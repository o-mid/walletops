-- +goose Up
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text NOT NULL UNIQUE,
    password_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE refresh_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash text NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE alert_rules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name text NOT NULL,
    event_type text NOT NULL,
    threshold numeric,
    enabled boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT alert_rules_name_len CHECK (char_length(name) <= 80)
);

CREATE TABLE events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    idempotency_key text NOT NULL,
    type text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'pending',
    attempt_count integer NOT NULL DEFAULT 0,
    last_error text,
    matched_rule_id uuid REFERENCES alert_rules (id) ON DELETE SET NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    CONSTRAINT events_status_check CHECK (status IN ('pending', 'processing', 'processed', 'failed')),
    CONSTRAINT events_user_idempotency UNIQUE (user_id, idempotency_key)
);

CREATE TABLE ai_summaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    request_hash text NOT NULL,
    event_ids uuid[] NOT NULL,
    response jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens (user_id);
CREATE INDEX alert_rules_user_id_idx ON alert_rules (user_id);
CREATE INDEX events_user_id_status_idx ON events (user_id, status);
CREATE INDEX events_received_at_idx ON events (received_at DESC);
CREATE INDEX ai_summaries_user_id_idx ON ai_summaries (user_id);

-- +goose Down
DROP TABLE IF EXISTS ai_summaries;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS alert_rules;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;
