import app/types/app_error.{type AppError, BadRequest}
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import wisp

pub opaque type Body {
  Body(fields: Dict(String, Dynamic))
}

type FieldValue {
  Absent
  Null
  Text(String)
  Number(Float)
  Boolean(Bool)
  Other
}

pub fn read_body(request: wisp.Request) -> Result(Body, AppError) {
  use bits <- result.try(
    wisp.read_body_bits(request)
    |> result.replace_error(BadRequest("Request body is too large")),
  )
  use text <- result.try(
    bit_array.to_string(bits)
    |> result.replace_error(BadRequest("Request body must be JSON")),
  )
  case string.trim(text) {
    "" -> Ok(empty())
    json_text ->
      json.parse(json_text, decode.dynamic)
      |> result.replace_error(BadRequest("Request body must be JSON"))
      |> result.map(from_dynamic)
  }
}

pub fn empty() -> Body {
  Body(dict.new())
}

pub fn from_dynamic(value: Dynamic) -> Body {
  decode.run(value, decode.dict(decode.string, decode.dynamic))
  |> result.unwrap(dict.new())
  |> Body
}

pub fn has(body: Body, key: String) -> Bool {
  case field(body, key) {
    Absent -> False
    _ -> True
  }
}

pub fn required_text(
  body: Body,
  key: String,
  label: String,
) -> Result(String, AppError) {
  case field(body, key) {
    Absent | Null -> Error(BadRequest(label <> " is required"))
    Text(text) ->
      case string.trim(text) {
        "" -> Error(BadRequest(label <> " is required"))
        trimmed -> Ok(trimmed)
      }
    Number(_) | Boolean(_) | Other ->
      Error(BadRequest(label <> " must be text"))
  }
}

pub fn optional_text(
  body: Body,
  key: String,
  label: String,
) -> Result(Option(String), AppError) {
  case field(body, key) {
    Absent | Null -> Ok(None)
    Text(text) ->
      case string.trim(text) {
        "" -> Ok(None)
        trimmed -> Ok(Some(trimmed))
      }
    Number(_) | Boolean(_) | Other ->
      Error(BadRequest(label <> " must be text"))
  }
}

pub fn changed_text(
  body: Body,
  key: String,
  label: String,
) -> Result(Option(String), AppError) {
  case has(body, key) {
    False -> Ok(None)
    True -> required_text(body, key, label) |> result.map(Some)
  }
}

pub fn changed_reference(
  body: Body,
  key: String,
  label: String,
) -> Result(Option(Option(String)), AppError) {
  case has(body, key) {
    False -> Ok(None)
    True -> optional_text(body, key, label) |> result.map(Some)
  }
}

pub fn required_number(
  body: Body,
  key: String,
  label: String,
) -> Result(Float, AppError) {
  let not_a_number = BadRequest(label <> " must be a number")
  case field(body, key) {
    Number(value) -> Ok(value)
    Text(text) ->
      parse_number(string.trim(text)) |> result.replace_error(not_a_number)
    Absent | Null | Boolean(_) | Other -> Error(not_a_number)
  }
}

pub fn optional_number(
  body: Body,
  key: String,
  label: String,
) -> Result(Option(Float), AppError) {
  case field(body, key) {
    Absent | Null -> Ok(None)
    _ -> required_number(body, key, label) |> result.map(Some)
  }
}

pub fn optional_bool(body: Body, key: String) -> Option(Bool) {
  case field(body, key) {
    Boolean(value) -> Some(value)
    _ -> None
  }
}

pub fn text_list(body: Body, key: String) -> List(String) {
  dict.get(body.fields, key)
  |> result.try(fn(value) {
    decode.run(value, decode.list(decode.dynamic)) |> result.replace_error(Nil)
  })
  |> result.unwrap([])
  |> list.map(fn(item) {
    case classify(item) {
      Text(text) -> text
      Number(number) -> float.to_string(number)
      _ -> ""
    }
  })
}

pub fn object_list(body: Body, key: String) -> Option(List(Body)) {
  dict.get(body.fields, key)
  |> result.try(fn(value) {
    decode.run(value, decode.list(decode.dynamic)) |> result.replace_error(Nil)
  })
  |> result.map(list.map(_, from_dynamic))
  |> option.from_result
}

pub fn query_text(
  query: List(#(String, String)),
  key: String,
) -> Option(String) {
  list.key_find(query, key)
  |> result.map(string.trim)
  |> result.try(fn(value) {
    case value {
      "" -> Error(Nil)
      present -> Ok(present)
    }
  })
  |> option.from_result
}

pub fn query_number(
  query: List(#(String, String)),
  key: String,
) -> Option(Float) {
  query_text(query, key)
  |> option.then(fn(text) { parse_number(text) |> option.from_result })
}

pub fn parse_number(text: String) -> Result(Float, Nil) {
  case float.parse(text) {
    Ok(value) -> Ok(value)
    Error(Nil) -> int.parse(text) |> result.map(int.to_float)
  }
}

fn field(body: Body, key: String) -> FieldValue {
  case dict.get(body.fields, key) {
    Error(Nil) -> Absent
    Ok(value) -> classify(value)
  }
}

fn classify(value: Dynamic) -> FieldValue {
  let decoded =
    decode.one_of(decode.string |> decode.map(Text), [
      decode.int |> decode.map(fn(number) { Number(int.to_float(number)) }),
      decode.float |> decode.map(Number),
      decode.bool |> decode.map(Boolean),
      decode.optional(decode.dynamic)
        |> decode.map(fn(maybe) {
          case maybe {
            None -> Null
            Some(_) -> Other
          }
        }),
    ])
  decode.run(value, decoded) |> result.unwrap(Other)
}
