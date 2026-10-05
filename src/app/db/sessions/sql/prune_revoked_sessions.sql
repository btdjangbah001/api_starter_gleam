delete from sessions where revoked_at < now() - interval '30 days';
