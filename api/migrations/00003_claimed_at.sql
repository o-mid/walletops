-- +goose Up
ALTER TABLE events
    ADD COLUMN claimed_at timestamptz;

CREATE INDEX events_claim_queue_idx ON events (status, claimed_at, received_at);

-- +goose Down
DROP INDEX IF EXISTS events_claim_queue_idx;
ALTER TABLE events DROP COLUMN IF EXISTS claimed_at;
