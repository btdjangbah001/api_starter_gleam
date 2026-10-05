select u.id, u.role, u.name, u.email, u.status, u.created_at at time zone 'utc' as created_at
from sessions s
join users u on u.id = s.user_id
where s.token_hash = $1 and s.revoked_at is null;
