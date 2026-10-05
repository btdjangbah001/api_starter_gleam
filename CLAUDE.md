# Engineering Guidelines

## Role & Mindset
Operate as a Staff/Principal engineer building production backends: precise, contract-first, resource-efficient. No junior-level scripts; design for real concurrency and real failure modes.

## Why Gleam on the BEAM
1. **Constrained infrastructure.** Lightweight processes handle thousands of concurrent requests (aggressive client polling included) in a small memory and CPU budget.
2. **Native background work.** Periodic jobs, queues and retries are supervised BEAM processes, not extra infrastructure such as Redis.
3. **The compiler is the guardrail.** Model states with algebraic data types and exhaustive pattern matching so edge cases are compile errors. If it compiles, it should run.

## Coding Standards

### Self-documenting code (no comments)
- Do not write comments, docstrings or block comments. Exceptions: a non-obvious mathematical formula, or an Erlang FFI bridge detail.
- Use descriptive, domain-specific names. Extract complex conditions into small, precisely named functions.

### Functional purity & pipelines
- Prefer the pipeline operator (`|>`) so data flows through transformations.
- Keep domain logic pure; push side effects (database writes, email, time, randomness) to the edges (services, workers, db).
- Handle errors exclusively with `Result` and `Option`; map them to the `AppError` ADT. Never crash silently.

### Algorithms
- Choose the most resource-efficient known algorithm, not the first that comes to mind (e.g. GCRA for rate limiting, lock-free `atomics`/ETS over serialising processes, set/dict lookups over repeated list scans).

### Serialization & database
- Write explicit, type-safe decoders/encoders for every request and response; never leak `Dynamic` into output.
- Use `pog` with raw, optimised SQL generated into typed functions by Squirrel. Follow the Squirrel conventions in the README (explicit `?` nullability, `at time zone 'utc'`, `nullif` parameters, ID query + hydrate).
- Schema changes are new, append-only files in `priv/migrations/`; never edit a migration that has shipped.
- Lock rows with `SELECT … FOR UPDATE` inside transactions for check-then-write operations, always in a consistent lock order.

### Dependencies
- Add packages with the CLI (`gleam add <pkg>`) so the latest versions resolve; never hand-write versions from memory.

## Project Structure
- `src/app/api/` – HTTP transport: routes, middleware, request decoding, JSON encoders, handlers.
- `src/app/services/` – use cases: orchestration, transactions, notifications.
- `src/app/domain/` – pure business rules.
- `src/app/db/` – infrastructure: Squirrel queries, adapters, row hydration.
- `src/app/workers/` – supervised background processes.
- `src/app/infra/` – technical building blocks (ids, tokens, passwords, rate limits, admission control).
- `src/app/types/` – shared types.

Do not put logic in the router. Each new feature follows migration → SQL → adapter → domain → service → handler → route.

## Deployment
- Containerised (Dockerfile) and deployable to Dokploy or any container platform; give the container a restart policy.
- Configuration and secrets come only from environment variables.
- Verify changes with `gleam test`, `scripts/smoke_check.py`, and the load-test kit before shipping performance-sensitive work.
