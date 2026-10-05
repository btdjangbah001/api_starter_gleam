import app/db/sessions
import app/infra/rate_limit
import app/services/context.{type Services}
import app/workers/periodic.{type Schedule, Schedule}
import gleam/string
import wisp

const rate_limit_purge_interval_ms = 60_000

const session_prune_interval_ms = 3_600_000

pub fn purge_rate_limits() -> Schedule {
  Schedule(
    ..periodic.every(rate_limit_purge_interval_ms, fn() {
      let _ = rate_limit.purge_expired()
      Nil
    }),
    prepare: rate_limit.create_table,
  )
}

pub fn prune_sessions(services: Services) -> Schedule {
  periodic.every(session_prune_interval_ms, fn() {
    case sessions.prune_revoked(services.db) {
      Ok(_) -> Nil
      Error(error) ->
        wisp.log_error("Session pruning failed: " <> string.inspect(error))
    }
  })
}
