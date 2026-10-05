pub type Policy {
  Policy(bucket: String, limit: Int, period_seconds: Int)
}

pub const login_attempts = Policy(
  bucket: "login",
  limit: 10,
  period_seconds: 900,
)

pub const signups = Policy(bucket: "signup", limit: 20, period_seconds: 3600)

pub fn allow(policy: Policy, key: String) -> Bool {
  gcra_allow(policy.bucket, key, policy.period_seconds, policy.limit)
}

pub fn create_table() -> Nil {
  rate_limit_table_create()
}

pub fn purge_expired() -> Int {
  rate_limit_purge_expired()
}

@external(erlang, "app_ffi", "gcra_allow")
fn gcra_allow(
  bucket: String,
  key: String,
  period_seconds: Int,
  limit: Int,
) -> Bool

@external(erlang, "app_ffi", "rate_limit_table_create")
fn rate_limit_table_create() -> Nil

@external(erlang, "app_ffi", "rate_limit_purge_expired")
fn rate_limit_purge_expired() -> Int
