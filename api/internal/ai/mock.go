package ai

import (
	"context"
	"fmt"
)

type MockProvider struct{}

func (MockProvider) Summarize(_ context.Context, _ string, eventIDs []string) (Summary, error) {
	n := len(eventIDs)
	risk := "low"
	if n >= 3 {
		risk = "medium"
	}
	if n >= 8 {
		risk = "high"
	}
	return Summary{
		Title: fmt.Sprintf("Ops summary for %d event(s)", n),
		SummaryBullets: []string{
			fmt.Sprintf("Reviewed %d allowlisted wallet ops event(s)", n),
			"No free-form user chat was included in the prompt",
		},
		RiskLevel: risk,
		FollowUps: []string{
			"Confirm matched alert rules still apply",
			"Check hot wallet balances if balance_drop present",
		},
		EventIDs: append([]string(nil), eventIDs...),
	}, nil
}
