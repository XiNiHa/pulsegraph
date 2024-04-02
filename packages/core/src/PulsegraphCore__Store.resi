type t
type content =
  | Value(PulsegraphCore__GraphQL.Scalar.t)
  | Values(array<PulsegraphCore__GraphQL.Scalar.t>)
  | Reference(string)
  | References(array<Null.t<string>>)
type field = {
  content: content,
  commitedAt: Date.msSinceEpoch,
}

@genType
let make: unit => t

@genType
let commitPayload: (t, PulsegraphCore__GraphQL.Response.t) => result<unit, array<string>>

@genType
let getState: t => Map.t<string, Dict.t<field>>
