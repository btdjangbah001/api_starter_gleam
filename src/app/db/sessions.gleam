import app/db/database
import app/db/sessions/sql
import app/db/users
import app/types/app_error.{type AppError}
import app/types/user.{type User}
import gleam/option.{type Option, None, Some}
import gleam/result
import pog

pub fn create(
  connection: pog.Connection,
  token_hash: String,
  user_id: String,
) -> Result(Int, AppError) {
  database.affected(sql.create_session(connection, token_hash, user_id))
}

pub fn find_user(
  connection: pog.Connection,
  token_hash: String,
) -> Result(Option(User), AppError) {
  use found <- result.try(
    database.first(sql.find_session_user(connection, token_hash)),
  )
  case found {
    None -> Ok(None)
    Some(row) ->
      users.hydrate(
        id: row.id,
        role: row.role,
        name: row.name,
        email: row.email,
        status: row.status,
        created_at: row.created_at,
      )
      |> result.map(Some)
  }
}

pub fn revoke(
  connection: pog.Connection,
  token_hash: String,
) -> Result(Int, AppError) {
  database.affected(sql.revoke_session(connection, token_hash))
}

pub fn revoke_all_for_user(
  connection: pog.Connection,
  user_id: String,
) -> Result(Int, AppError) {
  database.affected(sql.revoke_user_sessions(connection, user_id))
}

pub fn prune_revoked(connection: pog.Connection) -> Result(Int, AppError) {
  database.affected(sql.prune_revoked_sessions(connection))
}
