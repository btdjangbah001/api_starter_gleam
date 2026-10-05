import app/email/templates
import app/email/transport.{type Transport}
import app/types/notification.{type Email, type Notification}
import gleam/erlang/process.{type Name, type Subject}
import gleam/int
import gleam/otp/actor
import gleam/otp/supervision
import wisp

pub type Message {
  Enqueue(Notification)
  Attempt(email: Email, attempt: Int)
  DeliveryFailed(email: Email, attempt: Int, reason: String)
}

type State {
  State(self: Subject(Message), transport: Transport, app_name: String)
}

const maximum_retries = 3

pub fn supervised(
  name: Name(Message),
  transport: Transport,
  app_name: String,
) -> supervision.ChildSpecification(Subject(Message)) {
  supervision.worker(fn() {
    actor.new_with_initialiser(1000, fn(self) {
      State(self:, transport:, app_name:)
      |> actor.initialised
      |> actor.returning(self)
      |> Ok
    })
    |> actor.named(name)
    |> actor.on_message(handle_message)
    |> actor.start
  })
}

pub fn enqueue(name: Name(Message), notification: Notification) -> Nil {
  process.send(process.named_subject(name), Enqueue(notification))
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Enqueue(notification) -> {
      process.spawn_unlinked(fn() { render_and_deliver(state, notification) })
      actor.continue(state)
    }
    Attempt(email, attempt) -> {
      process.spawn_unlinked(fn() { deliver(state, email, attempt) })
      actor.continue(state)
    }
    DeliveryFailed(email, attempt, reason) -> {
      case attempt <= maximum_retries {
        True -> {
          wisp.log_warning(
            "Email \""
            <> email.subject
            <> "\" failed (attempt "
            <> int.to_string(attempt)
            <> "), retrying: "
            <> reason,
          )
          process.send_after(
            state.self,
            backoff_ms(attempt),
            Attempt(email, attempt + 1),
          )
          Nil
        }
        False ->
          wisp.log_error(
            "Email \""
            <> email.subject
            <> "\" abandoned after "
            <> int.to_string(attempt)
            <> " attempts: "
            <> reason,
          )
      }
      actor.continue(state)
    }
  }
}

fn render_and_deliver(state: State, notification: Notification) -> Nil {
  case templates.render(notification, state.app_name) {
    Ok(email) -> deliver(state, email, 1)
    Error(reason) -> wisp.log_error("Email rendering failed: " <> reason)
  }
}

fn deliver(state: State, email: Email, attempt: Int) -> Nil {
  case state.transport.deliver(email) {
    Ok(Nil) -> Nil
    Error(reason) ->
      process.send(state.self, DeliveryFailed(email:, attempt:, reason:))
  }
}

fn backoff_ms(attempt: Int) -> Int {
  case attempt {
    1 -> 5000
    2 -> 15_000
    _ -> 45_000
  }
}
