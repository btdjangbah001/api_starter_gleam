select exists (select 1 from users where email = $1 and id <> $2) as taken;
