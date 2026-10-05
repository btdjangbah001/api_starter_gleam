import app/types/notification.{type Notification}
import gleam/time/timestamp.{type Timestamp}
import pog

pub type Services {
  Services(
    db: pog.Connection,
    notify: fn(Notification) -> Nil,
    clock: fn() -> Timestamp,
  )
}
