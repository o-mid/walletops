# WalletOps Companion — Full Product Requirements

**Status:** Spec only. Implement in a **separate** git repo. Never build inside Career OS.  
**Owner:** Omid Mirzaei  
**Audience:** Portfolio / interview proof for Senior Flutter + light Go/backend  
**Last updated:** 2026-07-16

---

## 1. One-line description

A personal ops console for **simulated** wallet events: ingest signed webhooks, match alert rules, process jobs with retries, and summarize selected events with a schema-checked AI endpoint — Flutter client + Go API.

---

## 2. Why this exists (hiring signal)

| Signal | How MVP proves it |
|--------|-------------------|
| Flutter production patterns | Auth gate, secure token storage, Bloc, Dio, go_router, list/detail, tests |
| Backend ownership | Go REST, JWT, Postgres, migrations |
| Async / reliability | Webhook HMAC, idempotency key, worker retries, status machine |
| AI product sense | Structured summarize call + refusal/empty handling — not a chat toy |
| Ship quality | Docker Compose, GitHub Actions, health endpoint, structured logs |
| Domain fit | Wallet **ops** language without custody / NDA material |

---

## 3. Problem statement

Power users (and interviewers) need a believable slice of “ops around a wallet product”: events arrive from partners, rules fire, a worker processes the queue, and an engineer can ask “what happened here?” without dumping raw JSON.

Real wallets involve keys and custody. This product **simulates** partner webhooks and address activity so the architecture is real and the domain is familiar — without cloning Best Wallet or touching real funds.

---

## 4. Goals / non-goals

### Goals (MVP)

1. Register / login; mobile keeps session in secure storage.
2. Create / edit / delete alert rules (event type + optional threshold).
3. Accept `POST /webhooks/events` with HMAC signature; store events idempotently.
4. Background worker transitions events: `pending → processing → processed | failed` with limited retries.
5. Event feed + detail on mobile; filter by status.
6. “Explain” on a selection of events → AI returns **fixed JSON schema** summary.
7. `GET /health` shows API up, DB ping, last worker tick, rough error counts.
8. Local demo via Docker Compose; CI on PR; README that runs in under 10 minutes.

### Non-goals (explicit)

- Real seed phrases, private keys, MPC, Fireblocks, on-chain sends
- Best Wallet / proprietary API clones or screenshots of internal tools
- Multi-tenant SaaS, billing, orgs, RBAC beyond single user
- Perfect UI polish / design system
- Mobile offline-first sync (defer)
- Redis/SQS in MVP (in-process worker + DB polling is enough)
- Multiple LLM providers (one provider behind an interface)

---

## 5. Personas

1. **Primary:** You — demoing architecture in interviews (5-minute happy path).
2. **Secondary:** Fictional power user watching simulated address / partner events.

---

## 6. User stories (MVP)

| ID | Story | Acceptance |
|----|-------|------------|
| US-01 | Register with email + password | 201; password hashed (bcrypt/argon2); duplicate email → 409 |
| US-02 | Login | Access + refresh JWT; refresh rotates or invalidates old refresh per chosen policy |
| US-03 | Mobile stores tokens securely | FlutterSecureStorage (or equivalent); logout clears |
| US-04 | Create alert rule | Fields: name, event_type, optional numeric threshold, enabled |
| US-05 | List / update / delete rules | Soft-disable via `enabled` ok; hard delete ok |
| US-06 | Partner sends webhook | Valid HMAC → 202/200 + persist; invalid → 401; replay same idempotency key → 200 same resource, no duplicate |
| US-07 | Worker processes events | Pending picked; retries on failure; dead after N attempts with `failed` |
| US-08 | Mobile event feed | Paginated list; status chip; pull-to-refresh |
| US-09 | Event detail | Raw payload (pretty JSON), status history or timestamps, matched rule if any |
| US-10 | Explain selection | Select 1–20 events → summary object with title, bullets, risk_level, follow_ups |
| US-11 | Health | Unauth or light-auth health for demo; includes worker heartbeat |
| US-12 | Seed demo data | Script or admin endpoint (dev only) posts sample webhooks |

---

## 7. Functional requirements

### 7.1 Auth

- Email + password only for MVP.
- Access token TTL: 15m–1h. Refresh: 7–30d.
- Protect all routes except register, login, health, webhook.
- Webhook auth = HMAC, not user JWT.

### 7.2 Alert rules

