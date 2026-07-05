package rules

import (
	"fmt"
	"strings"
)

var allowedEventTypes = map[string]struct{}{
	"tx_simulated": {},
	"balance_drop": {},
	"partner_kyc":  {},
	"swap_quote":   {},
	"custom":       {},
}

const maxNameLen = 80

func validateName(name string) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("name is required")
	}
	if len(name) > maxNameLen {
		return fmt.Errorf("name must be at most %d characters", maxNameLen)
	}
	return nil
}

func validateEventType(eventType string) error {
	if _, ok := allowedEventTypes[eventType]; !ok {
		return fmt.Errorf("event_type must be one of tx_simulated, balance_drop, partner_kyc, swap_quote, custom")
	}
	return nil
}
