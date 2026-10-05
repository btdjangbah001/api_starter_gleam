import gleam/list
import gleam/string

type Mode {
  Normal
  SingleQuoted
  DoubleQuoted
  LineComment
  BlockComment(depth: Int)
  DollarQuoted(closing: List(String))
}

pub fn split_statements(script: String) -> List(String) {
  script
  |> string.to_graphemes
  |> scan(Normal, [], [])
}

fn scan(
  remaining: List(String),
  mode: Mode,
  statement: List(String),
  statements: List(String),
) -> List(String) {
  case mode, remaining {
    _, [] -> list.reverse(finish(statement, statements))

    Normal, [";", ..rest] ->
      scan(rest, Normal, [], finish(statement, statements))
    Normal, ["'", ..rest] ->
      scan(rest, SingleQuoted, ["'", ..statement], statements)
    Normal, ["\"", ..rest] ->
      scan(rest, DoubleQuoted, ["\"", ..statement], statements)
    Normal, ["-", "-", ..rest] ->
      scan(rest, LineComment, [" ", ..statement], statements)
    Normal, ["/", "*", ..rest] ->
      scan(rest, BlockComment(1), [" ", ..statement], statements)
    Normal, ["$", ..rest] ->
      case dollar_tag(rest, []) {
        Ok(#(tag, after_tag)) -> {
          let delimiter = ["$", ..list.append(tag, ["$"])]
          scan(
            after_tag,
            DollarQuoted(delimiter),
            list.append(list.reverse(delimiter), statement),
            statements,
          )
        }
        Error(Nil) -> scan(rest, Normal, ["$", ..statement], statements)
      }
    Normal, [character, ..rest] ->
      scan(rest, Normal, [character, ..statement], statements)

    SingleQuoted, ["'", "'", ..rest] ->
      scan(rest, SingleQuoted, ["'", "'", ..statement], statements)
    SingleQuoted, ["'", ..rest] ->
      scan(rest, Normal, ["'", ..statement], statements)
    SingleQuoted, [character, ..rest] ->
      scan(rest, SingleQuoted, [character, ..statement], statements)

    DoubleQuoted, ["\"", "\"", ..rest] ->
      scan(rest, DoubleQuoted, ["\"", "\"", ..statement], statements)
    DoubleQuoted, ["\"", ..rest] ->
      scan(rest, Normal, ["\"", ..statement], statements)
    DoubleQuoted, [character, ..rest] ->
      scan(rest, DoubleQuoted, [character, ..statement], statements)

    LineComment, ["\n", ..rest] ->
      scan(rest, Normal, ["\n", ..statement], statements)
    LineComment, [_, ..rest] -> scan(rest, LineComment, statement, statements)

    BlockComment(depth), ["*", "/", ..rest] ->
      case depth {
        1 -> scan(rest, Normal, statement, statements)
        _ -> scan(rest, BlockComment(depth - 1), statement, statements)
      }
    BlockComment(depth), ["/", "*", ..rest] ->
      scan(rest, BlockComment(depth + 1), statement, statements)
    BlockComment(depth), [_, ..rest] ->
      scan(rest, BlockComment(depth), statement, statements)

    DollarQuoted(closing), [character, ..rest] ->
      case starts_with(remaining, closing) {
        True ->
          scan(
            list.drop(remaining, list.length(closing)),
            Normal,
            list.append(list.reverse(closing), statement),
            statements,
          )
        False ->
          scan(
            rest,
            DollarQuoted(closing),
            [character, ..statement],
            statements,
          )
      }
  }
}

fn dollar_tag(
  remaining: List(String),
  tag: List(String),
) -> Result(#(List(String), List(String)), Nil) {
  case remaining {
    ["$", ..rest] -> Ok(#(list.reverse(tag), rest))
    [character, ..rest] ->
      case is_tag_character(character, tag == []) {
        True -> dollar_tag(rest, [character, ..tag])
        False -> Error(Nil)
      }
    [] -> Error(Nil)
  }
}

fn is_tag_character(character: String, is_first: Bool) -> Bool {
  let is_letter =
    string.lowercase(character) != string.uppercase(character)
    || character == "_"
  let is_digit = string.contains("0123456789", character)
  is_letter || { !is_first && is_digit }
}

fn starts_with(remaining: List(String), prefix: List(String)) -> Bool {
  case prefix, remaining {
    [], _ -> True
    [expected, ..prefix_rest], [actual, ..remaining_rest]
      if expected == actual
    -> starts_with(remaining_rest, prefix_rest)
    _, _ -> False
  }
}

fn finish(statement: List(String), statements: List(String)) -> List(String) {
  let text =
    statement
    |> list.reverse
    |> string.concat
    |> string.trim
  case text {
    "" -> statements
    _ -> [text, ..statements]
  }
}
