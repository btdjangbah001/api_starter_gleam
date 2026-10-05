import argus
import gleam/result

const timing_equaliser_hash = "$argon2id$v=13$m=19456,t=2,p=1$5pCTIblfGSMjsSPWluRN+A$Z9P05ZU+HasthIt0QDxvv8p+LZOqgiqCWM2uGR2Ut6E"

pub fn hash(password: String) -> Result(String, String) {
  argus.hasher()
  |> argus.hash(password)
  |> result.map(fn(output) { output.encoded_hash })
  |> result.replace_error("Password hashing failed")
}

pub fn verify(password: String, encoded_hash: String) -> Bool {
  argus.verify(encoded_hash, password) == Ok(True)
}

pub fn burn_verification_time(password: String) -> Bool {
  let _ = verify(password, timing_equaliser_hash)
  False
}
