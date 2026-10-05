import gleam/list
import gleam/string

pub fn full_name(raw: String) -> Result(String, String) {
  let name = string.trim(raw)
  case string.length(name) >= 2 {
    True -> Ok(name)
    False -> Error("Enter your full name")
  }
}

pub fn email(raw: String) -> Result(String, String) {
  let email = raw |> string.trim |> string.lowercase
  case is_plausible_email(email) {
    True -> Ok(email)
    False -> Error("Enter a valid email address")
  }
}

pub fn password(raw: String) -> Result(String, String) {
  case string.length(raw) >= 8 {
    True -> Ok(raw)
    False -> Error("Password must be at least 8 characters")
  }
}

fn is_plausible_email(email: String) -> Bool {
  let has_whitespace =
    string.to_graphemes(email) |> list.any(is_whitespace_grapheme)
  case has_whitespace, string.split(email, "@") {
    False, [local_part, domain] -> local_part != "" && has_inner_dot(domain)
    _, _ -> False
  }
}

fn has_inner_dot(domain: String) -> Bool {
  domain
  |> string.drop_start(1)
  |> string.drop_end(1)
  |> string.contains(".")
}

fn is_whitespace_grapheme(grapheme: String) -> Bool {
  case grapheme {
    " " | "\t" | "\n" | "\r" -> True
    _ -> False
  }
}