| Field | Type | Notes |
|-------|------|-------|
| id | uuid | |
| user_id | uuid | owner |
| name | string | max 80 |
| event_type | string | enum-like: `tx_simulated`, `balance_drop`, `partner_kyc`, `swap_quote`, `custom` |
| threshold | decimal nullable | e.g. amount below which rule matches |
| enabled | bool | |
| created_at / updated_at | timestamptz | |

Matching (MVP): on ingest or in worker, if `event.type == rule.event_type` and (threshold null OR payload.amount ≤ threshold) → set `matched_rule_id`.

### 7.3 Events

| Field | Type | Notes |
|-------|------|-------|
| id | uuid | |
| user_id | uuid | from webhook routing key or header mapping |
| idempotency_key | string | unique per user |
| type | string | |
| payload | jsonb | |
| status | enum | `pending`, `processing`, `processed`, `failed` |
| attempt_count | int | |
| last_error | text nullable | |
| matched_rule_id | uuid nullable | |
| received_at | timestamptz | |
| processed_at | timestamptz nullable | |

Webhook body example:

```json
{
  "idempotency_key": "evt_01HXYZ",
  "type": "balance_drop",
  "user_ref": "demo-user-1",
  "payload": {
    "address_label": "hot-sim-1",
    "amount": 120.5,
    "asset": "USDC",
    "note": "simulated drop"
  },
  "occurred_at": "2026-07-16T10:00:00Z"
}
```

HMAC: `X-Signature: sha256=<hex>` over raw body with shared secret. Reject skew optional (skip clock skew in MVP unless easy).

### 7.4 Worker

- Poll `pending` (and `failed` with attempt_count < max) every few seconds.
- Claim with `UPDATE … WHERE status = pending RETURNING` or equivalent to avoid double process.
- Max attempts: 5. Backoff: simple linear or exponential capped at 60s.
- Processing work MVP: validate payload shape, match rules, mark processed. (No external calls.)
- Persist `last_error` on failure.

### 7.5 AI summarize

`POST /ai/summarize`

Request:

```json
{
  "event_ids": ["…"]
}
```

Rules:

- Max 20 events; must belong to caller.
- Build a compact prompt from structured fields only (type, amount, status, rule name) — not free-form user chat.
- Model must return JSON matching schema; on parse failure → 502 with clear error, no hallucinated fallback prose to client.
- Persist request hash + response for audit.

Response schema (strict):

```json
{
  "title": "string",
  "summary_bullets": ["string"],
  "risk_level": "low|medium|high|unknown",
  "follow_ups": ["string"],
  "event_ids": ["string"]
}
```

Dev mode: if `AI_PROVIDER=mock`, return deterministic fixture without calling network.

### 7.6 Mobile screens (MVP)

1. Login / Register  
2. Home / Events list  
3. Event detail  
4. Alert rules list + create/edit sheet  
5. Explain result screen / bottom sheet  
6. Simple settings: logout, API base URL (debug)

---

## 8. Non-functional requirements

| Area | Requirement |
|------|-------------|
| Performance | List endpoints p95 < 300ms locally with 1k events |
| Security | No secrets in repo; `.env.example` only; webhook secret + JWT secret required |
| Privacy | No real PII beyond email; no production user data |
| Observability | Structured JSON logs; request_id middleware; worker logs attempt/result |
| Reliability | Idempotent webhooks; worker safe under two replicas (DB claim) |
| Testability | Table-driven Go tests; Flutter widget tests for auth gate + event list |
| Portability | `docker compose up` boots API + Postgres + (optional) adminer |

---

## 9. Architecture

```
[Flutter app]
    |  HTTPS JSON + JWT
    v
[Go API] ---- JWT auth
    |---- CRUD alert rules / events
    |---- POST /ai/summarize --> LLM (or mock)
    |---- POST /webhooks/events (HMAC)
    v
[Postgres]
    ^
[Worker goroutine in same process for MVP]
```

### Suggested repo layout (separate repo)

```
walletops/
  README.md
  docker-compose.yml
  .env.example
  .github/workflows/ci.yml
  api/
    cmd/server/main.go
    internal/…   (auth, events, rules, webhook, worker, ai, db)
    migrations/
    go.mod
  mobile/
    pubspec.yaml
    lib/…        (app, features, core)
    test/
  scripts/
    seed_webhooks.sh
  docs/
    threat-model.md
    architecture.md
```

### Stack choices (locked for MVP)

