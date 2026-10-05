update sessions set revoked_at = now() where token_hash = $1 and revoked_at is null;
