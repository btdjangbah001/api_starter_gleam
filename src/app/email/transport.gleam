import app/config.{type EmailBackend, type SmtpSettings, ConsoleEmail, SmtpEmail}
import app/types/notification.{type Email, type InlineImage}
import gleam/int
import gleam/io
import gleam/list
import gleam/string

pub type Transport {
  Transport(deliver: fn(Email) -> Result(Nil, String))
}

pub fn from_config(backend: EmailBackend, from_header: String) -> Transport {
  case backend {
    ConsoleEmail -> console()
    SmtpEmail(settings) -> smtp(settings, from_header)
  }
}

pub fn console() -> Transport {
  Transport(deliver: fn(email) {
    io.println(
      "[email] to="
      <> email.to_address
      <> " subject=\""
      <> email.subject
      <> "\" inline_images="
      <> int.to_string(list.length(email.inline_images))
      <> "\n"
      <> email.text_body,
    )
    Ok(Nil)
  })
}

pub fn smtp(settings: SmtpSettings, from_header: String) -> Transport {
  let envelope_sender = address_of(from_header)
  Transport(deliver: fn(email) {
    let message =
      encode_message(
        from_header,
        email.to_name,
        email.to_address,
        email.subject,
        email.text_body,
        email.html_body,
        email.inline_images,
      )
    send(
      envelope_sender,
      email.to_address,
      message,
      settings.host,
      settings.port,
      settings.username,
      settings.password,
      settings.use_starttls,
    )
  })
}

fn address_of(from_header: String) -> String {
  case string.split_once(from_header, "<") {
    Ok(#(_, rest)) ->
      case string.split_once(rest, ">") {
        Ok(#(address, _)) -> string.trim(address)
        Error(Nil) -> string.trim(rest)
      }
    Error(Nil) -> string.trim(from_header)
  }
}

@external(erlang, "app_smtp_ffi", "encode_message")
fn encode_message(
  from_header: String,
  to_name: String,
  to_address: String,
  subject: String,
  text_body: String,
  html_body: String,
  inline_images: List(InlineImage),
) -> BitArray

@external(erlang, "app_smtp_ffi", "send")
fn send(
  envelope_sender: String,
  recipient: String,
  message: BitArray,
  host: String,
  port: Int,
  username: String,
  password: String,
  use_starttls: Bool,
) -> Result(Nil, String)
