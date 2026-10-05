select id, role, name, email, status, created_at at time zone 'utc' as created_at
from users
where id = $1;
