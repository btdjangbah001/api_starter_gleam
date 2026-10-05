import app/db/database
import app/db/sessions
import app/db/users
import app/domain/validation
import app/infra/ids
import app/infra/passwords
import app/infra/rate_limit
import app/services/context.{type Services}
import app/types/app_error.{
  type AppError, BadRequest, Conflict, DatabaseFailure, Forbidden,
  TooManyRequests, Unauthorized, Unexpected,
}
import app/types/notification
import app/types/user.{type User, User}
import gleam/bool
import gleam/option.{type Option, None, Some}
import gleam/result
import pog

pub type Session {
  Session(token: String, user: User)
}

pub type SignupInput {
  SignupInput(name: String, email: String, password: String)
}

pub type LoginInput {
  LoginInput(email: String, password: String)
}

pub type ProfileChanges {
  ProfileChanges(
    name: Option(String),
    email: Option(String),
    current_password: Option(String),
    new_password: Option(String),
  )
}

pub const email_taken = Conflict("An account with this email already exists")

pub const suspended_account = Forbidden("Account suspended. Contact support.")

const incorrect_credentials = Unauthorized("Email or password is incorrect")

pub fn signup(
  services: Services,
  input: SignupInput,
  client_key: String,
) -> Result(Session, AppError) {
  use <- bool.guard(
    !rate_limit.allow(rate_limit.signups, client_key),
    Error(TooManyRequests(
      "Too many sign-up attempts. Please try again in a little while.",
    )),
  )
  use name <- result.try(checked(validation.full_name(input.name)))
  use email <- result.try(checked(validation.email(input.email)))
  use password <- result.try(checked(validation.password(input.password)))
  use already_registered <- result.try(users.email_belongs_to_another_user(
    services.db,
    email,
    "",
  ))
  use <- bool.guard(already_registered, Error(email_taken))
  use password_hash <- result.try(hash_password(password))
  use account <- result.try(
    users.insert(
      services.db,
      users.NewUser(
        id: ids.new_id("usr"),
        role: user.Member,
        name:,
        email:,
        password_hash:,
      ),
    )
    |> conflict_on_unique_violation(email_taken),
  )
  use session <- result.map(open_session(services, account))
  services.notify(notification.WelcomeUser(account))
  session
}

pub fn login(
  services: Services,
  input: LoginInput,
) -> Result(Session, AppError) {
  let email = input.email |> validation.email |> result.unwrap(input.email)
  use <- bool.guard(
    !rate_limit.allow(rate_limit.login_attempts, email),
    Error(TooManyRequests(
      "Too many sign-in attempts. Please wait a few minutes and try again.",
    )),
  )
  use found <- result.try(users.find_credentials_by_email(services.db, email))
  let password_matches = case found {
    Some(credentials) ->
      passwords.verify(input.password, credentials.password_hash)
    None -> passwords.burn_verification_time(input.password)
  }
  case found, password_matches {
    Some(credentials), True ->
      case credentials.user.status {
        user.Suspended -> Error(suspended_account)
        user.Active -> open_session(services, credentials.user)
      }
    _, _ -> Error(incorrect_credentials)
  }
}

pub fn authenticate(
  services: Services,
  token: String,
) -> Result(Option(User), AppError) {
  sessions.find_user(services.db, ids.token_hash(token))
}

pub fn logout(services: Services, token: String) -> Result(Nil, AppError) {
  sessions.revoke(services.db, ids.token_hash(token))
  |> result.replace(Nil)
}

pub fn update_profile(
  services: Services,
  current: User,
  changes: ProfileChanges,
) -> Result(User, AppError) {
  use name <- result.try(apply_optional(
    changes.name,
    current.name,
    validation.full_name,
  ))
  use email <- result.try(apply_optional(
    changes.email,
    current.email,
    validation.email,
  ))
  use email_conflict <- result.try(users.email_belongs_to_another_user(
    services.db,
    email,
    current.id,
  ))
  use <- bool.guard(email_conflict, Error(email_taken))
  use new_password_hash <- result.try(apply_password_change(
    services,
    current,
    changes,
  ))
  users.save(services.db, User(..current, name:, email:), new_password_hash)
  |> conflict_on_unique_violation(email_taken)
}

pub fn hash_password(password: String) -> Result(String, AppError) {
  passwords.hash(password) |> result.map_error(Unexpected)
}

pub fn checked(outcome: Result(value, String)) -> Result(value, AppError) {
  result.map_error(outcome, BadRequest)
}

pub fn conflict_on_unique_violation(
  outcome: Result(value, AppError),
  conflict: AppError,
) -> Result(value, AppError) {
  case outcome {
    Error(DatabaseFailure(pog.ConstraintViolated(..))) -> Error(conflict)
    other -> other
  }
}

fn open_session(
  services: Services,
  account: User,
) -> Result(Session, AppError) {
  let token = ids.session_token()
  use _ <- result.map(sessions.create(
    services.db,
    ids.token_hash(token),
    account.id,
  ))
  Session(token:, user: account)
}

fn apply_optional(
  proposed: Option(String),
  current: String,
  validate: fn(String) -> Result(String, String),
) -> Result(String, AppError) {
  case proposed {
    Some(raw) -> checked(validate(raw))
    None -> Ok(current)
  }
}

fn apply_password_change(
  services: Services,
  current: User,
  changes: ProfileChanges,
) -> Result(Option(String), AppError) {
  case changes.new_password {
    None -> Ok(None)
    Some(new_password) -> {
      use current_password <- result.try(option.to_result(
        changes.current_password,
        BadRequest("Current password is required"),
      ))
      use stored_hash <- result.try(database.require_found(
        users.find_password_hash(services.db, current.id),
        Unauthorized("Please log in again"),
      ))
      use <- bool.guard(
        !passwords.verify(current_password, stored_hash),
        Error(BadRequest("Current password is incorrect")),
      )
      use validated <- result.try(checked(validation.password(new_password)))
      hash_password(validated) |> result.map(Some)
    }
  }
}
