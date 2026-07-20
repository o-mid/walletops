package demo

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/omid/walletops/api/internal/auth"
	"github.com/omid/walletops/api/internal/events"
	"github.com/omid/walletops/api/internal/httpapi"
	"github.com/omid/walletops/api/internal/rules"
)

const demoRuleName = "Demo balance watch"

type Handler struct {
	events *events.Store
	rules  *rules.Store
}

func NewHandler(eventStore *events.Store, rulesStore *rules.Store) *Handler {
	return &Handler{events: eventStore, rules: rulesStore}
}

type simulateRequest struct {
	Count          int  `json:"count"`
	EnsureDemoRule bool `json:"ensure_demo_rule"`
}

type simulateResponse struct {
	Events          []events.Event `json:"events"`
	DemoRuleID      *string        `json:"demo_rule_id,omitempty"`
	DemoRuleCreated bool           `json:"demo_rule_created"`
	Hint            string         `json:"hint"`
}

// Simulate inserts pending events for the signed-in user (same store path as post-HMAC ingest).
func (h *Handler) Simulate(w http.ResponseWriter, r *http.Request) {
	user, ok := auth.UserFromContext(r.Context())
	if !ok {
		httpapi.WriteError(w, http.StatusUnauthorized, "unauthorized", "missing user")
		return
	}

	var req simulateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil && !errors.Is(err, io.EOF) {
		httpapi.WriteError(w, http.StatusBadRequest, "invalid_json", "invalid json body")
		return
	}
	if req.Count <= 0 {
		req.Count = 1
	}
	if req.Count > 5 {
		req.Count = 5
	}

	var demoRuleID *string
	var ruleCreated bool
	if req.EnsureDemoRule {
		id, created, err := h.ensureDemoRule(r.Context(), user.ID)
		if err != nil {
			httpapi.WriteError(w, http.StatusInternalServerError, "rule_error", err.Error())
			return
		}
		demoRuleID = &id
		ruleCreated = created
	}

	now := time.Now().UTC().UnixNano()
	out := make([]events.Event, 0, req.Count)
	for i := 0; i < req.Count; i++ {
		spec := demoSpecs[i%len(demoSpecs)]
		payload, err := json.Marshal(map[string]any{
			"address_label": "hot-sim-1",
			"amount":        spec.amount,
			"asset":         spec.asset,
			"note":          fmt.Sprintf("demo inject %d", i+1),
		})
		if err != nil {
			httpapi.WriteError(w, http.StatusInternalServerError, "payload_error", err.Error())
			return
		}
		ev, _, err := h.events.CreatePending(r.Context(), events.CreateInput{
			UserID:         user.ID,
			IdempotencyKey: fmt.Sprintf("demo_%d_%d", now, i+1),
			Type:           spec.eventType,
			Payload:        payload,
		})
		if err != nil {
			httpapi.WriteError(w, http.StatusInternalServerError, "create_failed", err.Error())
			return
		}
		out = append(out, ev)
	}

	httpapi.WriteJSON(w, http.StatusCreated, simulateResponse{
		Events:          out,
		DemoRuleID:      demoRuleID,
		DemoRuleCreated: ruleCreated,
		Hint:            "Events start as pending. Watch the list refresh as the worker claims and processes them.",
	})
}

type demoSpec struct {
	eventType string
	amount    float64
	asset     string
}

var demoSpecs = []demoSpec{
	{eventType: "balance_drop", amount: 120.5, asset: "USDC"},
	{eventType: "swap_quote", amount: 40, asset: "ETH"},
	{eventType: "balance_drop", amount: 85, asset: "USDC"},
	{eventType: "swap_quote", amount: 12.5, asset: "ETH"},
	{eventType: "balance_drop", amount: 200, asset: "USDT"},
}

func (h *Handler) ensureDemoRule(ctx context.Context, userID string) (string, bool, error) {
	existing, err := h.rules.ListByUser(ctx, userID)
	if err != nil {
		return "", false, err
	}
	for _, rule := range existing {
		if rule.Name == demoRuleName {
			return rule.ID, false, nil
		}
	}
	threshold := 100.0
	created, err := h.rules.Create(ctx, userID, rules.CreateInput{
		Name:      demoRuleName,
		EventType: "balance_drop",
		Threshold: &threshold,
		Enabled:   true,
	})
	if err != nil {
		return "", false, err
	}
	return created.ID, true, nil
}
