-- +goose Up
ALTER TABLE users
    ADD COLUMN user_ref text UNIQUE;

CREATE INDEX users_user_ref_idx ON users (user_ref) WHERE user_ref IS NOT NULL;

-- +goose Down
DROP INDEX IF EXISTS users_user_ref_idx;
ALTER TABLE users DROP COLUMN IF EXISTS user_ref;
