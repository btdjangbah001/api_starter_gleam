import app/api/encoders
import app/api/request
import app/api/web.{type Context}
import app/services/user_admin_service
import app/types/app_error.{BadRequest}
import app/types/user.{type User}
import gleam/float
import gleam/json
import gleam/option
import gleam/result
import wisp

pub fn users(context: Context, http_request: wisp.Request) -> wisp.Response {
  let query = wisp.get_query(http_request)
  let number = fn(key, default) {
    request.query_number(query, key)
    |> option.map(float.truncate)
    |> option.unwrap(default)
  }
  user_admin_service.list_users(
    context.services,
    number("limit", 50),
    number("offset", 0),
  )
  |> result.map(json.array(_, encoders.user))
  |> web.respond
}

pub fn update_user(
  context: Context,
  http_request: wisp.Request,
  admin: User,
  user_id: String,
) -> wisp.Response {
  {
    use body <- result.try(request.read_body(http_request))
    use status_text <- result.try(request.required_text(
      body,
      "status",
      "Status",
    ))
    use status <- result.try(
      user.account_status_from_string(status_text)
      |> result.replace_error(BadRequest("Status must be active or suspended")),
    )
    user_admin_service.set_status(context.services, admin, user_id, status)
  }
  |> result.map(encoders.user)
  |> web.respond
}
