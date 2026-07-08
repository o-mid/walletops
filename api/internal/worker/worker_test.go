package worker_test

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omid/walletops/api/internal/auth"
	"github.com/omid/walletops/api/internal/db"
	"github.com/omid/walletops/api/internal/events"
	"github.com/omid/walletops/api/internal/rules"
	"github.com/omid/walletops/api/internal/worker"
)

func TestProcessSuccess(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	userID := createUser(t, pool)
	ruleStore := rules.NewStore(pool)
	threshold := 200.0
	rule, err := ruleStore.Create(ctx, userID, rules.CreateInput{
		Name:      "drop watch",
		EventType: "balance_drop",
		Threshold: &threshold,
		Enabled:   true,
	})
	if err != nil {
		t.Fatal(err)
	}

	eventStore := events.NewStore(pool)
	ev, _, err := eventStore.CreatePending(ctx, events.CreateInput{
		UserID:         userID,
		IdempotencyKey: fmt.Sprintf("evt_ok_%d", time.Now().UnixNano()),
		Type:           "balance_drop",
		Payload:        []byte(`{"address_label":"hot-sim-1","amount":120.5,"asset":"USDC"}`),
	})
	if err != nil {
		t.Fatal(err)
	}

	claimed, err := eventStore.ClaimByID(ctx, ev.ID)
	if err != nil {
		t.Fatalf("claim: %v", err)
	}

	w := worker.New(eventStore, ruleStore, slog.Default())
	if err := w.Finish(ctx, claimed); err != nil {
		t.Fatal(err)
	}

	got, err := eventStore.GetByID(ctx, ev.ID)
	if err != nil {
		t.Fatal(err)
	}
	if got.Status != "processed" {
		t.Fatalf("status=%s", got.Status)
	}
	if got.MatchedRuleID == nil || *got.MatchedRuleID != rule.ID {
		t.Fatalf("matched_rule_id=%v want %s", got.MatchedRuleID, rule.ID)
	}
}

func TestProcessFailureIncrementsAttempts(t *testing.T) {
	pool := testPool(t)
	ctx := context.Background()
	userID := createUser(t, pool)
	eventStore := events.NewStore(pool)
	ev, _, err := eventStore.CreatePending(ctx, events.CreateInput{
		UserID:         userID,
		IdempotencyKey: fmt.Sprintf("evt_bad_%d", time.Now().UnixNano()),
		Type:           "balance_drop",
		Payload:        []byte(`["not","an","object"]`),
	})
	if err != nil {
		t.Fatal(err)
	}

	claimed, err := eventStore.ClaimByID(ctx, ev.ID)
	if err != nil {
		t.Fatalf("claim: %v", err)
	}

	w := worker.New(eventStore, rules.NewStore(pool), slog.Default())
	if err := w.Finish(ctx, claimed); err != nil {
		t.Fatal(err)
	}

	got, err := eventStore.GetByID(ctx, ev.ID)
	if err != nil {
		t.Fatal(err)
	}
	if got.AttemptCount != 1 {
		t.Fatalf("attempt_count=%d want 1", got.AttemptCount)
	}
	if got.LastError == nil || *got.LastError == "" {
		t.Fatal("expected last_error")
	}
	if got.Status != "failed" {
		t.Fatalf("status=%s want failed", got.Status)
	}
}

func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://walletops:walletops@localhost:5432/walletops?sslmode=disable"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	t.Cleanup(pool.Close)
	if err := pool.Ping(ctx); err != nil {
		t.Fatalf("ping: %v", err)
	}
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return pool
}

func createUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	store := auth.NewStore(pool)
	email := fmt.Sprintf("worker-%d@walletops.local", time.Now().UnixNano())
	u, err := store.CreateUser(context.Background(), email, "unused-hash")
	if err != nil {
		t.Fatal(err)
	}
	return u.ID
}
