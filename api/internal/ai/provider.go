package ai

import (
	"context"
	"fmt"

	"github.com/omid/walletops/api/internal/config"
)

type Provider interface {
	Summarize(ctx context.Context, prompt string, eventIDs []string) (Summary, error)
}

func NewProvider(cfg config.Config) (Provider, error) {
	switch cfg.AIProvider {
	case "mock", "":
		return MockProvider{}, nil
	case "openai":
		if cfg.AIAPIKey == "" {
			return nil, fmt.Errorf("AI_API_KEY required when AI_PROVIDER=openai")
		}
		return NewOpenAIProvider(cfg.AIAPIKey, cfg.AIBaseURL), nil
	default:
		return nil, fmt.Errorf("unknown AI_PROVIDER %q", cfg.AIProvider)
	}
}
