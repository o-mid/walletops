package ai

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Store struct {
	pool *pgxpool.Pool
}

func NewStore(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

func (s *Store) Save(ctx context.Context, userID, requestHash string, eventIDs []string, summary Summary) error {
	raw, err := json.Marshal(summary)
	if err != nil {
		return err
	}
	_, err = s.pool.Exec(ctx, `
		INSERT INTO ai_summaries (user_id, request_hash, event_ids, response)
		VALUES ($1, $2, $3::uuid[], $4::jsonb)
	`, userID, requestHash, eventIDs, raw)
	if err != nil {
		return fmt.Errorf("save ai summary: %w", err)
	}
	return nil
}
