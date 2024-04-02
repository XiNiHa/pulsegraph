module Path = {
  type t
  type plain

  external toActual: string => t = "%identity"
  external toPlain: string => plain = "%identity"
  external actualToString: t => string = "%identity"
  external plainToString: plain => string = "%identity"

  let segmentRepr = segment => {
    open PulsegraphCore.GraphQL

    switch segment {
    | Key(key) => key
    | Index(index) => Int.toString(index)
    }
  }

  let resolvePlain = (~segment, ~parentPath: option<plain>=?) => {
    let segment = segmentRepr(segment)
    switch parentPath {
    | Some(parentPath) => `${plainToString(parentPath)}:${segment}`
    | None => segment
    }->toPlain
  }

  let plainToActual = (plain, value) => {
    switch value {
    | JSON.Object(dict) => {
        let id = Dict.get(dict, "id")

        switch id {
        | Some(JSON.String(id)) => id
        | Some(JSON.Number(id)) => Float.toString(id)
        | Some(_) | None =>
          // ID field is missing, or not an ID type
          plainToString(plain)
        }
      }
    | _ => plainToString(plain)
    }->toActual
  }

  let resolve = (~segment, ~value, ~parentPath=?) => {
    resolvePlain(~segment, ~parentPath?)->plainToActual(value)
  }

  let tryPlainFromError = error => {
    open PulsegraphCore.GraphQL.Response

    error.path->Option.map(path =>
      path
      ->Array.map(segmentRepr)
      ->Array.concat(["root"], _)
      ->Array.joinWith(":")
      ->toPlain
    )
  }
}

type value = Scalar(PulsegraphCore.GraphQL.Scalar.t) | Error(PulsegraphCore.GraphQL.Response.error)
type content =
  | Value(value)
  | Values(array<value>)
  | Reference(Path.t)
  | References(array<Null.t<Path.t>>)

module ScalarArray = {
  type t =
    | String(array<Null.t<string>>)
    | Number(array<Null.t<float>>)
    | Boolean(array<Null.t<bool>>)
    | Null(array<unit>)

  type result = Scalar(t) | Object(array<Null.t<Dict.t<JSON.t>>>) | Invalid | Mixed

  let tryFrom = array => {
    array->Array.reduce(Scalar(Null([])), (result, value) => {
      switch (result, value) {
      | (Scalar(String(arr)), JSON.String(value)) =>
        Scalar(String(Array.concat(arr, [Value(value)])))
      | (Scalar(Number(arr)), JSON.Number(value)) =>
        Scalar(Number(Array.concat(arr, [Value(value)])))
      | (Scalar(Boolean(arr)), JSON.Boolean(value)) =>
        Scalar(Boolean(Array.concat(arr, [Value(value)])))
      | (Scalar(Null(arr)), JSON.Null) => Scalar(Null(Array.concat(arr, [()])))
      | (Scalar(Null(arr)), JSON.String(value)) =>
        arr
        ->Array.map(() => Null.Null)
        ->Array.concat([Value(value)])
        ->String
        ->Scalar
      | (Scalar(Null(arr)), JSON.Number(value)) =>
        arr
        ->Array.map(() => Null.Null)
        ->Array.concat([Value(value)])
        ->Number
        ->Scalar
      | (Scalar(Null(arr)), JSON.Boolean(value)) =>
        arr
        ->Array.map(() => Null.Null)
        ->Array.concat([Value(value)])
        ->Boolean
        ->Scalar
      | (Scalar(Null(arr)), JSON.Object(value)) =>
        arr
        ->Array.map(() => Null.Null)
        ->Array.concat([Value(value)])
        ->Object
      | (Scalar(String(arr)), JSON.Null) => Scalar(String(Array.concat(arr, [Null])))
      | (Scalar(Number(arr)), JSON.Null) => Scalar(Number(Array.concat(arr, [Null])))
      | (Scalar(Boolean(arr)), JSON.Null) => Scalar(Boolean(Array.concat(arr, [Null])))
      | (Object(arr), JSON.Object(value)) => Object(Array.concat(arr, [Value(value)]))
      | (Object(arr), JSON.Null) => Object(Array.concat(arr, [Null]))
      | (_, JSON.Array(_)) => Invalid
      | (Mixed, _) => Mixed
      | (Invalid, _) => Invalid
      | (_, _) => Mixed
      }
    })
  }

