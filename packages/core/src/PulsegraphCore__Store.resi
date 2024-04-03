module Key: {
  @genType.import("./shims/Path.shim.js")
  type t
}

type t
type value = Scalar(PulsegraphCore__GraphQL.Scalar.t) | Error(PulsegraphCore__GraphQL.Response.error)
type content =
  | Value(value)
  | Values(array<value>)
  | Reference(Key.t)
  | References(array<Null.t<Key.t>>)
type field = {
  content: content,
  commitedAt: Date.msSinceEpoch,
}

@genType
let make: unit => t

@genType
let commitPayload: (t, 'a, PulsegraphCore__GraphQL.Response.t) => result<unit, array<string>>

@genType
let getState: t => Map.t<Key.t, Dict.t<field>>
