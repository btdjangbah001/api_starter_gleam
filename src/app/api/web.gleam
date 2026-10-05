import app/api/encoders
import app/infra/admission
import app/services/auth_service
import app/services/context.{type Services}
import app/types/app_error.{type AppError, Forbidden, Unauthorized}
import app/types/user.{type Role, type User}
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import wisp

pub type Context {
  Context(
    services: Services,
    cors_allowed_origins: List(String),
    max_in_flight_requests: Int,
  )
}

pub type Caller {
  Guest
  SignedIn(user: User, token: String)
}

const max_body_bytes = 65_536

pub const please_log_in = Unauthorized("Please log in again")

pub fn json_ok(body: Json) -> wisp.Response {
  wisp.json_response(json.to_string(body), 200)
}

pub fn respond(outcome: Result(Json, AppError)) -> wisp.Response {
  case outcome {
    Ok(body) -> json_ok(body)
    Error(error) -> error_response(error)
  }
}

pub fn error_response(error: AppError) -> wisp.Response {
  case error {
    app_error.DatabaseFailure(cause) ->
      wisp.log_error("Database failure: " <> string.inspect(cause))
    app_error.Unexpected(detail) ->
      wisp.log_error("Unexpected failure: " <> detail)
    _ -> Nil
  }
  wisp.json_response(
    json.to_string(encoders.error_body(app_error.client_message(error))),
    app_error.status_code(error),
  )
}

pub fn require_role(
  caller: Caller,
  allowed: List(Role),
  next: fn(User) -> wisp.Response,
) -> wisp.Response {
  case caller {
    Guest -> error_response(please_log_in)
    SignedIn(user: signed_in, ..) ->
      case signed_in.status, list.contains(allowed, signed_in.role) {
        user.Suspended, _ -> error_response(auth_service.suspended_account)
        user.Active, False ->
          error_response(Forbidden("Not allowed for this account"))
        user.Active, True -> next(signed_in)
      }
  }
}

pub fn with_body(
  request: wisp.Request,
  next: fn(request_body) -> Result(Json, AppError),
  parse: fn(wisp.Request) -> Result(request_body, AppError),
) -> wisp.Response {
  parse(request) |> result.try(next) |> respond
}

pub fn middleware(
  request: wisp.Request,
  context: Context,
  handler: fn(wisp.Request, Caller) -> wisp.Response,
) -> wisp.Response {
  let started = timestamp.system_time()
  let request = wisp.set_max_body_size(request, max_body_bytes)
  let #(response, caller) = case request.method, request.path {
    http.Options, _ -> #(wisp.response(204), Guest)
    _, "/health" -> #(rescue(fn() { handler(request, Guest) }), Guest)
    _, _ ->
      admission.run(
        context.max_in_flight_requests,
        fn() {
          let caller = resolve_caller(context, request)
          #(rescue(fn() { handler(request, caller) }), caller)
        },
        fn() { #(busy_response(), Guest) },
      )
  }
  log_request(request, response, caller, started)
  with_cors(response, request, context.cors_allowed_origins)
}

fn busy_response() -> wisp.Response {
  error_response(app_error.ServiceBusy)
  |> response.set_header("retry-after", "1")
}

pub fn client_key(request: wisp.Request) -> String {
  request.get_header(request, "x-forwarded-for")
  |> result.try(fn(forwarded) { forwarded |> string.split(",") |> list.last })
  |> result.map(string.trim)
  |> result.unwrap("direct")
}

pub fn bearer_token(request: wisp.Request) -> Option(String) {
  case request.get_header(request, "authorization") {
    Ok(header) ->
      case string.split_once(string.trim(header), " ") {
        Ok(#(scheme, token)) ->
          case string.lowercase(scheme), string.trim(token) {
            "bearer", "" -> None
            "bearer", token -> Some(token)
            _, _ -> None
          }
        Error(Nil) -> None
      }
    Error(Nil) -> None
  }
}

fn resolve_caller(context: Context, request: wisp.Request) -> Caller {
  case bearer_token(request), request.method {
    _, http.Options | None, _ -> Guest
    Some(token), _ ->
      case auth_service.authenticate(context.services, token) {
        Ok(Some(signed_in)) -> SignedIn(user: signed_in, token:)
        Ok(None) -> Guest
        Error(error) -> {
          wisp.log_error("Session lookup failed: " <> string.inspect(error))
          Guest
        }
      }
  }
}

fn rescue(handler: fn() -> wisp.Response) -> wisp.Response {
  let response = wisp.rescue_crashes(handler)
  let is_json =
    response.get_header(response, "content-type")
    |> result.map(string.starts_with(_, "application/json"))
    |> result.unwrap(False)
  case response.status, is_json {
    500, False -> error_response(app_error.Unexpected("Request crashed"))
    _, _ -> response
  }
}

fn with_cors(
  response: wisp.Response,
  request: wisp.Request,
  allowed_origins: List(String),
) -> wisp.Response {
  let origin = request.get_header(request, "origin") |> result.unwrap("")
  let allow_origin = case list.contains(allowed_origins, "*") {
    True -> Some("*")
    False ->
      case list.contains(allowed_origins, origin) {
        True -> Some(origin)
        False -> None
      }
  }
  case allow_origin {
    None -> response
    Some(allowed) ->
      response
      |> response.set_header("access-control-allow-origin", allowed)
      |> response.set_header("vary", "Origin")
      |> response.set_header(
        "access-control-allow-headers",
        "Authorization, Content-Type",
      )
      |> response.set_header(
        "access-control-allow-methods",
        "GET, POST, PUT, PATCH, DELETE, OPTIONS",
      )
      |> response.set_header("access-control-max-age", "600")
  }
}

fn log_request(
  request: wisp.Request,
  response: wisp.Response,
  caller: Caller,
  started: timestamp.Timestamp,
) -> Nil {
  let elapsed_ms =
    timestamp.difference(started, timestamp.system_time())
    |> duration.to_milliseconds
  let user_id = case caller {
    SignedIn(user: signed_in, ..) -> signed_in.id
    Guest -> "-"
  }
  wisp.log_info(
    http.method_to_string(request.method)
    |> string.uppercase
    <> " "
    <> request.path
    <> " "
    <> int.to_string(response.status)
    <> " "
    <> int.to_string(elapsed_ms)
    <> "ms user="
    <> user_id,
  )
}
