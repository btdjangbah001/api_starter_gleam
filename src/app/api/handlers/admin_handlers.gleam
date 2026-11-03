import app/api/encoders
import app/api/request
import app/api/web.{type Context}
import app/services/user_admin_service
import app/types/app_error.{BadRequest}
import app/types/user.{type User}
import gleam/result
import wisp

const default_page_size = 50

const maximum_page_size = 200

pub fn users(context: Context, http_request: wisp.Request) -> wisp.Response {
  user_admin_service.list_users(
    context.services,
    web.page_request(http_request, default_page_size, maximum_page_size),
  )
  |> web.respond_page(encoders.user)
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
