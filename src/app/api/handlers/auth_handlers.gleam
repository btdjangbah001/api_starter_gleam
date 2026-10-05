import app/api/encoders
import app/api/request
import app/api/web.{type Context}
import app/services/auth_service.{LoginInput, ProfileChanges, SignupInput}
import app/types/user.{type User}
import gleam/result
import wisp

pub fn signup(context: Context, http_request: wisp.Request) -> wisp.Response {
  {
    use body <- result.try(request.read_body(http_request))
    use name <- result.try(request.required_text(body, "name", "Full name"))
    use email <- result.try(request.required_text(body, "email", "Email"))
    use password <- result.try(request.required_text(
      body,
      "password",
      "Password",
    ))
    auth_service.signup(
      context.services,
      SignupInput(name:, email:, password:),
      web.client_key(http_request),
    )
  }
  |> result.map(fn(session) { encoders.session(session.token, session.user) })
  |> web.respond
}

pub fn login(context: Context, http_request: wisp.Request) -> wisp.Response {
  {
    use body <- result.try(request.read_body(http_request))
    use email <- result.try(request.required_text(body, "email", "Email"))
    use password <- result.try(request.required_text(
      body,
      "password",
      "Password",
    ))
    auth_service.login(context.services, LoginInput(email:, password:))
  }
  |> result.map(fn(session) { encoders.session(session.token, session.user) })
  |> web.respond
}

pub fn logout(context: Context, token: String) -> wisp.Response {
  auth_service.logout(context.services, token)
  |> result.map(fn(_) { encoders.ok() })
  |> web.respond
}

pub fn me(signed_in: User) -> wisp.Response {
  web.json_ok(encoders.user(signed_in))
}

pub fn update_me(
  context: Context,
  http_request: wisp.Request,
  signed_in: User,
) -> wisp.Response {
  {
    use body <- result.try(request.read_body(http_request))
    use name <- result.try(request.changed_text(body, "name", "Full name"))
    use email <- result.try(request.changed_text(body, "email", "Email"))
    use new_password <- result.try(request.changed_text(
      body,
      "newPassword",
      "New password",
    ))
    use current_password <- result.try(request.optional_text(
      body,
      "currentPassword",
      "Current password",
    ))
    auth_service.update_profile(
      context.services,
      signed_in,
      ProfileChanges(name:, email:, current_password:, new_password:),
    )
  }
  |> result.map(encoders.user)
  |> web.respond
}
