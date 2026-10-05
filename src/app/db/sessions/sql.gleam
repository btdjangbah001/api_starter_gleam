//// This module contains the code to run the sql queries defined in
//// `./src/app/db/sessions/sql`.
//// > 🐿️ This module was generated automatically using v4.7.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/time/timestamp.{type Timestamp}
import pog

/// Runs the `create_session` query
/// defined in `./src/app/db/sessions/sql/create_session.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_session(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into sessions (token_hash, user_id) values ($1, $2);
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `find_session_user` query
/// defined in `./src/app/db/sessions/sql/find_session_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.7.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindSessionUserRow {
  FindSessionUserRow(
    id: String,
    role: String,
    name: String,
    email: String,
    status: String,
    created_at: Timestamp,
  )
}

/// Runs the `find_session_user` query
/// defined in `./src/app/db/sessions/sql/find_session_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_session_user(
  db: pog.Connection,
  s_token_hash: String,
) -> Result(pog.Returned(FindSessionUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use role <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use email <- decode.field(3, decode.string)
    use status <- decode.field(4, decode.string)
    use created_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(FindSessionUserRow(
      id:,
      role:,
      name:,
      email:,
      status:,
      created_at:,
    ))
  }

  "select u.id, u.role, u.name, u.email, u.status, u.created_at at time zone 'utc' as created_at
from sessions s
join users u on u.id = s.user_id
where s.token_hash = $1 and s.revoked_at is null;
"
  |> pog.query
  |> pog.parameter(pog.text(s_token_hash))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `prune_revoked_sessions` query
/// defined in `./src/app/db/sessions/sql/prune_revoked_sessions.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn prune_revoked_sessions(
  db: pog.Connection,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "delete from sessions where revoked_at < now() - interval '30 days';
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `revoke_session` query
/// defined in `./src/app/db/sessions/sql/revoke_session.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn revoke_session(
  db: pog.Connection,
  token_hash: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "update sessions set revoked_at = now() where token_hash = $1 and revoked_at is null;
"
  |> pog.query
  |> pog.parameter(pog.text(token_hash))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `revoke_user_sessions` query
/// defined in `./src/app/db/sessions/sql/revoke_user_sessions.sql`.
///
/// > 🐿️ This function was generated automatically using v4.7.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn revoke_user_sessions(
  db: pog.Connection,
  user_id: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "update sessions set revoked_at = now() where user_id = $1 and revoked_at is null;
"
  |> pog.query
  |> pog.parameter(pog.text(user_id))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
