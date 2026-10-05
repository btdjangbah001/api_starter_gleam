import app/infra/admission

pub fn admits_requests_up_to_the_limit_test() {
  admission.install()
  let outcome =
    admission.run(
      2,
      fn() { admission.run(2, fn() { "inner" }, fn() { "busy" }) },
      fn() { "busy" },
    )
  assert outcome == "inner"
  assert admission.in_flight() == 0
}

pub fn rejects_requests_beyond_the_limit_test() {
  admission.install()
  let outcome =
    admission.run(
      1,
      fn() { admission.run(1, fn() { "inner" }, fn() { "busy" }) },
      fn() { "busy" },
    )
  assert outcome == "busy"
  assert admission.in_flight() == 0
}

pub fn releases_the_slot_when_the_handler_crashes_test() {
  admission.install()
  let _ =
    rescue(fn() {
      admission.run(5, fn() { panic as "handler crashed" }, fn() { Nil })
    })
  assert admission.in_flight() == 0
}

@external(erlang, "app_test_ffi", "rescue")
fn rescue(work: fn() -> a) -> Result(a, Nil)
