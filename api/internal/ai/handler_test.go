package ai_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omid/walletops/api/internal/ai"
	"github.com/omid/walletops/api/internal/auth"
	"github.com/omid/walletops/api/internal/db"
	"github.com/omid/walletops/api/internal/events"
	"github.com/omid/walletops/api/internal/httpapi"
	"github.com/omid/walletops/api/internal/rules"
)

func TestSummarizeMockOK(t *testing.T) {
	pool := testPool(t)
	h := newTestServer(t, pool)
	owner := register(t, h, uniqueEmail("ai-owner"))
	evID := createEvent(t, pool, owner.ID, "balance_drop")

	status, body := doJSON(t, h, http.MethodPost, "/v1/ai/summarize", owner.Token, map[string]any{
		"event_ids": []string{evID},
	})
	if status != http.StatusOK {
		t.Fatalf("status=%d body=%s", status, body)
	}
	var summary ai.Summary
	mustDecode(t, body, &summary)
	if err := ai.ValidateSummary(summary); err != nil {
		t.Fatal(err)
	}
	if len(summary.EventIDs) != 1 || summary.EventIDs[0] != evID {
		t.Fatalf("event_ids=%v", summary.EventIDs)
	}
}

func TestSummarizeRejectForeignEvent(t *testing.T) {
	pool := testPool(t)
	h := newTestServer(t, pool)
	owner := register(t, h, uniqueEmail("ai-owner2"))
	other := register(t, h, uniqueEmail("ai-other"))
	foreignID := createEvent(t, pool, other.ID, "swap_quote")

	status, body := doJSON(t, h, http.MethodPost, "/v1/ai/summarize", owner.Token, map[string]any{
		"event_ids": []string{foreignID},
	})
	if status != http.StatusNotFound {
		t.Fatalf("status=%d body=%s", status, body)
	}
}

func TestSummarizeMax20(t *testing.T) {
	pool := testPool(t)
	h := newTestServer(t, pool)
	owner := register(t, h, uniqueEmail("ai-max"))
	ids := make([]string, 21)
	for i := range ids {
		ids[i] = fmt.Sprintf("00000000-0000-4000-8000-%012d", i+1)
	}
	status, body := doJSON(t, h, http.MethodPost, "/v1/ai/summarize", owner.Token, map[string]any{
		"event_ids": ids,
	})
	if status != http.StatusBadRequest {
		t.Fatalf("status=%d body=%s", status, body)
	}
}

type testUser struct {
	ID    string
	Token string
}

func newTestServer(t *testing.T, pool *pgxpool.Pool) http.Handler {
	t.Helper()
	authStore := auth.NewStore(pool)
	tokens := auth.NewTokenIssuer("test-jwt-secret")
	authHandler := auth.NewHandler(authStore, tokens)
	requireAuth := auth.RequireAuth(tokens, func(w http.ResponseWriter, code, msg string) {
		httpapi.WriteError(w, http.StatusUnauthorized, code, msg)
	})
	eventStore := events.NewStore(pool)
	rulesStore := rules.NewStore(pool)
	aiHandler := ai.NewHandler(eventStore, rulesStore, ai.NewStore(pool), ai.MockProvider{})

	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/auth/register", authHandler.Register)
	mux.Handle("GET /v1/me", requireAuth(http.HandlerFunc(authHandler.Me)))
	mux.Handle("POST /v1/ai/summarize", requireAuth(http.HandlerFunc(aiHandler.Summarize)))
	return mux
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

func register(t *testing.T, h http.Handler, email string) testUser {
	t.Helper()
	status, body := doJSON(t, h, http.MethodPost, "/v1/auth/register", "", map[string]string{
		"email":    email,
		"password": "ops-secret-1",
	})
	if status != http.StatusCreated {
		t.Fatalf("register status=%d body=%s", status, body)
	}
	var tok struct {
		AccessToken string `json:"access_token"`
	}
	mustDecode(t, body, &tok)
	status, body = doJSON(t, h, http.MethodGet, "/v1/me", tok.AccessToken, nil)
	if status != http.StatusOK {
		t.Fatalf("me status=%d body=%s", status, body)
	}
	var me struct {
		ID string `json:"id"`
	}
	mustDecode(t, body, &me)
	return testUser{ID: me.ID, Token: tok.AccessToken}
}

func createEvent(t *testing.T, pool *pgxpool.Pool, userID, eventType string) string {
	t.Helper()
	ev, _, err := events.NewStore(pool).CreatePending(context.Background(), events.CreateInput{
		UserID:         userID,
		IdempotencyKey: fmt.Sprintf("evt_ai_%d", time.Now().UnixNano()),
		Type:           eventType,
		Payload:        []byte(`{"amount":50,"asset":"USDC","address_label":"hot-sim-1"}`),
	})
	if err != nil {
		t.Fatal(err)
	}
	return ev.ID
}

func uniqueEmail(prefix string) string {
	return fmt.Sprintf("%s-%d@walletops.local", prefix, time.Now().UnixNano())
}

func doJSON(t *testing.T, h http.Handler, method, path, bearer string, payload any) (int, string) {
	t.Helper()
	var body io.Reader
	if payload != nil {
		raw, err := json.Marshal(payload)
		if err != nil {
			t.Fatal(err)
		}
		body = bytes.NewReader(raw)
	}
	req := httptest.NewRequest(method, path, body)
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	b, _ := io.ReadAll(rec.Body)
	return rec.Code, string(b)
}

func mustDecode(t *testing.T, body string, dest any) {
	t.Helper()
	if err := json.Unmarshal([]byte(body), dest); err != nil {
		t.Fatalf("decode %q: %v", body, err)
	}
}
