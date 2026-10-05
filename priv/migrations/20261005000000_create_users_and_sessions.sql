create table users (
  id text primary key,
  role text not null default 'member' check (role in ('member', 'admin')),
  name text not null,
  email text not null unique check (email = lower(email)),
  password_hash text not null,
  status text not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now()
);

create index users_created_idx on users (created_at desc);

create table sessions (
  token_hash text primary key,
  user_id text not null references users (id) on delete cascade,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index sessions_live_user_idx on sessions (user_id) where revoked_at is null;
create index sessions_revoked_idx on sessions (revoked_at) where revoked_at is not null;