  let toContent = (array, path, payloadErrors) => {
    open PulsegraphCore.GraphQL

    let handleNull = index => {
      let path = Path.resolvePlain(~segment=Index(index), ~parentPath=path)
      let error = payloadErrors->Array.find(error => Path.tryPlainFromError(error) == Some(path))
      switch error {
      | Some(error) => Error(error)
      | None => Scalar(Null)
      }
    }

    Values(
      switch array {
      | String(arr) =>
        arr->Array.mapWithIndex((value, i): value => {
          switch value {
          | Value(s) => Scalar(String(s))
          | Null => handleNull(i)
          }
        })
      | Number(arr) =>
        arr->Array.mapWithIndex((value, i): value => {
          switch value {
          | Value(n) => Scalar(Number(n))
          | Null => handleNull(i)
          }
        })
      | Boolean(arr) =>
        arr->Array.mapWithIndex((value, i): value => {
          switch value {
          | Value(b) => Scalar(Boolean(b))
          | Null => handleNull(i)
          }
        })
      | Null(arr) => arr->Array.mapWithIndex((_, i): value => handleNull(i))
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

let processData = (~store, ~dict, ~commitedAt, ~payloadErrors) => {
  let rec processDict = (~path: Path.t, ~plainPath: Path.plain, ~dict) => {
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
        let itemPlainPath = Path.resolvePlain(~segment=Key(key), ~parentPath=plainPath)
        let itemPath = Path.plainToActual(itemPlainPath, value)
        switch value {
        | String(value) => putContent(Key(key), Value(Scalar(String(value))), path)
        | Number(value) => putContent(Key(key), Value(Scalar(Number(value))), path)
        | Boolean(value) => putContent(Key(key), Value(Scalar(Boolean(value))), path)
        | Null => {
            let error =
              payloadErrors->Array.find(error =>
                Path.tryPlainFromError(error) == Some(itemPlainPath)
              )
            switch error {
            | Some(error) => putContent(Key(key), Value(Error(error)), path)
            | None => putContent(Key(key), Value(Scalar(Null)), path)
            }
          }
        | Object(dict) => {
            switch processDict(~path=itemPath, ~plainPath=itemPlainPath, ~dict) {
            | Ok() => ()
            | Error(errors') => Array.pushMany(errors, errors')
            }
            putContent(Key(key), Reference(itemPath), path)
          }
        | Array(values) =>
          switch ScalarArray.tryFrom(values) {
          | Mixed => Array.push(errors, `Array of mixed types at "${Path.actualToString(path)}"`)
          | Scalar(arr) =>
            putContent(Key(key), ScalarArray.toContent(arr, itemPlainPath, payloadErrors), path)
          | Object(arr) => {
              let refArray = Array.mapWithIndex(arr, (value, index) =>
                switch value {
                | Null => Null.Null
                | Value(dict) => {
                    let plainPath = Path.resolvePlain(
                      ~segment=Index(index),
                      ~parentPath=itemPlainPath,
                    )
                    let path = Path.plainToActual(plainPath, Object(dict))
                    switch processDict(~path, ~plainPath, ~dict) {
                    | Ok() => ()
                    | Error(errors') => Array.pushMany(errors, errors')
                    }
                    Value(path)
                  }
                }
              )
              putContent(Key(key), References(refArray), path)
            }
          | Invalid =>
            Array.push(errors, `Array of unknown or invalid types at "${Path.actualToString(path)}"`)
          }
        }
        errors
      })

    switch Array.length(errors) {
    | 0 => Ok()
    | _ => Error(errors)
    }
  }

  processDict(~path=Path.toActual("root"), ~plainPath=Path.toPlain("root"), ~dict)
}

let commitPayload = (store, payload) => {
  open PulsegraphCore.GraphQL.Response

  switch payload.data {
  | Some(dict) => {
      let commitedAt = Date.now()
      let result = ref(Ok())
      TanStackStore.batch(store.store, () => {
        result :=
          processData(
            ~store=store.store,
            ~dict,
            ~commitedAt,
            ~payloadErrors=payload.errors->Option.getOr([]),
          )
      })
      result.contents
    }
  | None => Ok()
  }
}

let getState = store => store.store->TanStackStore.state->StructuredClone.f
