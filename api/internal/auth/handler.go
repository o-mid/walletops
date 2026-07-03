package auth

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"golang.org/x/crypto/bcrypt"

	"github.com/omid/walletops/api/internal/httpapi"
)

const (
	minPasswordLen = 8
	bcryptCost     = bcrypt.DefaultCost
)

type Handler struct {
	store  *Store
	tokens *TokenIssuer
}

func NewHandler(store *Store, tokens *TokenIssuer) *Handler {
	return &Handler{store: store, tokens: tokens}
}

type credentialsRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type meResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "bad_request", "invalid json")
		return
	}
	email, password, ok := normalizeCredentials(req)
	if !ok {
		httpapi.WriteError(w, http.StatusBadRequest, "validation_error", "email and password (min 8) required")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcryptCost)
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not hash password")
		return
	}

	user, err := h.store.CreateUser(r.Context(), email, string(hash))
	if errors.Is(err, ErrEmailTaken) {
		httpapi.WriteError(w, http.StatusConflict, "email_taken", "email already registered")
		return
	}
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not create user")
		return
	}

	tokens, err := h.issuePair(r.Context(), user)
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not issue tokens")
		return
	}
	httpapi.WriteJSON(w, http.StatusCreated, tokens)
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "bad_request", "invalid json")
		return
	}
	email, password, ok := normalizeCredentials(req)
	if !ok {
		httpapi.WriteError(w, http.StatusBadRequest, "validation_error", "email and password required")
		return
	}

	user, err := h.store.UserByEmail(r.Context(), email)
	if errors.Is(err, ErrUserNotFound) {
		httpapi.WriteError(w, http.StatusUnauthorized, "invalid_credentials", "invalid email or password")
		return
	}
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "lookup failed")
		return
	}
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		httpapi.WriteError(w, http.StatusUnauthorized, "invalid_credentials", "invalid email or password")
		return
	}

	tokens, err := h.issuePair(r.Context(), user)
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not issue tokens")
		return
	}
	httpapi.WriteJSON(w, http.StatusOK, tokens)
}

func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "bad_request", "invalid json")
		return
	}
	plain := strings.TrimSpace(req.RefreshToken)
	if plain == "" {
		httpapi.WriteError(w, http.StatusBadRequest, "validation_error", "refresh_token required")
		return
	}

	userID, err := h.store.ConsumeRefreshToken(r.Context(), HashRefresh(plain))
	if errors.Is(err, ErrInvalidRefresh) {
		httpapi.WriteError(w, http.StatusUnauthorized, "invalid_refresh", "refresh token invalid or expired")
		return
	}
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "refresh failed")
		return
	}

	user, err := h.store.UserByID(r.Context(), userID)
	if err != nil {
		httpapi.WriteError(w, http.StatusUnauthorized, "invalid_refresh", "refresh token invalid or expired")
		return
	}

	tokens, err := h.issuePair(r.Context(), user)
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not issue tokens")
		return
	}
	httpapi.WriteJSON(w, http.StatusOK, tokens)
}

func (h *Handler) Me(w http.ResponseWriter, r *http.Request) {
	u, ok := UserFromContext(r.Context())
	if !ok {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "missing auth")
		return
	}
	user, err := h.store.UserByID(r.Context(), u.ID)
	if errors.Is(err, ErrUserNotFound) {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "user not found")
		return
	}
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "lookup failed")
		return
	}
	httpapi.WriteJSON(w, http.StatusOK, meResponse{ID: user.ID, Email: user.Email})
}

func (h *Handler) issuePair(ctx context.Context, user User) (tokenResponse, error) {
	access, expiresIn, err := h.tokens.IssueAccess(user.ID, user.Email)
	if err != nil {
		return tokenResponse{}, err
	}
	refresh, hash, expiresAt, err := NewRefreshToken()
	if err != nil {
		return tokenResponse{}, err
	}
	if err := h.store.SaveRefreshToken(ctx, user.ID, hash, expiresAt); err != nil {
		return tokenResponse{}, err
	}
	return tokenResponse{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresIn:    expiresIn,
	}, nil
}

func normalizeCredentials(req credentialsRequest) (email, password string, ok bool) {
	email = strings.ToLower(strings.TrimSpace(req.Email))
	password = req.Password
	if email == "" || !strings.Contains(email, "@") || len(password) < minPasswordLen {
		return "", "", false
	}
	return email, password, true
}
