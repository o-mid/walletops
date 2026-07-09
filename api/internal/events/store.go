package events

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Event struct {
	ID             string          `json:"id"`
	UserID         string          `json:"user_id"`
	IdempotencyKey string          `json:"idempotency_key"`
	Type           string          `json:"type"`
	Payload        json.RawMessage `json:"payload"`
	Status         string          `json:"status"`
	AttemptCount   int             `json:"attempt_count"`
	LastError      *string         `json:"last_error"`
	MatchedRuleID  *string         `json:"matched_rule_id"`
	ReceivedAt     time.Time       `json:"received_at"`
	ProcessedAt    *time.Time      `json:"processed_at"`
}

type CreateInput struct {
	UserID         string
	IdempotencyKey string
	Type           string
	Payload        json.RawMessage
}

type Store struct {
	pool *pgxpool.Pool
}

func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

func (s *Store) UserIDByRef(ctx context.Context, userRef string) (string, error) {
	var id string
	err := s.pool.QueryRow(ctx, `
		SELECT id::text FROM users WHERE user_ref = $1
	`, userRef).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrUnknownUserRef
	}
	if err != nil {
		return "", fmt.Errorf("user by ref: %w", err)
	}
	return id, nil
}

func (s *Store) SetUserRef(ctx context.Context, userID, userRef string) error {
	tag, err := s.pool.Exec(ctx, `
		UPDATE users SET user_ref = $2 WHERE id = $1
	`, userID, userRef)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return fmt.Errorf("user_ref taken")
		}
		return fmt.Errorf("set user_ref: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CreatePending inserts a pending event. On idempotency conflict, returns the existing row and created=false.
func (s *Store) CreatePending(ctx context.Context, in CreateInput) (Event, bool, error) {
	var e Event
	err := s.pool.QueryRow(ctx, `
		INSERT INTO events (user_id, idempotency_key, type, payload, status)
		VALUES ($1, $2, $3, $4, 'pending')
		ON CONFLICT (user_id, idempotency_key) DO NOTHING
		RETURNING id::text, user_id::text, idempotency_key, type, payload, status,
		          attempt_count, last_error, matched_rule_id::text, received_at, processed_at
	`, in.UserID, in.IdempotencyKey, in.Type, in.Payload).Scan(
		&e.ID, &e.UserID, &e.IdempotencyKey, &e.Type, &e.Payload, &e.Status,
		&e.AttemptCount, &e.LastError, &e.MatchedRuleID, &e.ReceivedAt, &e.ProcessedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		existing, getErr := s.GetByIdempotency(ctx, in.UserID, in.IdempotencyKey)
		if getErr != nil {
			return Event{}, false, getErr
		}
		return existing, false, nil
	}
	if err != nil {
		return Event{}, false, fmt.Errorf("create event: %w", err)
	}
	return e, true, nil
}

func (s *Store) GetByIdempotency(ctx context.Context, userID, key string) (Event, error) {
	var e Event
	err := s.pool.QueryRow(ctx, `
		SELECT id::text, user_id::text, idempotency_key, type, payload, status,
		       attempt_count, last_error, matched_rule_id::text, received_at, processed_at
		FROM events
		WHERE user_id = $1 AND idempotency_key = $2
	`, userID, key).Scan(
		&e.ID, &e.UserID, &e.IdempotencyKey, &e.Type, &e.Payload, &e.Status,
		&e.AttemptCount, &e.LastError, &e.MatchedRuleID, &e.ReceivedAt, &e.ProcessedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Event{}, ErrNotFound
	}
	if err != nil {
		return Event{}, fmt.Errorf("get by idempotency: %w", err)
	}
	return e, nil
}

func (s *Store) ListForUser(ctx context.Context, userID, status string) ([]Event, error) {
	var (
		rows pgx.Rows
		err  error
	)
	if status == "" {
		rows, err = s.pool.Query(ctx, `
			SELECT id::text, user_id::text, idempotency_key, type, payload, status,
			       attempt_count, last_error, matched_rule_id::text, received_at, processed_at
			FROM events
			WHERE user_id = $1
			ORDER BY received_at DESC
			LIMIT 100
		`, userID)
	} else {
		rows, err = s.pool.Query(ctx, `
			SELECT id::text, user_id::text, idempotency_key, type, payload, status,
			       attempt_count, last_error, matched_rule_id::text, received_at, processed_at
			FROM events
			WHERE user_id = $1 AND status = $2
			ORDER BY received_at DESC
			LIMIT 100
		`, userID, status)
	}
	if err != nil {
		return nil, fmt.Errorf("list events: %w", err)
	}
	defer rows.Close()

	out := make([]Event, 0)
	for rows.Next() {
		var e Event
		if err := rows.Scan(
			&e.ID, &e.UserID, &e.IdempotencyKey, &e.Type, &e.Payload, &e.Status,
			&e.AttemptCount, &e.LastError, &e.MatchedRuleID, &e.ReceivedAt, &e.ProcessedAt,
		); err != nil {
			return nil, fmt.Errorf("scan event: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (s *Store) GetForUserIDs(ctx context.Context, userID string, ids []string) (map[string]Event, error) {
	if len(ids) == 0 {
		return map[string]Event{}, nil
	}
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, user_id::text, idempotency_key, type, payload, status,
		       attempt_count, last_error, matched_rule_id::text, received_at, processed_at
		FROM events
		WHERE user_id = $1 AND id = ANY($2::uuid[])
	`, userID, ids)
	if err != nil {
		return nil, fmt.Errorf("get events by ids: %w", err)
	}
	defer rows.Close()

	out := make(map[string]Event, len(ids))
	for rows.Next() {
		var e Event
		if err := rows.Scan(
			&e.ID, &e.UserID, &e.IdempotencyKey, &e.Type, &e.Payload, &e.Status,
			&e.AttemptCount, &e.LastError, &e.MatchedRuleID, &e.ReceivedAt, &e.ProcessedAt,
		); err != nil {
			return nil, fmt.Errorf("scan event: %w", err)
		}
		out[e.ID] = e
	}
	return out, rows.Err()
}

func (s *Store) GetForUser(ctx context.Context, userID, id string) (Event, error) {
	var e Event
	err := s.pool.QueryRow(ctx, `
		SELECT id::text, user_id::text, idempotency_key, type, payload, status,
		       attempt_count, last_error, matched_rule_id::text, received_at, processed_at
		FROM events
		WHERE id = $1 AND user_id = $2
	`, id, userID).Scan(
		&e.ID, &e.UserID, &e.IdempotencyKey, &e.Type, &e.Payload, &e.Status,
		&e.AttemptCount, &e.LastError, &e.MatchedRuleID, &e.ReceivedAt, &e.ProcessedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Event{}, ErrNotFound
	}
	if err != nil {
		return Event{}, fmt.Errorf("get event: %w", err)
	}
	return e, nil
}

func (s *Store) GetByID(ctx context.Context, id string) (Event, error) {
	var e Event
	err := s.pool.QueryRow(ctx, `
		SELECT id::text, user_id::text, idempotency_key, type, payload, status,
		       attempt_count, last_error, matched_rule_id::text, received_at, processed_at
		FROM events
		WHERE id = $1
	`, id).Scan(
		&e.ID, &e.UserID, &e.IdempotencyKey, &e.Type, &e.Payload, &e.Status,
		&e.AttemptCount, &e.LastError, &e.MatchedRuleID, &e.ReceivedAt, &e.ProcessedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Event{}, ErrNotFound
	}
	if err != nil {
		return Event{}, fmt.Errorf("get event by id: %w", err)
	}
	return e, nil
}

func (s *Store) ClaimNext(ctx context.Context, maxAttempts int) (Event, error) {
	var e Event
	err := s.pool.QueryRow(ctx, `
		UPDATE events
		SET status = 'processing'
		WHERE id = (
			SELECT id FROM events
			WHERE status = 'pending'
			   OR (
			        status = 'failed'
			        AND attempt_count < $1
			        AND COALESCE(processed_at, received_at) <= now() - make_interval(secs => LEAST(60, GREATEST(2, attempt_count * 2)))
			   )
			ORDER BY received_at ASC
			LIMIT 1
			FOR UPDATE SKIP LOCKED
		)
		RETURNING id::text, user_id::text, idempotency_key, type, payload, status,
		          attempt_count, last_error, matched_rule_id::text, received_at, processed_at
	`, maxAttempts).Scan(
		&e.ID, &e.UserID, &e.IdempotencyKey, &e.Type, &e.Payload, &e.Status,
		&e.AttemptCount, &e.LastError, &e.MatchedRuleID, &e.ReceivedAt, &e.ProcessedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Event{}, ErrNotFound
	}
	if err != nil {
		return Event{}, fmt.Errorf("claim event: %w", err)
	}
	return e, nil
}

func (s *Store) ClaimByID(ctx context.Context, id string) (Event, error) {
	var e Event
	err := s.pool.QueryRow(ctx, `
		UPDATE events
		SET status = 'processing'
		WHERE id = $1 AND status IN ('pending', 'failed')
		RETURNING id::text, user_id::text, idempotency_key, type, payload, status,
		          attempt_count, last_error, matched_rule_id::text, received_at, processed_at
	`, id).Scan(
		&e.ID, &e.UserID, &e.IdempotencyKey, &e.Type, &e.Payload, &e.Status,
		&e.AttemptCount, &e.LastError, &e.MatchedRuleID, &e.ReceivedAt, &e.ProcessedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Event{}, ErrNotFound
	}
	if err != nil {
		return Event{}, fmt.Errorf("claim event by id: %w", err)
	}
	return e, nil
}

func (s *Store) MarkProcessed(ctx context.Context, id string, matchedRuleID *string) error {
	tag, err := s.pool.Exec(ctx, `
		UPDATE events
		SET status = 'processed',
		    matched_rule_id = $2,
		    processed_at = now(),
		    last_error = NULL
		WHERE id = $1 AND status = 'processing'
	`, id, matchedRuleID)
	if err != nil {
		return fmt.Errorf("mark processed: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) MarkAttemptFailed(ctx context.Context, id, lastError string) (Event, error) {
	var e Event
	err := s.pool.QueryRow(ctx, `
		UPDATE events
		SET attempt_count = attempt_count + 1,
		    last_error = $2,
		    status = 'failed',
		    processed_at = now()
		WHERE id = $1 AND status = 'processing'
		RETURNING id::text, user_id::text, idempotency_key, type, payload, status,
		          attempt_count, last_error, matched_rule_id::text, received_at, processed_at
	`, id, lastError).Scan(
		&e.ID, &e.UserID, &e.IdempotencyKey, &e.Type, &e.Payload, &e.Status,
		&e.AttemptCount, &e.LastError, &e.MatchedRuleID, &e.ReceivedAt, &e.ProcessedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Event{}, ErrNotFound
	}
	if err != nil {
		return Event{}, fmt.Errorf("mark attempt failed: %w", err)
	}
	return e, nil
}
