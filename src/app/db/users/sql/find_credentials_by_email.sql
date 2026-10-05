select id, role, name, email, status, created_at at time zone 'utc' as created_at, password_hash
from users
where email = $1;
