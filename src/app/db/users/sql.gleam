//// This module contains the code to run the sql queries defined in
//// `./src/app/db/users/sql`.
//// > 🐿️ This module was generated automatically using v4.7.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `count_admins` query
/// defined in `./src/app/db/users/sql/count_admins.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CountAdminsRow {
  CountAdminsRow(admins: Int)
}

/// Runs the `count_admins` query
/// defined in `./src/app/db/users/sql/count_admins.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn count_admins(
  db: pog.Connection,
) -> Result(pog.Returned(CountAdminsRow), pog.QueryError) {
  let decoder = {
    use admins <- decode.field(0, decode.int)
    decode.success(CountAdminsRow(admins:))
  }

  "select count(*)::int8 as admins from users where role = 'admin';
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `email_taken_by_another_user` query
/// defined in `./src/app/db/users/sql/email_taken_by_another_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type EmailTakenByAnotherUserRow {
  EmailTakenByAnotherUserRow(taken: Bool)
}

/// Runs the `email_taken_by_another_user` query
/// defined in `./src/app/db/users/sql/email_taken_by_another_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn email_taken_by_another_user(
  db: pog.Connection,
  email: String,
  arg_2: String,
) -> Result(pog.Returned(EmailTakenByAnotherUserRow), pog.QueryError) {
  let decoder = {
    use taken <- decode.field(0, decode.bool)
    decode.success(EmailTakenByAnotherUserRow(taken:))
  }

  "select exists (select 1 from users where email = $1 and id <> $2) as taken;
"
  |> pog.query
  |> pog.parameter(pog.text(email))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_credentials_by_email` query
/// defined in `./src/app/db/users/sql/find_credentials_by_email.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindCredentialsByEmailRow {
  FindCredentialsByEmailRow(
    id: String,
    role: String,
    name: String,
    email: String,
    status: String,
    created_at: Timestamp,
    password_hash: String,
  )
}

/// Runs the `find_credentials_by_email` query
/// defined in `./src/app/db/users/sql/find_credentials_by_email.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_credentials_by_email(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(FindCredentialsByEmailRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use role <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use email <- decode.field(3, decode.string)
    use status <- decode.field(4, decode.string)
    use created_at <- decode.field(5, pog.timestamp_decoder())
    use password_hash <- decode.field(6, decode.string)
    decode.success(FindCredentialsByEmailRow(
      id:,
      role:,
      name:,
      email:,
      status:,
      created_at:,
      password_hash:,
    ))
  }

  "select id, role, name, email, status, created_at at time zone 'utc' as created_at, password_hash
from users
where email = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_password_hash` query
/// defined in `./src/app/db/users/sql/find_password_hash.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindPasswordHashRow {
  FindPasswordHashRow(password_hash: String)
}

/// Runs the `find_password_hash` query
/// defined in `./src/app/db/users/sql/find_password_hash.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_password_hash(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(FindPasswordHashRow), pog.QueryError) {
  let decoder = {
    use password_hash <- decode.field(0, decode.string)
    decode.success(FindPasswordHashRow(password_hash:))
  }

  "select password_hash from users where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_user_by_id` query
/// defined in `./src/app/db/users/sql/find_user_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserByIdRow {
  FindUserByIdRow(
    id: String,
    role: String,
    name: String,
    email: String,
    status: String,
    created_at: Timestamp,
  )
}

/// Runs the `find_user_by_id` query
/// defined in `./src/app/db/users/sql/find_user_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user_by_id(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(FindUserByIdRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use role <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use email <- decode.field(3, decode.string)
    use status <- decode.field(4, decode.string)
    use created_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(FindUserByIdRow(
      id:,
      role:,
      name:,
      email:,
      status:,
      created_at:,
    ))
  }

  "select id, role, name, email, status, created_at at time zone 'utc' as created_at
from users
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_user` query
/// defined in `./src/app/db/users/sql/insert_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_user(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into users (id, role, name, email, password_hash)
values ($1, $2, $3, $4, $5);
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_users` query
/// defined in `./src/app/db/users/sql/list_users.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListUsersRow {
  ListUsersRow(
    id: String,
    role: String,
    name: String,
    email: String,
    status: String,
    created_at: Timestamp,
  )
}

/// Runs the `list_users` query
/// defined in `./src/app/db/users/sql/list_users.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_users(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ListUsersRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use role <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use email <- decode.field(3, decode.string)
    use status <- decode.field(4, decode.string)
    use created_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(ListUsersRow(id:, role:, name:, email:, status:, created_at:))
  }

  "select id, role, name, email, status, created_at at time zone 'utc' as created_at
from users
order by created_at desc
limit $1 offset $2;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `save_user_account` query
/// defined in `./src/app/db/users/sql/save_user_account.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn save_user_account(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "update users
set name = $2, email = $3, status = $4, password_hash = coalesce(nullif($5, ''), password_hash)
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
