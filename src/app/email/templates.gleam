import app/types/notification.{
  type Email, type InlineImage, type Notification, Email, WelcomeUser,
}
import gleam/list
import gleam/string

pub fn render(
  notification: Notification,
  app_name: String,
) -> Result(Email, String) {
  case notification {
    WelcomeUser(user) ->
      Ok(
        compose(
          app_name,
          user.name,
          user.email,
          "Welcome to " <> app_name,
          [
            "Hi " <> user.name <> ",",
            "Your " <> app_name <> " account is ready.",
            "If you did not create this account, you can ignore this email.",
          ],
          [],
        ),
      )
  }
}

pub fn compose(
  app_name: String,
  to_name: String,
  to_address: String,
  subject: String,
  lines: List(String),
  inline_images: List(InlineImage),
) -> Email {
  Email(
    to_name:,
    to_address:,
    subject:,
    text_body: string.join(lines, "\n\n") <> "\n\n— " <> app_name,
    html_body: html_document(app_name, subject, paragraphs(lines)),
    inline_images:,
  )
}

pub fn escape(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&#39;")
}

fn paragraphs(lines: List(String)) -> String {
  lines
  |> list.map(fn(line) { "<p>" <> escape(line) <> "</p>" })
  |> string.concat
}

fn html_document(app_name: String, title: String, content: String) -> String {
  "<!doctype html><html><head><meta charset=\"utf-8\"><title>"
  <> escape(title)
  <> "</title></head><body style=\"font-family:Arial,Helvetica,sans-serif;color:#1a1a1a;line-height:1.5\">"
  <> content
  <> "<p style=\"color:#666\">— "
  <> escape(app_name)
  <> "</p></body></html>"
}
