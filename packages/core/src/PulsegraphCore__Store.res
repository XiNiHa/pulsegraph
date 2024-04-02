module Path = {
  type t = string

  let resolve = (~segment, ~value, ~parentPath=?) => {
    open PulsegraphCore.GraphQL

    let segmentRepr = switch segment {
    | Key(key) => key
    | Index(index) => Int.toString(index)
    }

    let fallbackPath = switch parentPath {
    | Some(parentPath) => `${parentPath}:${segmentRepr}`
    | None => segmentRepr
    }

    (switch value {
    | JSON.Object(dict) => {
        let id = Dict.get(dict, "id")

        switch id {
        | Some(JSON.String(id)) => id
        | Some(JSON.Number(id)) => Float.toString(id)
        | Some(_) | None => // ID field is missing, or not an ID type
          fallbackPath
        }
      }
    | _ => fallbackPath
    } :> t)
  }
}

type content =
  | Value(PulsegraphCore.GraphQL.Scalar.t)
  | Values(array<PulsegraphCore.GraphQL.Scalar.t>)
  | Reference(Path.t)
  | References(array<option<Path.t>>)

module ScalarArray = {
  type t =
    | String(array<option<string>>)
    | Number(array<option<float>>)
    | Boolean(array<option<bool>>)
    | Null(array<unit>)

  type result = Scalar(t) | Object(array<option<Dict.t<JSON.t>>>) | Invalid | Mixed

  let tryFrom = array => {
    array->Array.reduce(Scalar(Null([])), (result, value) => {
      switch (result, value) {
      | (Scalar(String(arr)), JSON.String(value)) =>
        Scalar(String(Array.concat(arr, [Some(value)])))
      | (Scalar(Number(arr)), JSON.Number(value)) =>
        Scalar(Number(Array.concat(arr, [Some(value)])))
      | (Scalar(Boolean(arr)), JSON.Boolean(value)) =>
        Scalar(Boolean(Array.concat(arr, [Some(value)])))
      | (Scalar(Null(arr)), JSON.Null) => Scalar(Null(Array.concat(arr, [()])))
      | (Scalar(Null(arr)), JSON.String(value)) =>
        arr
        ->Array.map(() => None)
        ->Array.concat([Some(value)])
        ->String
        ->Scalar
      | (Scalar(Null(arr)), JSON.Number(value)) =>
        arr
        ->Array.map(() => None)
        ->Array.concat([Some(value)])
        ->Number
        ->Scalar
      | (Scalar(Null(arr)), JSON.Boolean(value)) =>
        arr
        ->Array.map(() => None)
        ->Array.concat([Some(value)])
        ->Boolean
        ->Scalar
      | (Scalar(Null(arr)), JSON.Object(value)) =>
        arr
        ->Array.map(() => None)
        ->Array.concat([Some(value)])
        ->Object
      | (Scalar(String(arr)), JSON.Null) => Scalar(String(Array.concat(arr, [None])))
      | (Scalar(Number(arr)), JSON.Null) => Scalar(Number(Array.concat(arr, [None])))
      | (Scalar(Boolean(arr)), JSON.Null) => Scalar(Boolean(Array.concat(arr, [None])))
      | (Object(arr), JSON.Object(value)) => Object(Array.concat(arr, [Some(value)]))
      | (Object(arr), JSON.Null) => Object(Array.concat(arr, [None]))
      | (_, JSON.Array(_)) => Invalid
      | (Mixed, _) => Mixed
      | (Invalid, _) => Invalid
      | (_, _) => Mixed
      }
    })
  }

  let toContent = array => {
    open PulsegraphCore.GraphQL
    Values(
      switch array {
      | String(arr) => arr->Array.map(s => s->Option.map(s => Scalar.String(s))->Option.getOr(Null))
      | Number(arr) => arr->Array.map(n => n->Option.map(n => Scalar.Number(n))->Option.getOr(Null))
      | Boolean(arr) =>
        arr->Array.map(b => b->Option.map(b => Scalar.Boolean(b))->Option.getOr(Null))
      | Null(arr) => arr->Array.map(() => Scalar.Null)
      },
    )
  }
}

type field = {
  content: content,
  commitedAt: Date.msSinceEpoch,
}
type entry = Dict.t<field>
type state = Map.t<Path.t, entry>
type t = {store: TanStackStore.t<state, state => state>}

let make = () => {
  store: TanStackStore.make(~initialState=Map.make()),
}

let rec processDict = (~store, ~path, ~dict, ~commitedAt) => {
  let putContent = (segment, content, path) => {
    open PulsegraphCore.GraphQL

    let object = switch Map.get(TanStackStore.state(store), path) {
    | Some(entry) => entry
    | None => {
        let object = Dict.make()
        Map.set(TanStackStore.state(store), path, object)
        object
      }
    }
    Dict.set(
      object,
      switch segment {
      | Key(key) => key
      | Index(index) => Int.toString(index)
      },
      {
        content,
        commitedAt,
      },
    )
  }

  let errors =
    dict
    ->Dict.toArray
    ->Array.reduce([], (errors, (key, value)) => {
      let itemPath = Path.resolve(~segment=Key(key), ~value, ~parentPath=path)
      switch value {
      | String(value) => putContent(Key(key), Value(String(value)), path)
      | Number(value) => putContent(Key(key), Value(Number(value)), path)
      | Boolean(value) => putContent(Key(key), Value(Boolean(value)), path)
      | Null => putContent(Key(key), Value(Null), path)
      | Object(dict) => {
          switch processDict(~store, ~path=itemPath, ~dict, ~commitedAt) {
          | Ok() => ()
          | Error(errors') => Array.pushMany(errors, errors')
          }
          putContent(Key(key), Reference(itemPath), path)
        }
      | Array(values) =>
        switch ScalarArray.tryFrom(values) {
        | Mixed => Array.push(errors, `Array of mixed types at "${path}"`)
        | Scalar(arr) => putContent(Key(key), ScalarArray.toContent(arr), path)
        | Object(arr) => {
            let refArray = Array.mapWithIndex(arr, (value, index) =>
              switch value {
              | None => None
              | Some(dict) => {
                  let path = Path.resolve(
                    ~segment=Index(index),
                    ~value=Object(dict),
                    ~parentPath=itemPath,
                  )
                  switch processDict(~store, ~path, ~dict, ~commitedAt) {
                  | Ok() => ()
                  | Error(errors') => Array.pushMany(errors, errors')
                  }
                  Some(path)
                }
              }
            )
            putContent(Key(key), References(refArray), path)
          }
        | Invalid => Array.push(errors, `Array of unknown or invalid types at "${path}"`)
        }
      }
      errors
    })

  switch Array.length(errors) {
  | 0 => Ok()
  | _ => Error(errors)
  }
}

let commitPayload = (store, payload) => {
  open PulsegraphCore.GraphQL.Response

  switch payload.data {
  | Some(dict) => {
      let commitedAt = Date.now()
      let path = Path.resolve(~segment=Key("root"), ~value=Object(dict))
      let result = ref(Ok())
      TanStackStore.batch(store.store, () => {
        result := processDict(~store=store.store, ~path, ~dict, ~commitedAt)
      })
      result.contents
    }
  | None => Ok()
  }
}

let getState = store => store.store->TanStackStore.state->StructuredClone.f
