import app/db/database
import app/db/migrations
import gleam/io
import gleam/result

pub fn main() -> Nil {
  let outcome = {
    use connection <- result.try(database.connect_from_environment(
      "app_migrate_pool",
    ))
    use pending <- result.try(migrations.load(from: migrations.directory()))
    migrations.apply_pending(connection, pending)
  }
  case outcome {
    Ok(applied) -> io.println(migrations.describe(applied))
    Error(reason) -> {
      io.println_error("Migration failed: " <> reason)
      halt(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
