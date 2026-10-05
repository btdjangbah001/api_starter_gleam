import gleam/time/timestamp.{type Timestamp}

pub type Role {
  Member
  Admin
}

pub type AccountStatus {
  Active
  Suspended
}

pub type User {
  User(
    id: String,
    role: Role,
    name: String,
    email: String,
    status: AccountStatus,
    created_at: Timestamp,
  )
}

pub type Credentials {
  Credentials(user: User, password_hash: String)
}

pub fn role_to_string(role: Role) -> String {
  case role {
    Member -> "member"
    Admin -> "admin"
  }
}

pub fn role_from_string(text: String) -> Result(Role, Nil) {
  case text {
    "member" -> Ok(Member)
    "admin" -> Ok(Admin)
    _ -> Error(Nil)
  }
}

pub fn account_status_to_string(status: AccountStatus) -> String {
  case status {
    Active -> "active"
    Suspended -> "suspended"
  }
}

pub fn account_status_from_string(text: String) -> Result(AccountStatus, Nil) {
  case text {
    "active" -> Ok(Active)
    "suspended" -> Ok(Suspended)
    _ -> Error(Nil)
  }
}
