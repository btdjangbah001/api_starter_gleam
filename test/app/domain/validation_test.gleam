import app/domain/validation

pub fn emails_are_trimmed_and_lower_cased_test() {
  assert validation.email(" Ada@Example.COM ") == Ok("ada@example.com")
  assert validation.email("no-at-sign.com") |> is_error
  assert validation.email("a@b") |> is_error
  assert validation.email("a@.b") |> is_error
  assert validation.email("a b@c.com") |> is_error
}

pub fn names_and_passwords_have_minimum_lengths_test() {
  assert validation.full_name("  Ada  ") == Ok("Ada")
  assert validation.full_name("A") == Error("Enter your full name")
  assert validation.password("min8char") == Ok("min8char")
  assert validation.password("short")
    == Error("Password must be at least 8 characters")
}

fn is_error(outcome: Result(a, b)) -> Bool {
  case outcome {
    Ok(_) -> False
    Error(_) -> True
  }
}
