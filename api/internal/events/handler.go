package events

import (
	"errors"
	"net/http"

	"github.com/omid/walletops/api/internal/auth"
	"github.com/omid/walletops/api/internal/httpapi"
)

type Handler struct {
	store *Store
}

func NewHandler(store *Store) *Handler {
	return &Handler{store: store}
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "missing auth")
		return
	}
	status := r.URL.Query().Get("status")
	items, err := h.store.ListForUser(r.Context(), user.ID, status)
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not list events")
		return
	}
	httpapi.WriteJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "missing auth")
		return
	}
	ev, err := h.store.GetForUser(r.Context(), user.ID, r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpapi.WriteError(w, http.StatusNotFound, "not_found", "event not found")
		return
	}
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not get event")
		return
	}
	httpapi.WriteJSON(w, http.StatusOK, ev)
}
