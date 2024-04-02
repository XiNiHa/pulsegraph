@genType @unboxed type pathSegment = Key(string) | Index(int)

@genType
module Scalar = {
  @unboxed
  type t =
    | String(string)
    | Number(float)
    | Boolean(bool)
    | Null
}

@genType
module Response = {
  type errorLocation = {
    line: int,
    column: int,
  }

  type error = {
    message: string,
    locations?: array<errorLocation>,
    path?: array<pathSegment>,
    extensions?: Dict.t<JSON.t>,
  }

  type t = {
    data?: Dict.t<JSON.t>,
    errors?: array<error>,
    extensions?: Dict.t<JSON.t>,
  }
}
