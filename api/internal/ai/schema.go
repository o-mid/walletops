package ai

import (
	"fmt"
	"slices"
)

type Summary struct {
	Title          string   `json:"title"`
	SummaryBullets []string `json:"summary_bullets"`
	RiskLevel      string   `json:"risk_level"`
	FollowUps      []string `json:"follow_ups"`
	EventIDs       []string `json:"event_ids"`
}

var allowedRisk = map[string]struct{}{
	"low": {}, "medium": {}, "high": {}, "unknown": {},
}

func ValidateSummary(s Summary) error {
	if s.Title == "" {
		return fmt.Errorf("title required")
	}
	if len(s.SummaryBullets) == 0 {
		return fmt.Errorf("summary_bullets required")
	}
	if _, ok := allowedRisk[s.RiskLevel]; !ok {
		return fmt.Errorf("invalid risk_level")
	}
	if s.FollowUps == nil {
		return fmt.Errorf("follow_ups required")
	}
	if len(s.EventIDs) == 0 {
		return fmt.Errorf("event_ids required")
	}
	return nil
}

func sameIDs(got, want []string) bool {
	if len(got) != len(want) {
		return false
	}
	a := append([]string(nil), got...)
	b := append([]string(nil), want...)
	slices.Sort(a)
	slices.Sort(b)
	return slices.Equal(a, b)
}
