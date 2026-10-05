import app/types/user.{type User}

pub type Notification {
  WelcomeUser(user: User)
}

pub type InlineImage {
  InlineImage(content_id: String, filename: String, png: BitArray)
}

pub type Email {
  Email(
    to_name: String,
    to_address: String,
    subject: String,
    text_body: String,
    html_body: String,
    inline_images: List(InlineImage),
  )
}
