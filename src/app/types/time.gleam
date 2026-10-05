import gleam/int
import gleam/order
import gleam/result
import gleam/string
import gleam/time/calendar.{type Date, Date, TimeOfDay}
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}

pub type ClockTime {
  ClockTime(hours: Int, minutes: Int)
}

pub fn now() -> Timestamp {
  timestamp.system_time()
}

pub fn to_iso8601(moment: Timestamp) -> String {
  let #(date, time_of_day) = timestamp.to_calendar(moment, calendar.utc_offset)
  let milliseconds = time_of_day.nanoseconds / 1_000_000
  date_to_string(date)
  <> "T"
  <> two_digits(time_of_day.hours)
  <> ":"
  <> two_digits(time_of_day.minutes)
  <> ":"
  <> two_digits(time_of_day.seconds)
  <> "."
  <> string.pad_start(int.to_string(milliseconds), to: 3, with: "0")
  <> "Z"
}

pub fn utc_date(moment: Timestamp) -> Date {
  timestamp.to_calendar(moment, calendar.utc_offset).0
}

pub fn utc_clock_time(moment: Timestamp) -> ClockTime {
  let #(_, time_of_day) = timestamp.to_calendar(moment, calendar.utc_offset)
  ClockTime(time_of_day.hours, time_of_day.minutes)
}

pub fn date_to_string(date: Date) -> String {
  string.pad_start(int.to_string(date.year), to: 4, with: "0")
  <> "-"
  <> two_digits(calendar.month_to_int(date.month))
  <> "-"
  <> two_digits(date.day)
}

pub fn date_to_compact_string(date: Date) -> String {
  date_to_string(date) |> string.replace("-", "")
}

pub fn parse_date(text: String) -> Result(Date, Nil) {
  case string.split(text, "-") {
    [year_text, month_text, day_text] -> {
      use year <- result.try(parse_fixed_width_int(year_text, 4))
      use month_number <- result.try(parse_fixed_width_int(month_text, 2))
      use day <- result.try(parse_fixed_width_int(day_text, 2))
      use month <- result.try(calendar.month_from_int(month_number))
      let date = Date(year, month, day)
      case calendar.is_valid_date(date) {
        True -> Ok(date)
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

pub fn add_days(date: Date, days: Int) -> Date {
  start_of_day(date)
  |> timestamp.add(duration.hours(24 * days))
  |> utc_date
}

pub fn start_of_day(date: Date) -> Timestamp {
  timestamp.from_calendar(
    date:,
    time: TimeOfDay(0, 0, 0, 0),
    offset: calendar.utc_offset,
  )
}

pub fn at_clock_time(date: Date, clock_time: ClockTime) -> Timestamp {
  timestamp.from_calendar(
    date:,
    time: TimeOfDay(clock_time.hours, clock_time.minutes, 0, 0),
    offset: calendar.utc_offset,
  )
}

pub fn compare_dates(left: Date, right: Date) -> order.Order {
  calendar.naive_date_compare(left, right)
}

pub fn parse_clock_time(text: String) -> Result(ClockTime, Nil) {
  case string.split(text, ":") {
    [hours_text, minutes_text] -> {
      use hours <- result.try(parse_fixed_width_int(hours_text, 2))
      use minutes <- result.try(parse_fixed_width_int(minutes_text, 2))
      case hours >= 0 && hours <= 23 && minutes >= 0 && minutes <= 59 {
        True -> Ok(ClockTime(hours, minutes))
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

pub fn clock_time_to_string(clock_time: ClockTime) -> String {
  two_digits(clock_time.hours) <> ":" <> two_digits(clock_time.minutes)
}

pub fn clock_time_to_compact_string(clock_time: ClockTime) -> String {
  two_digits(clock_time.hours) <> two_digits(clock_time.minutes)
}

pub fn is_after(moment: Timestamp, reference: Timestamp) -> Bool {
  timestamp.compare(moment, reference) == order.Gt
}

pub fn minutes_before(moment: Timestamp, minutes: Int) -> Timestamp {
  timestamp.subtract(moment, duration.minutes(minutes))
}

pub fn minutes_after(moment: Timestamp, minutes: Int) -> Timestamp {
  timestamp.add(moment, duration.minutes(minutes))
}

pub fn hours_before(moment: Timestamp, hours: Int) -> Timestamp {
  timestamp.subtract(moment, duration.hours(hours))
}

fn parse_fixed_width_int(text: String, width: Int) -> Result(Int, Nil) {
  case string.length(text) == width {
    True -> int.parse(text)
    False -> Error(Nil)
  }
}

fn two_digits(value: Int) -> String {
  string.pad_start(int.to_string(value), to: 2, with: "0")
}
