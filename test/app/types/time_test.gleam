import app/types/time.{ClockTime}
import gleam/time/calendar.{Date, December, January, October}

pub fn timestamps_render_as_iso8601_with_milliseconds_test() {
  assert time.to_iso8601(time.at_clock_time(
      Date(2026, October, 3),
      ClockTime(15, 0),
    ))
    == "2026-10-03T15:00:00.000Z"
}

pub fn dates_roll_over_months_and_years_test() {
  assert time.add_days(Date(2026, December, 31), 1) == Date(2027, January, 1)
}

pub fn dates_and_clock_times_parse_strictly_test() {
  assert time.parse_date("2026-10-03") == Ok(Date(2026, October, 3))
  assert time.parse_date("2026-02-30") == Error(Nil)
  assert time.parse_clock_time("05:30") == Ok(ClockTime(5, 30))
  assert time.parse_clock_time("24:00") == Error(Nil)
}
