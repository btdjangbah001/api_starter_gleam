import app/config
import app/types/app_error.{type AppError}
import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/supervision
import gleam/result
import pog

pub type QueryOutcome(row) =
  Result(pog.Returned(row), pog.QueryError)

pub fn pool_child_spec(
  pool_name: process.Name(pog.Message),
  database_url: String,
  pool_size: Int,
) -> Result(supervision.ChildSpecification(pog.Connection), String) {
  pog.url_config(pool_name, database_url)
  |> result.replace_error(
    "DATABASE_URL must look like postgresql://user:password@host:5432/postgres?sslmode=require",
  )
  |> result.map(fn(config) {
    config
    |> pog.pool_size(pool_size)
    |> pog.queue_target(200)
    |> pog.queue_interval(1000)
    |> pog.supervised
  })
}

pub fn rows(outcome: QueryOutcome(row)) -> Result(List(row), AppError) {
  outcome
  |> result.map(fn(returned) { returned.rows })
  |> result.map_error(app_error.from_database)
}

pub fn first(outcome: QueryOutcome(row)) -> Result(Option(row), AppError) {
  rows(outcome)
  |> result.map(fn(found) { list.first(found) |> option.from_result })
}

pub fn single(outcome: QueryOutcome(row)) -> Result(row, AppError) {
  use found <- result.try(first(outcome))
  option.to_result(found, app_error.Unexpected("Expected exactly one row"))
}

pub fn affected(outcome: QueryOutcome(row)) -> Result(Int, AppError) {
  outcome
  |> result.map(fn(returned) { returned.count })
  |> result.map_error(app_error.from_database)
}

pub fn transaction(
  connection: pog.Connection,
  unit_of_work: fn(pog.Connection) -> Result(value, AppError),
) -> Result(value, AppError) {
  pog.transaction(connection, unit_of_work)
  |> result.map_error(fn(error) {
    case error {
      pog.TransactionRolledBack(cause) -> cause
      pog.TransactionQueryError(cause) -> app_error.from_database(cause)
    }
  })
}

pub fn require_found(
  found: Result(Option(row), AppError),
  not_found: AppError,
) -> Result(row, AppError) {
  use maybe_row <- result.try(found)
  option.to_result(maybe_row, not_found)
}

pub fn column(
  value: String,
  parse: fn(String) -> Result(parsed, Nil),
  column_name: String,
) -> Result(parsed, AppError) {
  parse(value)
  |> result.replace_error(app_error.Unexpected(
    "Unrecognised " <> column_name <> " value: " <> value,
  ))
}

pub fn optional_column(
  value: Option(String),
  parse: fn(String) -> Result(parsed, Nil),
  column_name: String,
) -> Result(Option(parsed), AppError) {
  case value {
    Some(text) -> column(text, parse, column_name) |> result.map(Some)
    None -> Ok(None)
  }
}

pub fn blank_when_absent(value: Option(String)) -> String {
  option.unwrap(value, "")
}

pub fn in_id_order(
  records: List(record),
  ordered_ids: List(String),
  id: fn(record) -> String,
) -> List(record) {
  let by_id =
    records
    |> list.map(fn(record) { #(id(record), record) })
    |> dict.from_list
  list.filter_map(ordered_ids, fn(wanted) { dict.get(by_id, wanted) })
}

pub fn connect_from_environment(
  pool_name: String,
) -> Result(pog.Connection, String) {
  use #(database_url, pool_size) <- result.try(config.load_database_url())
  use pool_config <- result.try(
    pog.url_config(process.new_name(pool_name), database_url)
    |> result.replace_error("DATABASE_URL is not a valid PostgreSQL URL"),
  )
  pool_config
  |> pog.pool_size(pool_size)
  |> pog.start
  |> result.map(fn(started) { started.data })
  |> result.replace_error("Could not start the database pool")
}
