type t
type content =
  | Value(PulsegraphCore.GraphQL.Scalar.t)
  | Values(array<PulsegraphCore.GraphQL.Scalar.t>)
  | Reference(string)
  | References(array<option<string>>)
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
