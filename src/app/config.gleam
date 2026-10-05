import envoy
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type SmtpSettings {
  SmtpSettings(
    host: String,
    port: Int,
    use_starttls: Bool,
    username: String,
    password: String,
  )
}

pub type EmailBackend {
  ConsoleEmail
  SmtpEmail(SmtpSettings)
}

pub type Config {
  Config(
    port: Int,
    database_url: String,
    database_pool_size: Int,
    app_name: String,
    email_backend: EmailBackend,
    email_from: String,
    cors_allowed_origins: List(String),
    secret_key_base: String,
    max_in_flight_requests: Int,
  )
}

const default_port = 4000

const default_pool_size = 10

const default_max_in_flight_requests = 100

const default_email_from = "Starter App <no-reply@example.com>"

pub fn load() -> Result(Config, String) {
  use port <- result.try(optional_int("PORT", default_port))
  use database_url <- result.try(required("DATABASE_URL"))
  use database_pool_size <- result.try(optional_int(
    "DATABASE_POOL_SIZE",
    default_pool_size,
  ))
  use email_backend <- result.try(load_email_backend())
  use secret_key_base <- result.try(required("SECRET_KEY_BASE"))
  use max_in_flight_requests <- result.try(optional_int(
    "MAX_IN_FLIGHT_REQUESTS",
    default_max_in_flight_requests,
  ))
  Ok(Config(
    port:,
    database_url:,
    database_pool_size:,
    app_name: optional("APP_NAME", "Starter App"),
    email_backend:,
    email_from: optional("EMAIL_FROM", default_email_from),
    cors_allowed_origins: optional("CORS_ALLOWED_ORIGINS", "*")
      |> string.split(",")
      |> list.map(string.trim)
      |> list.filter(fn(origin) { origin != "" }),
    secret_key_base:,
    max_in_flight_requests:,
  ))
}

pub fn load_database_url() -> Result(#(String, Int), String) {
  use database_url <- result.try(required("DATABASE_URL"))
  use pool_size <- result.try(optional_int("DATABASE_POOL_SIZE", 2))
  Ok(#(database_url, pool_size))
}

fn load_email_backend() -> Result(EmailBackend, String) {
  case optional("EMAIL_BACKEND", "smtp") |> string.lowercase {
    "console" -> Ok(ConsoleEmail)
    "smtp" -> {
      use host <- result.try(required("EMAIL_HOST"))
      use port <- result.try(optional_int("EMAIL_PORT", 587))
      use username <- result.try(required("EMAIL_HOST_USER"))
      use password <- result.try(required("EMAIL_HOST_PASSWORD"))
      let use_starttls =
        optional("EMAIL_USE_TLS", "true") |> string.lowercase == "true"
      Ok(
        SmtpEmail(SmtpSettings(
          host:,
          port:,
          use_starttls:,
          username:,
          password:,
        )),
      )
    }
    other ->
      Error("EMAIL_BACKEND must be \"smtp\" or \"console\", got " <> other)
  }
}

fn required(name: String) -> Result(String, String) {
  case envoy.get(name) {
    Ok(value) if value != "" -> Ok(value)
    _ -> Error("Missing required environment variable " <> name)
  }
}

fn optional(name: String, default: String) -> String {
  case envoy.get(name) {
    Ok(value) if value != "" -> value
    _ -> default
  }
}

fn optional_int(name: String, default: Int) -> Result(Int, String) {
  case envoy.get(name) {
    Ok(value) if value != "" ->
      int.parse(value)
      |> result.replace_error(name <> " must be a whole number")
    _ -> Ok(default)
  }
}
