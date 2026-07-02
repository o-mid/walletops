# WalletOps Companion

Personal ops console for simulated wallet events: signed webhook ingest, alert rules, a retrying worker, and schema-checked AI summaries. Flutter client talks to a Go API over Postgres.

## Local

```bash
cp .env.example .env
docker compose up --build
```

API listens on `http://localhost:8080`. Migrations run on API boot.

```bash
curl -s http://localhost:8080/v1/health
# {"status":"ok"}
```

Env vars are listed in `.env.example`. Module path under `api/` is a placeholder — change before publishing.
