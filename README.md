# Gleam API Starter

A production-shaped starting point for JSON APIs in Gleam on the BEAM: `wisp` + `mist` for HTTP, PostgreSQL via `pog` with type-safe SQL from [Squirrel](https://github.com/giacomocavalieri/squirrel) and a built-in migration runner, supervised background workers, and a load-testing kit. It ships with one complete vertical slice, user accounts and auth, that exercises every layer.

## Start a new project from it

```bash
git clone <this-repo> my_service && cd my_service
```

```bash
scripts/rename.sh my_service
```

`rename.sh <package_name> [namespace]` renames the Gleam package, the `app/` source namespace, the FFI modules and every reference to them, then deletes `build/`. Run it once, before anything else. Afterwards set `APP_NAME` / `EMAIL_FROM` in `docker-compose.dev.yml` and `.env.example`.

## What you get

| Concern | Implementation |
| --- | --- |
| HTTP | `wisp` on `mist`, CORS, per-request log line (method, path, status, duration, user), crash rescue to a JSON 500, 64 KB body limit |
| Overload protection | Lock-free admission control (`atomics`): beyond `MAX_IN_FLIGHT_REQUESTS` (default 100) requests get an immediate `503` + `Retry-After` instead of queueing until the node runs out of memory |
| Rate limiting | GCRA over ETS with lock-free compare-and-swap; one integer per key; janitor purges idle keys |
| Auth | argon2id passwords (dirty-scheduler NIF, timing-equalised for unknown emails), opaque bearer tokens stored as SHA-256 hashes, revocation, suspend-revokes-all |
| Database | `pog` pool, Squirrel-generated queries, transactions, explicit row hydration into domain types |
| Migrations | Plain `.sql` files in `priv/migrations/`, shipped inside the release and applied in order by `app/migrate` (one transaction per file, advisory-locked, tracked in `schema_migrations`) |
| Email | Queue actor with retries (5 s / 15 s / 45 s), rendering and SMTP off the request path, SMTP (STARTTLS, verified certificates, inline CID images) or console transport |
| Workers | Supervised periodic actors (rate-limit purge, session pruning) |
| Errors | One `AppError` ADT mapped exhaustively to status codes; clients always get `{ "error": "<human message>" }` |
| Ops | Multi-stage Dockerfile (non-root, `/health` health check), dev compose with Postgres + Mailpit + API capped at 1 CPU / 1 GB, CI (format, squirrel check, tests, Docker build) |
| Testing | `gleeunit` unit tests, `scripts/smoke_check.py` end-to-end, k6 load test, binary-search breaking-point finder |

## Layout

| Path | Responsibility |
| --- | --- |
| `src/app/api/` | Router, middleware (`web.gleam`), request decoding (`request.gleam`), JSON encoders, handlers |
| `src/app/services/` | Use cases: orchestration, transactions, side effects at the edges |
| `src/app/domain/` | Pure business rules (start here for your own logic) |
| `src/app/db/` | Adapters over Squirrel queries (`db/<area>/sql/*.sql` → `db/<area>/sql.gleam`) |
| `src/app/workers/` | Supervised BEAM processes |
| `src/app/email/` | Templates and transport |
| `src/app/infra/` | IDs, tokens, passwords, rate limiting, admission control |
| `src/app/types/` | Shared types (`AppError`, `User`, time helpers) |
| `priv/migrations/` | Schema migrations, applied in filename order |
| `container/` | Release entrypoints copied into the image: `start` (migrates when `MIGRATE_ON_START=true`, then runs), `migrate`, `seed` |

## The example slice

| Endpoint | Access | Notes |
| --- | --- | --- |
| `POST /api/v1/auth/signup` | public | `{ name, email, password }` → `{ token, user }`; sends a welcome email; rate-limited per client IP |
| `POST /api/v1/auth/login` | public | `{ email, password }` → `{ token, user }`; GCRA-throttled per email |
| `POST /api/v1/auth/logout` | member, admin | Revokes the presented token |
| `GET /api/v1/me` | member, admin | Current user |
| `PATCH /api/v1/me` | member, admin | `{ name?, email?, currentPassword?, newPassword? }` |
| `GET /api/v1/admin/users?limit=&offset=` | admin | Newest first, max 200 per page |
| `PATCH /api/v1/admin/users/:id` | admin | `{ status: "active" \| "suspended" }`; suspending revokes every session |
| `GET /health` | public | No database access, exempt from admission control |

To add a feature, follow the same path: migration in `priv/migrations/` → `db/<area>/sql/*.sql` → `gleam run -m squirrel` → `db/<area>.gleam` adapter → pure rules in `domain/` → use case in `services/` → handler and route in `api/`.

## Local development

Requirements: Gleam 1.18+, Erlang/OTP 29, Docker.

```bash
docker compose -f docker-compose.dev.yml up -d --build --wait
```

```bash
docker compose -f docker-compose.dev.yml exec api /app/seed
```

API at `http://localhost:4000/api/v1`, captured email at `http://localhost:8025` (Mailpit). The seed creates `admin@example.com / ChangeMe-123` (override with `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD`). Host ports are overridable (`API_PORT`, `POSTGRES_PORT`, `MAILPIT_UI_PORT`, `MAILPIT_SMTP_PORT`) so several projects from this starter can run side by side.

For a faster edit loop, run only the backing services in Docker and the API on the host:

```bash
docker compose -f docker-compose.dev.yml up -d --wait postgres mailpit
```

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:54329/app gleam run -m app/migrate
```

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:54329/app SECRET_KEY_BASE=dev-secret-key-base-that-is-long-enough-for-wisp-0123456789 EMAIL_BACKEND=console gleam run
```

> **macOS + Command Line Tools 27:** the argon2 NIF fails to link against the 27.0 SDK (`unknown architecture arm64e.x1`). Export `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk` before building. Linux and Docker are unaffected.

## Testing

```bash
gleam test
```

```bash
python3 scripts/smoke_check.py
```

Load test (isolated `app_load` database and a second API container with the same limits; live dashboard at `http://localhost:5665`, HTML report in `scripts/load/results/`):

```bash
scripts/load/run.sh
```

Find the highest sustainable request rate by binary search (each probe: 15 s warm-up, 60 s measured; pass = <1% errors, p95 < 500 ms, no dropped iterations), sampling API and Postgres CPU/memory every second:

```bash
python3 scripts/load/find_breaking_point.py 3000
```

## Writing SQL (Squirrel conventions)

Queries live in `src/app/db/<area>/sql/<query_name>.sql`. Regenerate after editing, against a database with the migrations applied (CI runs `squirrel check` to catch stale code):

```bash
DATABASE_URL=postgres://postgres:postgres@localhost:54329/app gleam run -m squirrel
```

- **Nullable columns are explicit.** Alias any column that can be null with a `?` suffix (`x.deleted_at as "deleted_at?"`), including outer-join columns and expressions. Squirrel infers nullability from query plans, which is unreliable for outer joins.
- **`timestamptz`** is read as `col at time zone 'utc'` and written as `$n::timestamp at time zone 'utc'`. Squirrel deliberately does not decode `timestamptz`.
- **Nullable parameters** are passed as `''` and unwrapped with `nullif($n, '')`. When null carries meaning, write two queries (`assign_x.sql` / `unassign_x.sql`).
- **Money** belongs in `numeric` columns but should travel as integer minor units: read `(amount * 100)::int8`, write `$n::int8 / 100.0`.
- **Lists are ID query + hydrate.** Filter/order queries return IDs; one canonical `*_by_ids.sql` query builds the read model and `database.in_id_order` restores ordering, so each aggregate has a single row mapper.

## Database migrations

Migrations are plain SQL files in `priv/migrations/`, named so they sort in the order they must run (e.g. `20261005000000_create_users_and_sessions.sql`). `priv/` ships inside the release, so the same files run everywhere:

| Where | How |
| --- | --- |
| Host | `gleam run -m app/migrate` |
| Container | `/app/migrate`, or automatically before boot with `MIGRATE_ON_START=true` (the dev compose file sets it) |

Each file runs in its own transaction, under a Postgres advisory lock so concurrent instances cannot apply the same migration twice, and is recorded in `schema_migrations`. Files are never edited after they ship: add a new one instead. Statements are split on top-level semicolons (quotes, comments and `$tag$` dollar-quoting are respected), which means statements that refuse to run inside a transaction, such as `create index concurrently`, need to be applied by hand.

Any PostgreSQL 16+ works. In production, use TLS (`?sslmode=require`) and give the app a role that owns its schema.

## Configuration

| Variable | Notes |
| --- | --- |
| `PORT` | Default 4000 |
| `APP_NAME` | Used in emails |
| `DATABASE_URL`, `DATABASE_POOL_SIZE` | Pool size 10 by default |
| `MIGRATE_ON_START` | `true` makes the container apply pending migrations before booting |
| `MAX_IN_FLIGHT_REQUESTS` | Admission limit, default 100. Throughput ≈ limit ÷ request latency, so 100 slots at ~5 ms allow ~20,000 req/s; the limit only bites when work starts queueing |
| `SECRET_KEY_BASE` | Required by wisp |
| `CORS_ALLOWED_ORIGINS` | Comma-separated origins or `*` |
| `EMAIL_BACKEND` | `smtp` (default) or `console` |
| `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_USE_TLS`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `EMAIL_FROM` | SMTP over STARTTLS with certificate verification |
| `SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD` | First admin created by `gleam run -m app/seed` / `/app/seed` |

The app fails fast at boot when a required variable is missing. Rate-limit and admission state is per node; run one replica or move those to a shared store before scaling out.
