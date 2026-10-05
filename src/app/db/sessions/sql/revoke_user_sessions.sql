update sessions set revoked_at = now() where user_id = $1 and revoked_at is null;
