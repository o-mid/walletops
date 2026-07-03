package auth_test

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
)

func TestAuthFlows(t *testing.T) {
	pool := testPool(t)
	h := newTestServer(t, pool)

	t.Run("register_ok", func(t *testing.T) {
		email := uniqueEmail("register-ok")
		status, body := postJSON(t, h, "/v1/auth/register", map[string]string{
			"email":    email,
			"password": "ops-secret-1",
		})
		if status != http.StatusCreated {
			t.Fatalf("status=%d body=%s", status, body)
		}
		var tok tokenBody
		mustDecode(t, body, &tok)
		if tok.AccessToken == "" || tok.RefreshToken == "" || tok.ExpiresIn <= 0 {
			t.Fatalf("incomplete tokens: %+v", tok)
		}
	})

	t.Run("duplicate_email", func(t *testing.T) {
		email := uniqueEmail("dup")
		status, _ := postJSON(t, h, "/v1/auth/register", map[string]string{
			"email":    email,
			"password": "ops-secret-1",
		})
		if status != http.StatusCreated {
			t.Fatalf("setup register status=%d", status)
		}
		status, body := postJSON(t, h, "/v1/auth/register", map[string]string{
			"email":    email,
			"password": "ops-secret-1",
		})
		if status != http.StatusConflict {
			t.Fatalf("status=%d body=%s", status, body)
		}
	})

	t.Run("bad_login", func(t *testing.T) {
		email := uniqueEmail("bad-login")
		status, _ := postJSON(t, h, "/v1/auth/register", map[string]string{
			"email":    email,
			"password": "ops-secret-1",
		})
		if status != http.StatusCreated {
			t.Fatalf("setup register status=%d", status)
		}
		status, body := postJSON(t, h, "/v1/auth/login", map[string]string{
			"email":    email,
			"password": "wrong-password",
		})
		if status != http.StatusUnauthorized {
			t.Fatalf("status=%d body=%s", status, body)
		}
	})

	t.Run("refresh", func(t *testing.T) {
		email := uniqueEmail("refresh")
		status, body := postJSON(t, h, "/v1/auth/register", map[string]string{
			"email":    email,
			"password": "ops-secret-1",
		})
		if status != http.StatusCreated {
			t.Fatalf("setup register status=%d body=%s", status, body)
		}
		var first tokenBody
		mustDecode(t, body, &first)

		status, body = postJSON(t, h, "/v1/auth/refresh", map[string]string{
			"refresh_token": first.RefreshToken,
		})
		if status != http.StatusOK {
			t.Fatalf("refresh status=%d body=%s", status, body)
		}
		var second tokenBody
		mustDecode(t, body, &second)
		if second.AccessToken == "" || second.RefreshToken == "" {
			t.Fatalf("incomplete refresh tokens: %+v", second)
		}
		if second.RefreshToken == first.RefreshToken {
			t.Fatal("refresh token was not rotated")
		}

		status, body = postJSON(t, h, "/v1/auth/refresh", map[string]string{
			"refresh_token": first.RefreshToken,
		})
		if status != http.StatusUnauthorized {
			t.Fatalf("replay refresh status=%d body=%s", status, body)
		}
	})
}

type tokenBody struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
}

func newTestServer(t *testing.T, pool *pgxpool.Pool) http.Handler {
	t.Helper()
	store := auth.NewStore(pool)
	tokens := auth.NewTokenIssuer("test-jwt-secret")
	authHandler := auth.NewHandler(store, tokens)
	requireAuth := auth.RequireAuth(tokens, func(w http.ResponseWriter, code, msg string) {
		httpapi.WriteError(w, http.StatusUnauthorized, code, msg)
	})

	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/auth/register", authHandler.Register)
	mux.HandleFunc("POST /v1/auth/login", authHandler.Login)
	mux.HandleFunc("POST /v1/auth/refresh", authHandler.Refresh)
	mux.Handle("GET /v1/me", requireAuth(http.HandlerFunc(authHandler.Me)))
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

func uniqueEmail(prefix string) string {
	return fmt.Sprintf("%s-%d@walletops.local", prefix, time.Now().UnixNano())
}

func postJSON(t *testing.T, h http.Handler, path string, payload any) (int, string) {
	t.Helper()
	raw, err := json.Marshal(payload)
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(raw))
	req.Header.Set("Content-Type", "application/json")
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
