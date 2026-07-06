#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${API_BASE:-http://127.0.0.1:8080}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-dev-webhook-secret}"
USER_REF="${USER_REF:-demo-user-1}"
EMAIL="${SEED_EMAIL:-demo-user-1@walletops.local}"
PASSWORD="${SEED_PASSWORD:-ops-secret-1}"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/docker-compose.yml}"

post_signed() {
  local file="$1"
  local sig
  sig="$(openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" "$file" | awk '{print $NF}')"
  curl -sS -w "\nHTTP %{http_code}\n" \
    -X POST "$API_BASE/v1/webhooks/events" \
    -H "Content-Type: application/json" \
    -H "X-Signature: sha256=${sig}" \
    --data-binary @"$file"
}

echo "registering demo user (ignore conflict if exists)"
REG_CODE="$(curl -sS -o /tmp/walletops-seed-reg.json -w '%{http_code}' \
  -X POST "$API_BASE/v1/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" || true)"

if [[ "$REG_CODE" != "201" && "$REG_CODE" != "409" ]]; then
  echo "register failed HTTP $REG_CODE: $(cat /tmp/walletops-seed-reg.json 2>/dev/null || true)" >&2
  exit 1
fi

LOGIN="$(curl -sS -X POST "$API_BASE/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")"
ACCESS="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$LOGIN")"
USER_ID="$(curl -sS "$API_BASE/v1/me" -H "Authorization: Bearer $ACCESS" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"

echo "mapping user_ref=$USER_REF -> $USER_ID"
docker compose -f "$COMPOSE_FILE" exec -T postgres \
  psql -U walletops -d walletops -v ON_ERROR_STOP=1 \
  -c "UPDATE users SET user_ref = '$USER_REF' WHERE id = '$USER_ID';"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cat >"$TMPDIR/evt1.json" <<EOF
{
  "idempotency_key": "evt_seed_balance_drop_1",
  "type": "balance_drop",
  "user_ref": "$USER_REF",
  "payload": {
    "address_label": "hot-sim-1",
    "amount": 120.5,
    "asset": "USDC",
    "note": "simulated drop"
  },
  "occurred_at": "2026-07-16T10:00:00Z"
}
EOF

cat >"$TMPDIR/evt2.json" <<EOF
{
  "idempotency_key": "evt_seed_swap_quote_1",
  "type": "swap_quote",
  "user_ref": "$USER_REF",
  "payload": {
    "address_label": "hot-sim-1",
    "amount": 40,
    "asset": "ETH",
    "note": "simulated quote"
  },
  "occurred_at": "2026-07-16T10:05:00Z"
}
EOF

echo "=== event 1 ==="
post_signed "$TMPDIR/evt1.json"
echo "=== event 2 ==="
post_signed "$TMPDIR/evt2.json"

echo "=== list events ==="
curl -sS -w "\nHTTP %{http_code}\n" "$API_BASE/v1/events" \
  -H "Authorization: Bearer $ACCESS"
