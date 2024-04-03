@genType
module Path = {
  @unboxed type segment = Key(string) | Index(int)
  type t = array<segment>

  let segmentToString = segment => {
    switch segment {
    | Key(key) => key
    | Index(index) => Int.toString(index)
    }
  }

  let toString = path => {
    path->Array.reduce("", (acc, segment) => {
      switch (acc, segment) {
      | ("", _) => segmentToString(segment)
      | (acc, Key(key)) => `${acc}.${key}`
      | (acc, Index(index)) => `${acc}[${Int.toString(index)}]`
      }
    })
  }
}

@genType
module Scalar = {
  @unboxed
  type t =
    | String(string)
    | Number(float)
    | Boolean(bool)
    | @as(null) Null
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
    path?: Path.t,
    extensions?: Dict.t<JSON.t>,
  }

  type t = {
    data?: Dict.t<JSON.t>,
    errors?: array<error>,
    extensions?: Dict.t<JSON.t>,
  }
}
