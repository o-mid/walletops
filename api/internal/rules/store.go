package rules

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Rule struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Name      string    `json:"name"`
	EventType string    `json:"event_type"`
	Threshold *float64  `json:"threshold"`
	Enabled   bool      `json:"enabled"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CreateInput struct {
	Name      string
	EventType string
	Threshold *float64
	Enabled   bool
}

type UpdateInput struct {
	Name      *string
	EventType *string
	Threshold **float64
	Enabled   *bool
}

type Store struct {
	pool *pgxpool.Pool
}

func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

func (s *Store) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	out := make(map[string]string)
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, name FROM alert_rules WHERE id = ANY($1::uuid[])
	`, ids)
	if err != nil {
		return nil, fmt.Errorf("rule names: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var id, name string
		if err := rows.Scan(&id, &name); err != nil {
			return nil, fmt.Errorf("scan rule name: %w", err)
		}
		out[id] = name
	}
	return out, rows.Err()
}

func (s *Store) EnabledByUserAndType(ctx context.Context, userID, eventType string) ([]Rule, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, user_id::text, name, event_type, threshold, enabled, created_at, updated_at
		FROM alert_rules
		WHERE user_id = $1 AND event_type = $2 AND enabled = true
		ORDER BY created_at ASC
	`, userID, eventType)
	if err != nil {
		return nil, fmt.Errorf("list matching rules: %w", err)
	}
	defer rows.Close()

	out := make([]Rule, 0)
	for rows.Next() {
		var r Rule
		if err := rows.Scan(&r.ID, &r.UserID, &r.Name, &r.EventType, &r.Threshold, &r.Enabled, &r.CreatedAt, &r.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan rule: %w", err)
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Store) Create(ctx context.Context, userID string, in CreateInput) (Rule, error) {
	var r Rule
	err := s.pool.QueryRow(ctx, `
		INSERT INTO alert_rules (user_id, name, event_type, threshold, enabled)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id::text, user_id::text, name, event_type, threshold, enabled, created_at, updated_at
	`, userID, in.Name, in.EventType, in.Threshold, in.Enabled).Scan(
		&r.ID, &r.UserID, &r.Name, &r.EventType, &r.Threshold, &r.Enabled, &r.CreatedAt, &r.UpdatedAt,
	)
	if err != nil {
		return Rule{}, fmt.Errorf("create rule: %w", err)
	}
	return r, nil
}

func (s *Store) ListByUser(ctx context.Context, userID string) ([]Rule, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id::text, user_id::text, name, event_type, threshold, enabled, created_at, updated_at
		FROM alert_rules
		WHERE user_id = $1
		ORDER BY created_at DESC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("list rules: %w", err)
	}
	defer rows.Close()

	out := make([]Rule, 0)
	for rows.Next() {
		var r Rule
		if err := rows.Scan(&r.ID, &r.UserID, &r.Name, &r.EventType, &r.Threshold, &r.Enabled, &r.CreatedAt, &r.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan rule: %w", err)
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Store) GetForUser(ctx context.Context, userID, id string) (Rule, error) {
	var r Rule
	err := s.pool.QueryRow(ctx, `
		SELECT id::text, user_id::text, name, event_type, threshold, enabled, created_at, updated_at
		FROM alert_rules
		WHERE id = $1 AND user_id = $2
	`, id, userID).Scan(
		&r.ID, &r.UserID, &r.Name, &r.EventType, &r.Threshold, &r.Enabled, &r.CreatedAt, &r.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Rule{}, ErrNotFound
	}
	if err != nil {
		return Rule{}, fmt.Errorf("get rule: %w", err)
	}
	return r, nil
}

func (s *Store) UpdateForUser(ctx context.Context, userID, id string, in UpdateInput) (Rule, error) {
	current, err := s.GetForUser(ctx, userID, id)
	if err != nil {
		return Rule{}, err
	}

	name := current.Name
	if in.Name != nil {
		name = *in.Name
	}
	eventType := current.EventType
	if in.EventType != nil {
		eventType = *in.EventType
	}
	threshold := current.Threshold
	if in.Threshold != nil {
		threshold = *in.Threshold
	}
	enabled := current.Enabled
	if in.Enabled != nil {
		enabled = *in.Enabled
	}

	var r Rule
	err = s.pool.QueryRow(ctx, `
		UPDATE alert_rules
		SET name = $3,
		    event_type = $4,
		    threshold = $5,
		    enabled = $6,
		    updated_at = now()
		WHERE id = $1 AND user_id = $2
		RETURNING id::text, user_id::text, name, event_type, threshold, enabled, created_at, updated_at
	`, id, userID, name, eventType, threshold, enabled).Scan(
		&r.ID, &r.UserID, &r.Name, &r.EventType, &r.Threshold, &r.Enabled, &r.CreatedAt, &r.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Rule{}, ErrNotFound
	}
	if err != nil {
		return Rule{}, fmt.Errorf("update rule: %w", err)
	}
	return r, nil
}

func (s *Store) DeleteForUser(ctx context.Context, userID, id string) error {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM alert_rules WHERE id = $1 AND user_id = $2
	`, id, userID)
	if err != nil {
		return fmt.Errorf("delete rule: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
