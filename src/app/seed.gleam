import app/db/database
import app/db/users
import app/infra/ids
import app/infra/passwords
import app/types/user
import envoy
import gleam/io
import gleam/result
import gleam/string
import pog

pub fn main() -> Nil {
  case seed() {
    Ok(summary) -> io.println(summary)
    Error(reason) -> io.println_error("Seeding failed: " <> reason)
  }
}

fn seed() -> Result(String, String) {
  use connection <- result.try(database.connect_from_environment(
    "app_seed_pool",
  ))
  use admins <- result.try(
    users.count_admins(connection) |> result.map_error(string.inspect),
  )
  case admins {
    0 -> create_admin(connection)
    _ -> Ok("An admin already exists; nothing to do.")
  }
}

fn create_admin(connection: pog.Connection) -> Result(String, String) {
  let email =
    envoy.get("SEED_ADMIN_EMAIL") |> result.unwrap("admin@example.com")
  let password =
    envoy.get("SEED_ADMIN_PASSWORD") |> result.unwrap("ChangeMe-123")
  use password_hash <- result.try(passwords.hash(password))
  use _ <- result.map(
    users.insert(
      connection,
      users.NewUser(
        id: ids.new_id("usr"),
        role: user.Admin,
        name: "Administrator",
        email: string.lowercase(email),
        password_hash:,
      ),
    )
    |> result.map_error(fn(error) { string.inspect(error) }),
  )
  "Created admin "
  <> email
  <> " (set SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD to choose)"
}
