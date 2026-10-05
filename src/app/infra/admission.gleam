pub fn install() -> Nil {
  admission_install()
}

pub fn run(
  limit: Int,
  admitted: fn() -> outcome,
  rejected: fn() -> outcome,
) -> outcome {
  admission_run(limit, admitted, rejected)
}

pub fn in_flight() -> Int {
  admission_in_flight()
}

@external(erlang, "app_ffi", "admission_install")
fn admission_install() -> Nil

@external(erlang, "app_ffi", "admission_run")
fn admission_run(
  limit: Int,
  admitted: fn() -> outcome,
  rejected: fn() -> outcome,
) -> outcome

@external(erlang, "app_ffi", "admission_in_flight")
fn admission_in_flight() -> Int
