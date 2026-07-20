# WalletOps Companion

Personal ops console for **simulated** wallet events. Partners post signed webhooks; Postgres stores them idempotently; a Go worker claims and processes them against alert rules; a Flutter client lists events and can request a schema-checked summary.

No real custody, keys, or on-chain sends.

## Why the backend matters

The interview-friendly core is reliability around ingest and jobs:

| Concern | Behavior |
|---------|----------|
| Forged webhooks | HMAC-SHA256 over the raw body (`X-Signature: sha256=<hex>`) |
| Duplicate delivery | Unique `(user_id, idempotency_key)`; replay returns the same event (`200`) |
| Concurrent workers | `FOR UPDATE SKIP LOCKED` claim — safe under two pollers |
| Crash mid-process | `claimed_at` lease; stale `processing` rows become claimable again |
| Retries | Failed attempts back off (capped at 60s) up to 5 tries |

Open `api/internal/webhook/handler_test.go` (`replay`) and `api/internal/worker/worker_test.go` (`TestConcurrentClaimNoDoubleProcess`, `TestReclaimExpiredProcessingLease`).

## Architecture

See [`docs/architecture.md`](docs/architecture.md). Threat notes: [`docs/threat-model.md`](docs/threat-model.md).

```mermaid
sequenceDiagram
  participant P as Partner
  participant A as API
  participant D as DB
  participant W as Worker
  participant M as Mobile
  P->>A: HMAC webhook
  A->>D: pending event
  W->>D: claim + process
  M->>A: list events / summarize
```

## Env

Copy `.env.example` → `.env` (compose already injects defaults for local):

| Var | Purpose |
|-----|---------|
| `DATABASE_URL` | Postgres DSN |
| `JWT_SECRET` | Access token signing |
| `WEBHOOK_SECRET` | HMAC for `/v1/webhooks/events` |
| `AI_PROVIDER` | `mock` (default) or `openai` |
| `AI_API_KEY` | Required if `openai` |
| `HTTP_ADDR` | API bind (`:8080`) |

## Demo (< 5 minutes)

```bash
# 1) API + Postgres
docker compose up --build -d
curl -s http://127.0.0.1:8080/v1/health
# expect status=ok, worker ticks, queue.by_status

# 2) Seed user + two signed events (maps user_ref=demo-user-1)
./scripts/seed_webhooks.sh

# 3) Optional: create a rule via curl after login from seed output,
#    or use the mobile app (Events → Rules).

# 4) Mobile
cd mobile
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:8080
# Android emulator: API_BASE=http://10.0.2.2:8080
```

In the app: sign in as `demo-user-1@walletops.local` / `ops-secret-1` → Events (status → processed) → open an event → **Explain** (mock AI by default).

## Tests

CI runs the same checks on every pull request (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)): Go tests against Postgres, Flutter analyze + test against a Compose API.

```bash
# API (stop api container first if it races the worker)
cd api && DATABASE_URL='postgres://walletops:walletops@localhost:5432/walletops?sslmode=disable' go test ./...

# Mobile (API up on :8080 for integration tests)
cd mobile && flutter pub get && flutter analyze && flutter test --dart-define=API_BASE=http://127.0.0.1:8080
```

Module path: `github.com/omid/walletops/api`.
