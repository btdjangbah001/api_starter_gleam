import app/api/encoders
import app/api/handlers/admin_handlers as admin
import app/api/handlers/auth_handlers as auth
import app/api/web.{type Caller, type Context, SignedIn}
import app/types/app_error.{NotFound}
import app/types/user.{Admin, Member}
import gleam/http.{Get, Patch, Post}
import wisp

pub fn handle_request(
  request: wisp.Request,
  context: Context,
) -> wisp.Response {
  use request, caller <- web.middleware(request, context)
  case request.method, wisp.path_segments(request) {
    _, ["api", "v1", ..segments] -> dispatch(request, context, caller, segments)
    Get, ["health"] -> web.json_ok(encoders.ok())
    _, _ -> not_found()
  }
}

fn dispatch(
  request: wisp.Request,
  context: Context,
  caller: Caller,
  segments: List(String),
) -> wisp.Response {
  let everyone = [Member, Admin]
  case request.method, segments {
    Post, ["auth", "signup"] -> auth.signup(context, request)
    Post, ["auth", "login"] -> auth.login(context, request)
    Post, ["auth", "logout"] -> {
      use _ <- web.require_role(caller, everyone)
      case caller {
        SignedIn(token:, ..) -> auth.logout(context, token)
        web.Guest -> web.error_response(web.please_log_in)
      }
    }
    Get, ["me"] -> {
      use signed_in <- web.require_role(caller, everyone)
      auth.me(signed_in)
    }
    Patch, ["me"] -> {
      use signed_in <- web.require_role(caller, everyone)
      auth.update_me(context, request, signed_in)
    }
    Get, ["admin", "users"] -> {
      use _ <- web.require_role(caller, [Admin])
      admin.users(context, request)
    }
    Patch, ["admin", "users", user_id] -> {
      use signed_in <- web.require_role(caller, [Admin])
      admin.update_user(context, request, signed_in, user_id)
    }
    _, _ -> not_found()
  }
}

fn not_found() -> wisp.Response {
  web.error_response(NotFound("Not found"))
}
