import app/types/time
import app/types/user.{type User}
import gleam/json.{type Json}
import gleam/time/timestamp.{type Timestamp}

pub fn ok() -> Json {
  json.object([#("ok", json.bool(True))])
}

pub fn error_body(message: String) -> Json {
  json.object([#("error", json.string(message))])
}

pub fn session(token: String, account: User) -> Json {
  json.object([#("token", json.string(token)), #("user", user(account))])
}

pub fn user(account: User) -> Json {
  json.object([
    #("id", json.string(account.id)),
    #("role", json.string(user.role_to_string(account.role))),
    #("name", json.string(account.name)),
    #("email", json.string(account.email)),
    #("status", json.string(user.account_status_to_string(account.status))),
    #("createdAt", moment(account.created_at)),
  ])
}

pub fn moment(value: Timestamp) -> Json {
  json.string(time.to_iso8601(value))
}