| Layer | Choice | Why |
|-------|--------|-----|
| Mobile | Flutter 3.x, Dart 3 | Track A |
| State | Bloc / Cubit | Matches your production habit |
| DI | GetIt | Matches your habit |
| Nav | go_router | Matches your habit |
| HTTP | Dio | Matches your habit |
| Secure storage | flutter_secure_storage | Session |
| API | Go 1.22+ | Track B proof |
| Router | chi or stdlib mux | Keep boring |
| DB | Postgres 16 + pgx or sqlc | Real migrations |
| Migrations | goose or golang-migrate | |
| Auth | golang-jwt + bcrypt | |
| AI | OpenAI-compatible HTTP client + mock | Cost control |
| CI | GitHub Actions | go test + flutter analyze/test |
| Deploy (stretch) | Fly.io / Railway free tier for API only | Optional after MVP |

---

## 10. API contract (MVP)

Base: `/v1`

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| POST | `/auth/register` | none | `{email,password}` |
| POST | `/auth/login` | none | → `{access_token,refresh_token,expires_in}` |
| POST | `/auth/refresh` | refresh | |
| GET | `/me` | JWT | |
| GET/POST | `/alert-rules` | JWT | |
| GET/PATCH/DELETE | `/alert-rules/{id}` | JWT | |
| GET | `/events` | JWT | `?status=&cursor=` |
| GET | `/events/{id}` | JWT | |
| POST | `/webhooks/events` | HMAC | |
| POST | `/ai/summarize` | JWT | |
| GET | `/health` | none | |

Errors: JSON `{ "error": { "code": "...", "message": "..." } }` — keep codes stable.

---

## 11. Security / threat model (summary)

Full page: `docs/threat-model.md` in the app repo.

Threats to handle in MVP:

1. Forged webhooks → HMAC required  
2. Token theft on device → secure storage; short access TTL  
3. Prompt injection via event payload → only pass allowlisted fields to model  
4. Secret leak in git → pre-commit ignore + CI secret scan optional  
5. Enumerating other users’ events → ownership checks on every ID  

Out of scope MVP: SSO, device binding, WAF, rate limit beyond basic IP throttle stub.

---

## 12. Testing requirements

### API

- Webhook valid / invalid signature  
- Idempotent replay  
- Worker marks processed; failure increments attempts  
- Auth register/login/refresh happy + bad password  
- Summarize rejects foreign event IDs  
- Mock AI returns schema  

### Mobile

- Auth gate redirects when no token  
- Event list renders fixtures  
- Logout clears storage (unit/bloc test)

### CI

- `go test ./...`  
- `dart analyze` + `flutter test`  
- Fail PR on either red  

---

## 13. Demo script (must work)

1. `docker compose up -d`  
2. Register in app (or curl)  
3. Create rule `balance_drop` threshold 200  
4. `scripts/seed_webhooks.sh` with secret  
5. See event appear; status → processed  
6. Select events → Explain → schema UI  
7. Show health endpoint  

Target: **under 5 minutes** once env is set.

---

## 14. Success criteria (definition of done)

- [ ] Happy-path demo works cold from README  
- [ ] Webhook HMAC + idempotency tests green  
- [ ] Flutter auth gate + list tests green  
- [ ] CI green on main  
- [ ] Threat model one-pager committed  
- [ ] README: architecture diagram (mermaid or png), env vars, demo script  
- [ ] No `.env`, keys, or NDA material in git history  
- [ ] You can explain every package and endpoint without notes  

---

## 15. Out of scope backlog (post-MVP)

- Redis queue / SQS  
- Push notifications  
- Multi-device refresh family  
- Eval harness for AI summaries  
- Feature flags  
- Offline cache  

---

## 16. Open decisions (defaults chosen)

| Question | MVP default |
|----------|-------------|
| LLM provider | Mock by default; OpenAI-compatible via env |
| Jobs | In-process goroutine + DB poll |
| DB | Postgres only (Compose). No SQLite split. |
| User routing for webhooks | `user_ref` maps to user id in a simple `webhook_clients` or fixed demo mapping table |
| Package name / app id | `com.omid.walletops` (change if you prefer) |

---

## 17. Interview talking points (after ship)

1. Why HMAC + idempotency on partner webhooks  
2. How you claim rows safely for the worker  
3. Why AI gets allowlisted fields only  
4. Flutter session lifecycle (refresh, 401 retry once)  
5. What you would change for multi-instance workers  

---

## Related files

- [`architecture.md`](./architecture.md)
- [`threat-model.md`](./threat-model.md)

