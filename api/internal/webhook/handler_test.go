package webhook_test

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

	"github.com/omid/walletops/api/internal/auth"
	"github.com/omid/walletops/api/internal/db"
	"github.com/omid/walletops/api/internal/events"
	"github.com/omid/walletops/api/internal/httpapi"
	"github.com/omid/walletops/api/internal/webhook"
)

const testSecret = "dev-webhook-secret"

func TestWebhookIngest(t *testing.T) {
	pool := testPool(t)
	eventStore := events.NewStore(pool)
	h := newTestServer(t, pool, eventStore)

	userRef := fmt.Sprintf("demo-ref-%d", time.Now().UnixNano())
	access := register(t, h, uniqueEmail("hook"))
	userID := meID(t, h, access)
	if err := eventStore.SetUserRef(context.Background(), userID, userRef); err != nil {
		t.Fatalf("set user_ref: %v", err)
	}

	body := []byte(fmt.Sprintf(`{
		"idempotency_key": "evt_%d",
		"type": "balance_drop",
		"user_ref": %q,
		"payload": {"address_label":"hot-sim-1","amount":120.5,"asset":"USDC","note":"simulated drop"},
		"occurred_at": "2026-07-16T10:00:00Z"
	}`, time.Now().UnixNano(), userRef))

	t.Run("good_sig", func(t *testing.T) {
		status, resp := postWebhook(t, h, body, webhook.SignBody(testSecret, body))
		if status != http.StatusAccepted {
			t.Fatalf("status=%d body=%s", status, resp)
		}
		var ev events.Event
		mustDecode(t, resp, &ev)
		if ev.Status != "pending" || ev.Type != "balance_drop" {
			t.Fatalf("unexpected event: %+v", ev)
		}
	})

	t.Run("bad_sig", func(t *testing.T) {
		status, resp := postWebhook(t, h, body, "sha256=deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef")
		if status != http.StatusUnauthorized {
			t.Fatalf("status=%d body=%s", status, resp)
		}
	})

	t.Run("replay", func(t *testing.T) {
		status1, resp1 := postWebhook(t, h, body, webhook.SignBody(testSecret, body))
		if status1 != http.StatusOK && status1 != http.StatusAccepted {
			t.Fatalf("first status=%d body=%s", status1, resp1)
		}
		var first events.Event
		mustDecode(t, resp1, &first)

		status2, resp2 := postWebhook(t, h, body, webhook.SignBody(testSecret, body))
		if status2 != http.StatusOK {
			t.Fatalf("replay status=%d body=%s", status2, resp2)
		}
		var second events.Event
		mustDecode(t, resp2, &second)
		if first.ID != second.ID {
			t.Fatalf("replay created duplicate: %s vs %s", first.ID, second.ID)
		}

		listStatus, listBody := doAuth(t, h, http.MethodGet, "/v1/events", access, nil)
		if listStatus != http.StatusOK {
			t.Fatalf("list status=%d body=%s", listStatus, listBody)
		}
		var list struct {
			Items []events.Event `json:"items"`
		}
		mustDecode(t, listBody, &list)
		count := 0
		for _, item := range list.Items {
			if item.IdempotencyKey == first.IdempotencyKey {
				count++
			}
		}
		if count != 1 {
			t.Fatalf("expected 1 stored event for key, got %d", count)
		}
	})
}

func newTestServer(t *testing.T, pool *pgxpool.Pool, eventStore *events.Store) http.Handler {
	t.Helper()
	authStore := auth.NewStore(pool)
	tokens := auth.NewTokenIssuer("test-jwt-secret")
	authHandler := auth.NewHandler(authStore, tokens)
	requireAuth := auth.RequireAuth(tokens, func(w http.ResponseWriter, code, msg string) {
		httpapi.WriteError(w, http.StatusUnauthorized, code, msg)
	})
	hookHandler := webhook.NewHandler(eventStore, testSecret)
	eventsHandler := events.NewHandler(eventStore)

	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/auth/register", authHandler.Register)
	mux.Handle("GET /v1/me", requireAuth(http.HandlerFunc(authHandler.Me)))
	mux.HandleFunc("POST /v1/webhooks/events", hookHandler.Ingest)
	mux.Handle("GET /v1/events", requireAuth(http.HandlerFunc(eventsHandler.List)))
	mux.Handle("GET /v1/events/{id}", requireAuth(http.HandlerFunc(eventsHandler.Get)))
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
		t.Fatalf("ping postgres: %v", err)
	}
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return pool
}

func register(t *testing.T, h http.Handler, email string) string {
	t.Helper()
	status, body := doAuth(t, h, http.MethodPost, "/v1/auth/register", "", map[string]string{
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
	return tok.AccessToken
}

func meID(t *testing.T, h http.Handler, access string) string {
	t.Helper()
	status, body := doAuth(t, h, http.MethodGet, "/v1/me", access, nil)
	if status != http.StatusOK {
		t.Fatalf("me status=%d body=%s", status, body)
	}
	var me struct {
		ID string `json:"id"`
	}
	mustDecode(t, body, &me)
	return me.ID
}

func uniqueEmail(prefix string) string {
	return fmt.Sprintf("%s-%d@walletops.local", prefix, time.Now().UnixNano())
}

func postWebhook(t *testing.T, h http.Handler, body []byte, sig string) (int, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1/webhooks/events", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Signature", sig)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	b, _ := io.ReadAll(rec.Body)
	return rec.Code, string(b)
}

func doAuth(t *testing.T, h http.Handler, method, path, bearer string, payload any) (int, string) {
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
