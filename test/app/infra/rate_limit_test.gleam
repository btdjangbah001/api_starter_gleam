import app/infra/ids
import app/infra/rate_limit.{Policy}

pub fn allows_a_burst_up_to_the_limit_then_refuses_test() {
  rate_limit.create_table()
  let policy = Policy(bucket: "test-burst", limit: 3, period_seconds: 60)
  let key = ids.random_code(12)
  assert rate_limit.allow(policy, key)
  assert rate_limit.allow(policy, key)
  assert rate_limit.allow(policy, key)
  assert !rate_limit.allow(policy, key)
}

pub fn keys_are_limited_independently_test() {
  rate_limit.create_table()
  let policy = Policy(bucket: "test-keys", limit: 1, period_seconds: 60)
  let first = ids.random_code(12)
  let second = ids.random_code(12)
  assert rate_limit.allow(policy, first)
  assert !rate_limit.allow(policy, first)
  assert rate_limit.allow(policy, second)
}
