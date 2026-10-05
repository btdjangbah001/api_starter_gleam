import app/db/sql_script
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import pog
import simplifile

pub type Migration {
  Migration(version: String, statements: List(String))
}

const migration_lock_key = 7_239_001

pub fn directory() -> String {
  priv_directory() <> "/migrations"
}

pub fn load(from directory: String) -> Result(List(Migration), String) {
  use entries <- result.try(
    simplifile.read_directory(directory)
    |> result.map_error(fn(error) {
      "Cannot read " <> directory <> ": " <> string.inspect(error)
    }),
  )
  entries
  |> list.filter(string.ends_with(_, ".sql"))
  |> list.sort(string.compare)
  |> list.try_map(fn(file_name) {
    simplifile.read(directory <> "/" <> file_name)
    |> result.map(fn(script) {
      Migration(
        version: string.drop_end(file_name, 4),
        statements: sql_script.split_statements(script),
      )
    })
    |> result.map_error(fn(error) {
      "Cannot read " <> file_name <> ": " <> string.inspect(error)
    })
  })
}

pub fn apply_pending(
  connection: pog.Connection,
  migrations: List(Migration),
) -> Result(List(String), String) {
  use _ <- result.try(
    run(
      connection,
      "create table if not exists schema_migrations (
       version text primary key,
       applied_at timestamptz not null default now()
     )",
      [],
    ),
  )
  list.try_fold(migrations, [], fn(applied, migration) {
    use was_applied <- result.map(apply(connection, migration))
    case was_applied {
      True -> [migration.version, ..applied]
      False -> applied
    }
  })
  |> result.map(list.reverse)
}

fn apply(
  connection: pog.Connection,
  migration: Migration,
) -> Result(Bool, String) {
  pog.transaction(connection, fn(tx) {
    use _ <- result.try(
      run(tx, "select true from pg_advisory_xact_lock($1)", [
        pog.int(migration_lock_key),
      ]),
    )
    use already_applied <- result.try(is_applied(tx, migration.version))
    case already_applied {
      True -> Ok(False)
      False -> {
        use _ <- result.try(
          list.try_each(migration.statements, fn(statement) {
            run(tx, statement, [])
            |> result.map_error(fn(reason) {
              migration.version
              <> " failed on statement:\n"
              <> string.slice(statement, 0, 400)
              <> "\n"
              <> reason
            })
          }),
        )
        run(tx, "insert into schema_migrations (version) values ($1)", [
          pog.text(migration.version),
        ])
        |> result.replace(True)
      }
    }
  })
  |> result.map_error(fn(error) {
    case error {
      pog.TransactionRolledBack(reason) -> reason
      pog.TransactionQueryError(cause) -> string.inspect(cause)
    }
  })
}

fn is_applied(
  connection: pog.Connection,
  version: String,
) -> Result(Bool, String) {
  pog.query("select count(*)::int8 from schema_migrations where version = $1")
  |> pog.parameter(pog.text(version))
  |> pog.returning(decode.field(0, decode.int, decode.success))
  |> pog.execute(connection)
  |> result.map(fn(returned) { returned.rows == [1] })
  |> result.map_error(string.inspect)
}

fn run(
  connection: pog.Connection,
  sql: String,
  parameters: List(pog.Value),
) -> Result(Int, String) {
  parameters
  |> list.fold(pog.query(sql), pog.parameter)
  |> pog.execute(connection)
  |> result.map(fn(returned) { returned.count })
  |> result.map_error(string.inspect)
}

pub fn describe(applied: List(String)) -> String {
  case applied {
    [] -> "Database is up to date."
    _ ->
      "Applied "
      <> int.to_string(list.length(applied))
      <> " migration(s):\n  "
      <> string.join(applied, "\n  ")
  }
}

@external(erlang, "app_ffi", "priv_directory")
fn priv_directory() -> String
