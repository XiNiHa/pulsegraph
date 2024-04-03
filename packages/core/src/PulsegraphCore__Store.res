module Key = {
  type t

  external fromString: string => t = "%identity"

  type container = Array(array<JSON.t>) | Dict(dict<JSON.t>)

  let resolve = (path, _query, data) => {
    open PulsegraphCore.GraphQL

    let parts = ref(["root"])
    let container = ref(Dict(data))

    path->Array.forEach(segment => {
      let (key, value) = switch (container.contents, segment) {
      | (Dict(dict), Path.Key(key)) => // TODO: handle query with arguments
        (key, Dict.get(dict, key))
      | (Array(arr), Path.Index(index)) => (Int.toString(index), arr->Array.get(index))
      | _ => failwith(`Invalid path "${Path.toString(path)}"`)
      }

      switch value {
      | Some(JSON.Object(value)) => {
          let id = Dict.get(value, "id")
          switch id {
          | Some(JSON.String(id)) => parts := [id]
          | Some(JSON.Number(id)) => parts := [Float.toString(id)]
          | _ => parts.contents->Array.push(key)
          }
          container := Dict(value)
        }
      | Some(JSON.Array(value)) => {
          container := Array(value)
          parts.contents->Array.push(key)
        }
      | Some(_) => parts.contents->Array.push(key)
      | None => failwith(`Invalid path "${Path.toString(path)}"`)
      }
    })

    parts.contents->Array.joinWith(":")->fromString
  }
}

type value = Scalar(PulsegraphCore.GraphQL.Scalar.t) | Error(PulsegraphCore.GraphQL.Response.error)
type content =
  | Value(value)
  | Values(array<value>)
  | Reference(Key.t)
  | References(array<Null.t<Key.t>>)

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
      | (Scalar(String(arr)), JSON.String(value)) => Scalar(String([...arr, Value(value)]))
      | (Scalar(Number(arr)), JSON.Number(value)) => Scalar(Number([...arr, Value(value)]))
      | (Scalar(Boolean(arr)), JSON.Boolean(value)) => Scalar(Boolean([...arr, Value(value)]))
      | (Scalar(Null(arr)), JSON.Null) => Scalar(Null([...arr, ()]))
      | (Scalar(Null(arr)), JSON.String(value)) =>
        Scalar(String([...arr->Array.map(() => Null.Null), Value(value)]))
      | (Scalar(Null(arr)), JSON.Number(value)) =>
        Scalar(Number([...arr->Array.map(() => Null.Null), Value(value)]))
      | (Scalar(Null(arr)), JSON.Boolean(value)) =>
        Scalar(Boolean([...arr->Array.map(() => Null.Null), Value(value)]))
      | (Scalar(Null(arr)), JSON.Object(value)) =>
        Object([...arr->Array.map(() => Null.Null), Value(value)])
      | (Scalar(String(arr)), JSON.Null) => Scalar(String([...arr, Null]))
      | (Scalar(Number(arr)), JSON.Null) => Scalar(Number([...arr, Null]))
      | (Scalar(Boolean(arr)), JSON.Null) => Scalar(Boolean([...arr, Null]))
      | (Object(arr), JSON.Object(value)) => Object([...arr, Value(value)])
      | (Object(arr), JSON.Null) => Object([...arr, Null])
      | (_, JSON.Array(_)) => Invalid
      | (Mixed, _) => Mixed
      | (Invalid, _) => Invalid
      | (_, _) => Mixed
      }
    })
  }

  let toContent = (array, path, payloadErrors) => {
    let handleNull = index => {
      open PulsegraphCore.GraphQL.Path
      open PulsegraphCore.GraphQL.Response

      let path = [...path, Index(index)]
      let error = payloadErrors->Array.find(error => error.path == Some(path))
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
type state = Map.t<Key.t, entry>
type t = {store: TanStackStore.t<state, state => state>}

let make = () => {
  store: TanStackStore.make(~initialState=Map.make()),
}

let processData = (
  ~store,
  ~query,
  ~data,
  ~commitedAt,
  ~payloadErrors: array<PulsegraphCore.GraphQL.Response.error>,
) => {
  open PulsegraphCore.GraphQL

  let rec processDict = (~path: Path.t, ~dict) => {
    let putContent = (parentPath, segment, content) => {
      let key = Key.resolve(parentPath, query, data)
      let dict = switch Map.get(TanStackStore.state(store), key) {
      | Some(entry) => entry
      | None => {
          let dict = Dict.make()
          Map.set(TanStackStore.state(store), key, dict)
          dict
        }
      }
      Dict.set(
        dict,
        Path.segmentToString(segment),
        {
          content,
          commitedAt,
        },
      )
    }

    let errors =
      dict
      ->Dict.toArray
      ->Array.reduce([], (errors, (key, value: JSON.t)) => {
        let itemPath = [...path, Key(key)]

        switch value {
        | String(value) => putContent(path, Path.Key(key), Value(Scalar(String(value))))
        | Number(value) => putContent(path, Path.Key(key), Value(Scalar(Number(value))))
        | Boolean(value) => putContent(path, Path.Key(key), Value(Scalar(Boolean(value))))
        | Null => {
            let error = payloadErrors->Array.find(error => error.path == Some(itemPath))
            switch error {
            | Some(error) => putContent(path, Key(key), Value(Error(error)))
            | None => putContent(path, Key(key), Value(Scalar(Null)))
            }
          }
        | Object(dict) => {
            switch processDict(~path=itemPath, ~dict) {
            | Ok() => ()
            | Error(errors') => Array.pushMany(errors, errors')
            }
            let itemKey = Key.resolve(itemPath, query, data)
            putContent(path, Key(key), Reference(itemKey))
          }
        | Array(values) =>
          switch ScalarArray.tryFrom(values) {
          | Mixed => Array.push(errors, `Array of mixed types at "${Path.toString(itemPath)}"`)
          | Scalar(arr) =>
            putContent(path, Key(key), ScalarArray.toContent(arr, itemPath, payloadErrors))
          | Object(arr) => {
              let refArray = Array.mapWithIndex(arr, (value, index) =>
                switch value {
                | Null => Null.Null
                | Value(dict) => {
                    let path = [...itemPath, Index(index)]
                    let key = Key.resolve(path, query, data)
                    switch processDict(~path, ~dict) {
                    | Ok() => ()
                    | Error(errors') => Array.pushMany(errors, errors')
                    }
                    Value(key)
                  }
                }
              )
              putContent(path, Key(key), References(refArray))
            }
          | Invalid =>
            Array.push(errors, `Array of unknown or invalid types at "${Path.toString(itemPath)}"`)
          }
        }
        errors
      })

    switch Array.length(errors) {
    | 0 => Ok()
    | _ => Error(errors)
    }
  }

  processDict(~path=[], ~dict=data)
}

let commitPayload = (store, query, payload) => {
  open PulsegraphCore.GraphQL.Response

  switch payload.data {
  | Some(data) => {
      let commitedAt = Date.now()
      let result = ref(Ok())
      TanStackStore.batch(store.store, () => {
        result :=
          processData(
            ~store=store.store,
            ~query,
            ~data,
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
