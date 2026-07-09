package ai

import (
	"encoding/json"
	"fmt"
	"strings"
)

type EventFact struct {
	Type     string   `json:"type"`
	Amount   *float64 `json:"amount,omitempty"`
	Status   string   `json:"status"`
	RuleName string   `json:"rule_name,omitempty"`
}

func BuildPrompt(facts []EventFact) string {
	var b strings.Builder
	b.WriteString("Summarize these wallet ops events. Use only the fields provided.\n")
	b.WriteString("Return JSON with keys: title, summary_bullets, risk_level, follow_ups, event_ids.\n")
	b.WriteString("risk_level must be one of low|medium|high|unknown.\n")
	b.WriteString("Events:\n")
	for i, f := range facts {
		line := map[string]any{
			"type":   f.Type,
			"status": f.Status,
		}
		if f.Amount != nil {
			line["amount"] = *f.Amount
		}
		if f.RuleName != "" {
			line["rule_name"] = f.RuleName
		}
		raw, _ := json.Marshal(line)
		fmt.Fprintf(&b, "%d. %s\n", i+1, string(raw))
	}
	return b.String()
}

func amountFromPayload(payload json.RawMessage) *float64 {
	var obj map[string]json.RawMessage
	if err := json.Unmarshal(payload, &obj); err != nil {
		return nil
	}
	raw, ok := obj["amount"]
	if !ok {
		return nil
	}
	var amount float64
	if err := json.Unmarshal(raw, &amount); err != nil {
		return nil
	}
	return &amount
}
