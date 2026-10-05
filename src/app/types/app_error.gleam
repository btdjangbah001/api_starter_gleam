import pog

pub type AppError {
  BadRequest(message: String)
  Unauthorized(message: String)
  PaymentDeclined(message: String)
  Forbidden(message: String)
  NotFound(message: String)
  Conflict(message: String)
  Gone(message: String)
  TooManyRequests(message: String)
  ServiceBusy
  DatabaseFailure(cause: pog.QueryError)
  Unexpected(detail: String)
}

pub const generic_failure_message = "Something went wrong"

pub const busy_message = "The service is busy right now. Please try again in a moment."

pub fn status_code(error: AppError) -> Int {
  case error {
    BadRequest(_) -> 400
    Unauthorized(_) -> 401
    PaymentDeclined(_) -> 402
    Forbidden(_) -> 403
    NotFound(_) -> 404
    Conflict(_) -> 409
    Gone(_) -> 410
    TooManyRequests(_) -> 429
    ServiceBusy -> 503
    DatabaseFailure(_) | Unexpected(_) -> 500
  }
}

pub fn client_message(error: AppError) -> String {
  case error {
    BadRequest(message)
    | Unauthorized(message)
    | PaymentDeclined(message)
    | Forbidden(message)
    | NotFound(message)
    | Conflict(message)
    | Gone(message)
    | TooManyRequests(message) -> message
    ServiceBusy -> busy_message
    DatabaseFailure(_) | Unexpected(_) -> generic_failure_message
  }
}

pub fn from_database(error: pog.QueryError) -> AppError {
  case error {
    pog.ConnectionUnavailable -> ServiceBusy
    _ -> DatabaseFailure(error)
  }
}
