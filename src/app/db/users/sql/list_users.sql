select
  id,
  role,
  name,
  email,
  status,
  created_at at time zone 'utc' as created_at,
  count(*) over () as total
from users
order by created_at desc
limit $1 offset $2;
