import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/otp/supervision

pub type Tick {
  Tick
}

pub type Schedule {
  Schedule(
    prepare: fn() -> Nil,
    first_delay_ms: fn() -> Int,
    next_delay_ms: fn() -> Int,
    job: fn() -> Nil,
  )
}

pub fn every(interval_ms: Int, job: fn() -> Nil) -> Schedule {
  Schedule(
    prepare: fn() { Nil },
    first_delay_ms: fn() { interval_ms },
    next_delay_ms: fn() { interval_ms },
    job:,
  )
}

pub fn supervised(
  schedule: Schedule,
) -> supervision.ChildSpecification(Subject(Tick)) {
  supervision.worker(fn() {
    actor.new_with_initialiser(5000, fn(self) {
      schedule.prepare()
      process.send_after(self, schedule.first_delay_ms(), Tick)
      #(self, schedule)
      |> actor.initialised
      |> actor.returning(self)
      |> Ok
    })
    |> actor.on_message(fn(state, _tick) {
      let #(self, schedule) = state
      schedule.job()
      process.send_after(self, schedule.next_delay_ms(), Tick)
      actor.continue(state)
    })
    |> actor.start
  })
}
