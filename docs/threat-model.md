# Threat model (MVP)

Scope: local/demo WalletOps Companion — Flutter client + Go API + Postgres. No real custody or production PII.

## Assets

- User credentials (email/password hash)
- JWT access + refresh tokens
- Webhook shared secret
- Event payloads (simulated wallet ops data)
- AI prompt/response audit rows

## Threats and controls

| Threat | Control in MVP |
|--------|----------------|
| Forged partner webhooks | HMAC-SHA256 over raw body (`X-Signature: sha256=<hex>`); reject bad sigs with 401 |
| Replay / duplicate ingest | Unique `(user_id, idempotency_key)`; replay returns same event |
| Stolen device tokens | `flutter_secure_storage`; short access TTL; refresh rotation on use |
| Prompt injection via payload | Summarize prompt uses allowlisted fields only (type, amount, status, rule name) |
| Cross-user event access | Ownership checks on event IDs for list/detail/summarize |
| Secret leak in git | `.env` gitignored; `.env.example` only |

## Out of scope (MVP)

SSO, device binding, WAF, production rate limits, multi-tenant RBAC, real on-chain keys.

## Residual risk

Demo secrets in compose defaults are for local use only. Rotate before any shared deploy. Mock AI avoids network exfiltration in default config (`AI_PROVIDER=mock`).
