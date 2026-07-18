# Code standards

Keep the repo readable for an interviewer who opens random files.

## Avoid

1. Comments that narrate the code (`// This function handles…`)
2. README emoji walls or marketing filler
3. Generic names: `MyApp`, `Utils`, `Helper`, `ManagerImpl`, `DataService`
4. Giant god-files and unused dependencies
5. Over-abstract ports/adapters for a small MVP
6. Fake or identical commit spam

## Prefer

### Go

- Packages by domain: `auth`, `events`, `rules`, `webhook`, `worker`, `ai`
- Interfaces at test boundaries; clear functions elsewhere
- Errors wrapped with `%w`
- Table-driven tests with short names (`ok`, `bad_sig`, `replay`)
- slog JSON with useful fields (`event_id`, `attempt`)

### Flutter

- `features/<name>/` with `data` + `presentation`
- Cubit + GetIt + go_router + Dio
- Short operational copy
- Widget tests with fakes for auth gate and lists

### README

Hand the repo to another engineer: what it is, how to run it, HMAC/idempotency/worker notes, demo path.

## Ownership

Before you claim the project in interviews:

- [ ] Explain any file in 60 seconds
- [ ] Break one test on purpose and fix it
- [ ] Draw webhook → claim → list on paper
- [ ] Answer why stdlib mux + Postgres polling is enough for this MVP
