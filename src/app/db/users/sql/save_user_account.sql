update users
set name = $2, email = $3, status = $4, password_hash = coalesce(nullif($5, ''), password_hash)
where id = $1;
