package ai

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"sort"
	"strings"

	"github.com/omid/walletops/api/internal/auth"
	"github.com/omid/walletops/api/internal/events"
	"github.com/omid/walletops/api/internal/httpapi"
	"github.com/omid/walletops/api/internal/rules"
)

const maxEvents = 20

type Handler struct {
	events   *events.Store
	rules    *rules.Store
	store    *Store
	provider Provider
}

func NewHandler(eventsStore *events.Store, rulesStore *rules.Store, store *Store, provider Provider) *Handler {
	return &Handler{
		events:   eventsStore,
		rules:    rulesStore,
		store:    store,
		provider: provider,
	}
}

type summarizeRequest struct {
	EventIDs []string `json:"event_ids"`
}

func (h *Handler) Summarize(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "missing auth")
		return
	}

	var req summarizeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpapi.WriteError(w, http.StatusBadRequest, "bad_request", "invalid json")
		return
	}
	ids := normalizeIDs(req.EventIDs)
	if len(ids) == 0 {
		httpapi.WriteError(w, http.StatusBadRequest, "validation_error", "event_ids required")
		return
	}
	if len(ids) > maxEvents {
		httpapi.WriteError(w, http.StatusBadRequest, "validation_error", "event_ids max is 20")
		return
	}

	evs, err := h.events.GetForUserIDs(r.Context(), user.ID, ids)
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not load events")
		return
	}
	if len(evs) != len(ids) {
		httpapi.WriteError(w, http.StatusNotFound, "not_found", "one or more events not found")
		return
	}

	ruleIDs := make([]string, 0)
	for _, ev := range evs {
		if ev.MatchedRuleID != nil && *ev.MatchedRuleID != "" {
			ruleIDs = append(ruleIDs, *ev.MatchedRuleID)
		}
	}
	names, err := h.rules.NamesByIDs(r.Context(), ruleIDs)
	if err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not load rules")
		return
	}

	facts := make([]EventFact, 0, len(evs))
	orderedIDs := make([]string, 0, len(evs))
	for _, id := range ids {
		ev := evs[id]
		fact := EventFact{
			Type:   ev.Type,
			Amount: amountFromPayload(ev.Payload),
			Status: ev.Status,
		}
		if ev.MatchedRuleID != nil {
			fact.RuleName = names[*ev.MatchedRuleID]
		}
		facts = append(facts, fact)
		orderedIDs = append(orderedIDs, ev.ID)
	}

	prompt := BuildPrompt(facts)
	summary, err := h.provider.Summarize(r.Context(), prompt, orderedIDs)
	if err != nil {
		httpapi.WriteError(w, http.StatusBadGateway, "ai_error", "provider failed to return valid summary")
		return
	}
	if err := ValidateSummary(summary); err != nil || !sameIDs(summary.EventIDs, orderedIDs) {
		httpapi.WriteError(w, http.StatusBadGateway, "ai_schema_error", "provider response failed schema validation")
		return
	}
	summary.EventIDs = orderedIDs

	hash := requestHash(orderedIDs, prompt)
	if err := h.store.Save(r.Context(), user.ID, hash, orderedIDs, summary); err != nil {
		httpapi.WriteError(w, http.StatusInternalServerError, "internal_error", "could not persist summary")
		return
	}
	httpapi.WriteJSON(w, http.StatusOK, summary)
}

func normalizeIDs(ids []string) []string {
	seen := make(map[string]struct{}, len(ids))
	out := make([]string, 0, len(ids))
	for _, id := range ids {
		id = strings.TrimSpace(id)
		if id == "" {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	return out
}

func requestHash(eventIDs []string, prompt string) string {
	sorted := append([]string(nil), eventIDs...)
	sort.Strings(sorted)
	h := sha256.New()
	_, _ = h.Write([]byte(strings.Join(sorted, ",")))
	_, _ = h.Write([]byte{0})
	_, _ = h.Write([]byte(prompt))
	return hex.EncodeToString(h.Sum(nil))
}
