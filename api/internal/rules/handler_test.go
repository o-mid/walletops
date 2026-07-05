package rules_test

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
	"github.com/omid/walletops/api/internal/httpapi"
	"github.com/omid/walletops/api/internal/rules"
)

func TestAlertRulesCRUD(t *testing.T) {
	pool := testPool(t)
	h := newTestServer(t, pool)

	ownerTok := register(t, h, uniqueEmail("owner"))
	otherTok := register(t, h, uniqueEmail("other"))

	var createdID string

	t.Run("create", func(t *testing.T) {
		threshold := 200.0
		status, body := doJSON(t, h, http.MethodPost, "/v1/alert-rules", ownerTok, map[string]any{
			"name":       "hot wallet drop",
			"event_type": "balance_drop",
			"threshold":  threshold,
			"enabled":    true,
		})
		if status != http.StatusCreated {
			t.Fatalf("status=%d body=%s", status, body)
		}
		var rule rules.Rule
		mustDecode(t, body, &rule)
		if rule.ID == "" || rule.Name != "hot wallet drop" || rule.EventType != "balance_drop" {
			t.Fatalf("unexpected rule: %+v", rule)
		}
		if rule.Threshold == nil || *rule.Threshold != 200 {
			t.Fatalf("threshold=%v", rule.Threshold)
		}
		createdID = rule.ID
	})

	t.Run("list", func(t *testing.T) {
		status, body := doJSON(t, h, http.MethodGet, "/v1/alert-rules", ownerTok, nil)
		if status != http.StatusOK {
			t.Fatalf("status=%d body=%s", status, body)
		}
		var resp struct {
			Items []rules.Rule `json:"items"`
		}
		mustDecode(t, body, &resp)
		if len(resp.Items) == 0 {
			t.Fatal("expected at least one rule")
		}
		found := false
		for _, item := range resp.Items {
			if item.ID == createdID {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("created rule %s missing from list", createdID)
		}
	})

	t.Run("update", func(t *testing.T) {
		status, body := doJSON(t, h, http.MethodPatch, "/v1/alert-rules/"+createdID, ownerTok, map[string]any{
			"name":    "hot wallet drop v2",
			"enabled": false,
		})
		if status != http.StatusOK {
			t.Fatalf("status=%d body=%s", status, body)
		}
		var rule rules.Rule
		mustDecode(t, body, &rule)
		if rule.Name != "hot wallet drop v2" || rule.Enabled {
			t.Fatalf("unexpected update: %+v", rule)
		}
	})

	t.Run("foreign_id_404", func(t *testing.T) {
		status, body := doJSON(t, h, http.MethodGet, "/v1/alert-rules/"+createdID, otherTok, nil)
		if status != http.StatusNotFound {
			t.Fatalf("get foreign status=%d body=%s", status, body)
		}
		status, body = doJSON(t, h, http.MethodPatch, "/v1/alert-rules/"+createdID, otherTok, map[string]any{
			"enabled": true,
		})
		if status != http.StatusNotFound {
			t.Fatalf("patch foreign status=%d body=%s", status, body)
		}
		status, body = doJSON(t, h, http.MethodDelete, "/v1/alert-rules/"+createdID, otherTok, nil)
		if status != http.StatusNotFound {
			t.Fatalf("delete foreign status=%d body=%s", status, body)
		}
	})

	t.Run("delete", func(t *testing.T) {
		status, body := doJSON(t, h, http.MethodDelete, "/v1/alert-rules/"+createdID, ownerTok, nil)
		if status != http.StatusNoContent {
			t.Fatalf("status=%d body=%s", status, body)
		}
		status, body = doJSON(t, h, http.MethodGet, "/v1/alert-rules/"+createdID, ownerTok, nil)
		if status != http.StatusNotFound {
			t.Fatalf("get after delete status=%d body=%s", status, body)
		}
	})
}

func newTestServer(t *testing.T, pool *pgxpool.Pool) http.Handler {
	t.Helper()
	authStore := auth.NewStore(pool)
	tokens := auth.NewTokenIssuer("test-jwt-secret")
	authHandler := auth.NewHandler(authStore, tokens)
	requireAuth := auth.RequireAuth(tokens, func(w http.ResponseWriter, code, msg string) {
		httpapi.WriteError(w, http.StatusUnauthorized, code, msg)
	})
	rulesHandler := rules.NewHandler(rules.NewStore(pool))

	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/auth/register", authHandler.Register)
	mux.Handle("GET /v1/alert-rules", requireAuth(http.HandlerFunc(rulesHandler.List)))
	mux.Handle("POST /v1/alert-rules", requireAuth(http.HandlerFunc(rulesHandler.Create)))
	mux.Handle("GET /v1/alert-rules/{id}", requireAuth(http.HandlerFunc(rulesHandler.Get)))
	mux.Handle("PATCH /v1/alert-rules/{id}", requireAuth(http.HandlerFunc(rulesHandler.Patch)))
	mux.Handle("DELETE /v1/alert-rules/{id}", requireAuth(http.HandlerFunc(rulesHandler.Delete)))
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
		t.Fatalf("ping postgres (start docker compose): %v", err)
	}
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return pool
}

func register(t *testing.T, h http.Handler, email string) string {
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
	return tok.AccessToken
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
