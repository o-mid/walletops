package auth

import (
	"context"
	"net/http"
	"strings"
)

type ctxKey int

const userCtxKey ctxKey = 1

type UserContext struct {
	ID    string
	Email string
}

func UserFromContext(ctx context.Context) (UserContext, bool) {
	u, ok := ctx.Value(userCtxKey).(UserContext)
	return u, ok
}

func RequireAuth(issuer *TokenIssuer, unauthorized func(http.ResponseWriter, string, string)) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if !strings.HasPrefix(header, "Bearer ") {
				unauthorized(w, "unauthorized", "missing bearer token")
				return
			}
			token := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
			claims, err := issuer.ParseAccess(token)
			if err != nil || claims.Subject == "" {
				unauthorized(w, "unauthorized", "invalid access token")
				return
			}
			ctx := context.WithValue(r.Context(), userCtxKey, UserContext{
				ID:    claims.Subject,
				Email: claims.Email,
			})
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
