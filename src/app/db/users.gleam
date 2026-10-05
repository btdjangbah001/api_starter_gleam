import app/db/database
import app/db/users/sql
import app/types/app_error.{type AppError}
import app/types/user.{
  type AccountStatus, type Credentials, type Role, type User, Credentials, User,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import pog

pub type NewUser {
  NewUser(
    id: String,
    role: Role,
    name: String,
    email: String,
    password_hash: String,
  )
}

pub fn hydrate(
  id id: String,
  role role: String,
  name name: String,
  email email: String,
  status status: String,
  created_at created_at: Timestamp,
) -> Result(User, AppError) {
  use role <- result.try(database.column(role, user.role_from_string, "role"))
  use status <- result.map(database.column(
    status,
    user.account_status_from_string,
    "account status",
  ))
  User(id:, role:, name:, email:, status:, created_at:)
}

pub fn find_by_id(
  connection: pog.Connection,
  user_id: String,
) -> Result(Option(User), AppError) {
  use found <- result.try(
    database.first(sql.find_user_by_id(connection, user_id)),
  )
  case found {
    None -> Ok(None)
    Some(row) ->
      hydrate(
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

pub fn find_credentials_by_email(
  connection: pog.Connection,
  email: String,
) -> Result(Option(Credentials), AppError) {
  use found <- result.try(
    database.first(sql.find_credentials_by_email(connection, email)),
  )
  case found {
    None -> Ok(None)
    Some(row) ->
      hydrate(
        id: row.id,
        role: row.role,
        name: row.name,
        email: row.email,
        status: row.status,
        created_at: row.created_at,
      )
      |> result.map(fn(account) {
        Some(Credentials(user: account, password_hash: row.password_hash))
      })
  }
}

pub fn find_password_hash(
  connection: pog.Connection,
  user_id: String,
) -> Result(Option(String), AppError) {
  database.first(sql.find_password_hash(connection, user_id))
  |> result.map(option.map(_, fn(row) { row.password_hash }))
}

pub fn email_belongs_to_another_user(
  connection: pog.Connection,
  email: String,
  excluded_user_id: String,
) -> Result(Bool, AppError) {
  database.single(sql.email_taken_by_another_user(
    connection,
    email,
    excluded_user_id,
  ))
  |> result.map(fn(row) { row.taken })
}

pub fn insert(
  connection: pog.Connection,
  new_user: NewUser,
) -> Result(User, AppError) {
  use _ <- result.try(
    database.affected(sql.insert_user(
      connection,
      new_user.id,
      user.role_to_string(new_user.role),
      new_user.name,
      new_user.email,
      new_user.password_hash,
    )),
  )
  database.require_found(
    find_by_id(connection, new_user.id),
    app_error.Unexpected("Inserted user vanished"),
  )
}

pub fn save(
  connection: pog.Connection,
  account: User,
  new_password_hash: Option(String),
) -> Result(User, AppError) {
  use _ <- result.try(
    database.affected(sql.save_user_account(
      connection,
      account.id,
      account.name,
      account.email,
      user.account_status_to_string(account.status),
      option.unwrap(new_password_hash, ""),
    )),
  )
  database.require_found(
    find_by_id(connection, account.id),
    app_error.NotFound("User not found"),
  )
}

pub fn set_status(
  connection: pog.Connection,
  account: User,
  status: AccountStatus,
) -> Result(User, AppError) {
  save(connection, User(..account, status:), None)
}

pub fn list(
  connection: pog.Connection,
  limit: Int,
  offset: Int,
) -> Result(List(User), AppError) {
  use found <- result.try(
    database.rows(sql.list_users(connection, limit, offset)),
  )
  list.try_map(found, fn(row) {
    hydrate(
      id: row.id,
      role: row.role,
      name: row.name,
      email: row.email,
      status: row.status,
      created_at: row.created_at,
    )
  })
}

pub fn count_admins(connection: pog.Connection) -> Result(Int, AppError) {
  database.single(sql.count_admins(connection))
  |> result.map(fn(row) { row.admins })
}
