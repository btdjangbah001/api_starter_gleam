import gleam/bit_array
import gleam/crypto
import gleam/string

const readable_alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

pub fn random_code(length: Int) -> String {
  crypto.strong_random_bytes(length)
  |> map_bytes_to_alphabet("")
}

pub fn new_id(prefix: String) -> String {
  prefix <> "_" <> string.lowercase(random_code(10))
}

pub fn session_token() -> String {
  crypto.strong_random_bytes(32)
  |> bit_array.base64_url_encode(False)
}

pub fn token_hash(token: String) -> String {
  crypto.hash(crypto.Sha256, bit_array.from_string(token))
  |> bit_array.base16_encode
  |> string.lowercase
}

fn map_bytes_to_alphabet(bytes: BitArray, accumulated: String) -> String {
  case bytes {
    <<byte, rest:bytes>> ->
      map_bytes_to_alphabet(
        rest,
        accumulated <> string.slice(readable_alphabet, byte % 32, 1),
      )
    _ -> accumulated
  }
}
