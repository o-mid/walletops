package rules

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/omid/walletops/api/internal/auth"
	"github.com/omid/walletops/api/internal/httpapi"
)

type Handler struct {
	store *Store
}

func NewHandler(store *Store) *Handler {
	return &Handler{store: store}
}

type createRequest struct {
	Name      string   `json:"name"`
	EventType string   `json:"event_type"`
	Threshold *float64 `json:"threshold"`
	Enabled   *bool    `json:"enabled"`
}

type patchRequest struct {
	Name      *string          `json:"name"`
	EventType *string          `json:"event_type"`
	Threshold optionalFloat64  `json:"threshold"`
	Enabled   *bool            `json:"enabled"`
}

// optionalFloat64 distinguishes omitted vs explicit null.
type optionalFloat64 struct {
	set   bool
	null  bool
	value *float64
}

func (o *optionalFloat64) UnmarshalJSON(b []byte) error {
	o.set = true
	if string(b) == "null" {
		o.null = true
		o.value = nil
		return nil
	}
	var v float64
	if err := json.Unmarshal(b, &v); err != nil {
		return err
	}
	o.value = &v
	return nil
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "missing auth")
		return
	}

	var req createRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "bad_request", "invalid json")
		return
	}

	name := strings.TrimSpace(req.Name)
	eventType := strings.TrimSpace(req.EventType)
	if err := validateName(name); err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "validation_error", err.Error())
		return
	}
	if err := validateEventType(eventType); err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "validation_error", err.Error())
		return
	}

	enabled := true
	if req.Enabled != nil {
		enabled = *req.Enabled
	}

	rule, err := h.store.Create(r.Context(), user.ID, CreateInput{
		Name:      name,
		EventType: eventType,
		Threshold: req.Threshold,
		Enabled:   enabled,
	})
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not create rule")
		return
	}
	httpapi.WriteJSON(w, http.StatusCreated, rule)
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "missing auth")
		return
	}
	items, err := h.store.ListByUser(r.Context(), user.ID)
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not list rules")
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
	rule, err := h.store.GetForUser(r.Context(), user.ID, r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpapi.WriteError(w, http.StatusNotFound, "not_found", "alert rule not found")
		return
	}
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not get rule")
		return
	}
	httpapi.WriteJSON(w, http.StatusOK, rule)
}

func (h *Handler) Patch(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "missing auth")
		return
	}

	var req patchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "bad_request", "invalid json")
		return
	}

	in := UpdateInput{
		Name:      nil,
		EventType: nil,
		Enabled:   req.Enabled,
	}
	if req.Name != nil {
		name := strings.TrimSpace(*req.Name)
		if err := validateName(name); err != nil {
			httpapi.WriteError(w, http.StatusBadRequest, "validation_error", err.Error())
			return
		}
		in.Name = &name
	}
	if req.EventType != nil {
		eventType := strings.TrimSpace(*req.EventType)
		if err := validateEventType(eventType); err != nil {
			httpapi.WriteError(w, http.StatusBadRequest, "validation_error", err.Error())
			return
		}
		in.EventType = &eventType
	}
	if req.Threshold.set {
		var ptr *float64
		if !req.Threshold.null {
			ptr = req.Threshold.value
		}
		in.Threshold = &ptr
	}

	rule, err := h.store.UpdateForUser(r.Context(), user.ID, r.PathValue("id"), in)
	if errors.Is(err, ErrNotFound) {
		httpapi.WriteError(w, http.StatusNotFound, "not_found", "alert rule not found")
		return
	}
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not update rule")
		return
	}
	httpapi.WriteJSON(w, http.StatusOK, rule)
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "missing auth")
		return
	}
	err := h.store.DeleteForUser(r.Context(), user.ID, r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpapi.WriteError(w, http.StatusNotFound, "not_found", "alert rule not found")
		return
	}
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not delete rule")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
