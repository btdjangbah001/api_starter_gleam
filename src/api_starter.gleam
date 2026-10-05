import app/api/router
import app/api/web.{Context}
import app/config.{type Config}
import app/db/database
import app/email/transport
import app/infra/admission
import app/services/context.{Services}
import app/types/time
import app/workers/email_queue
import app/workers/jobs
import app/workers/periodic
import gleam/erlang/process
import gleam/io
import gleam/otp/static_supervisor as supervisor
import gleam/result
import mist
import pog
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()
  case config.load() |> result.try(start) {
    Ok(Nil) -> process.sleep_forever()
    Error(reason) -> {
      io.println_error("Failed to start: " <> reason)
      halt(1)
    }
  }
}

fn start(settings: Config) -> Result(Nil, String) {
  let pool_name = process.new_name("app_db_pool")
  let email_queue_name = process.new_name("app_email_queue")
  use pool <- result.try(database.pool_child_spec(
    pool_name,
    settings.database_url,
    settings.database_pool_size,
  ))
  let services =
    Services(
      db: pog.named_connection(pool_name),
      notify: email_queue.enqueue(email_queue_name, _),
      clock: time.now,
    )
  admission.install()
  let http_handler =
    wisp_mist.handler(
      router.handle_request(
        _,
        Context(
          services:,
          cors_allowed_origins: settings.cors_allowed_origins,
          max_in_flight_requests: settings.max_in_flight_requests,
        ),
      ),
      settings.secret_key_base,
    )
  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(pool)
  |> supervisor.add(periodic.supervised(jobs.purge_rate_limits()))
  |> supervisor.add(email_queue.supervised(
    email_queue_name,
    transport.from_config(settings.email_backend, settings.email_from),
    settings.app_name,
  ))
  |> supervisor.add(periodic.supervised(jobs.prune_sessions(services)))
  |> supervisor.add(
    http_handler
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(settings.port)
    |> mist.supervised,
  )
  |> supervisor.start
  |> result.replace(Nil)
  |> result.replace_error("Supervision tree failed to start")
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
