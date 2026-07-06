package webhook

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/omid/walletops/api/internal/events"
	"github.com/omid/walletops/api/internal/httpapi"
)

type Handler struct {
	store  *events.Store
	secret string
}

func NewHandler(store *events.Store, secret string) *Handler {
	return &Handler{store: store, secret: secret}
}

type ingestRequest struct {
	IdempotencyKey string          `json:"idempotency_key"`
	Type           string          `json:"type"`
	UserRef        string          `json:"user_ref"`
	Payload        json.RawMessage `json:"payload"`
	OccurredAt     *time.Time      `json:"occurred_at"`
}

func (h *Handler) Ingest(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "bad_request", "could not read body")
		return
	}
	if !ValidSignature(h.secret, body, r.Header.Get("X-Signature")) {
		httpapi.WriteError(w, http.StatusUnauthorized, "invalid_signature", "webhook signature invalid")
		return
	}

	var req ingestRequest
	if err := json.Unmarshal(body, &req); err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "bad_request", "invalid json")
		return
	}
	key := strings.TrimSpace(req.IdempotencyKey)
	eventType := strings.TrimSpace(req.Type)
	userRef := strings.TrimSpace(req.UserRef)
	if key == "" || eventType == "" || userRef == "" {
		httpapi.WriteError(w, http.StatusBadRequest, "validation_error", "idempotency_key, type, and user_ref required")
		return
	}
	payload := req.Payload
	if len(payload) == 0 {
		payload = json.RawMessage(`{}`)
	}

	userID, err := h.store.UserIDByRef(r.Context(), userRef)
	if errors.Is(err, events.ErrUnknownUserRef) {
		httpapi.WriteError(w, http.StatusNotFound, "unknown_user_ref", "user_ref not mapped")
		return
	}
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "lookup failed")
		return
	}

	ev, created, err := h.store.CreatePending(r.Context(), events.CreateInput{
		UserID:         userID,
		IdempotencyKey: key,
		Type:           eventType,
		Payload:        payload,
	})
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not persist event")
		return
	}
	if created {
		httpapi.WriteJSON(w, http.StatusAccepted, ev)
		return
	}
	httpapi.WriteJSON(w, http.StatusOK, ev)
}
