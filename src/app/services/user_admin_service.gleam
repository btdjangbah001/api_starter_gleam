import app/db/database
import app/db/sessions
import app/db/users
import app/services/context.{type Services}
import app/types/app_error.{type AppError, Conflict, NotFound}
import app/types/user.{type AccountStatus, type User}
import gleam/bool
import gleam/int
import gleam/result

const maximum_page_size = 200

pub fn list_users(
  services: Services,
  limit: Int,
  offset: Int,
) -> Result(List(User), AppError) {
  users.list(
    services.db,
    int.clamp(limit, min: 1, max: maximum_page_size),
    int.max(offset, 0),
  )
}

pub fn set_status(
  services: Services,
  acting_admin: User,
  user_id: String,
  status: AccountStatus,
) -> Result(User, AppError) {
  use <- bool.guard(
    user_id == acting_admin.id && status == user.Suspended,
    Error(Conflict("You cannot suspend your own account")),
  )
  database.transaction(services.db, fn(tx) {
    use existing <- result.try(database.require_found(
      users.find_by_id(tx, user_id),
      NotFound("User not found"),
    ))
    use saved <- result.try(users.set_status(tx, existing, status))
    use _ <- result.map(case saved.status {
      user.Suspended -> sessions.revoke_all_for_user(tx, saved.id)
      user.Active -> Ok(0)
    })
    saved
  })
}
