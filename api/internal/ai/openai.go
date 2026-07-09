package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type OpenAIProvider struct {
	apiKey  string
	baseURL string
	model   string
	client  *http.Client
}

func NewOpenAIProvider(apiKey, baseURL string) *OpenAIProvider {
	if baseURL == "" {
		baseURL = "https://api.openai.com/v1"
	}
	baseURL = strings.TrimRight(baseURL, "/")
	return &OpenAIProvider{
		apiKey:  apiKey,
		baseURL: baseURL,
		model:   "gpt-4o-mini",
		client:  &http.Client{Timeout: 30 * time.Second},
	}
}

func (p *OpenAIProvider) Summarize(ctx context.Context, prompt string, eventIDs []string) (Summary, error) {
	reqBody := map[string]any{
		"model": p.model,
		"messages": []map[string]string{
			{"role": "system", "content": "You return only compact JSON matching the requested schema. No markdown."},
			{"role": "user", "content": prompt + "\nevent_ids: " + strings.Join(eventIDs, ",")},
		},
		"response_format": map[string]string{"type": "json_object"},
		"temperature":     0,
	}
	raw, err := json.Marshal(reqBody)
	if err != nil {
		return Summary{}, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/chat/completions", bytes.NewReader(raw))
	if err != nil {
		return Summary{}, err
	}
	req.Header.Set("Authorization", "Bearer "+p.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := p.client.Do(req)
	if err != nil {
		return Summary{}, fmt.Errorf("openai request: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return Summary{}, err
	}
	if resp.StatusCode >= 300 {
		return Summary{}, fmt.Errorf("openai status %d: %s", resp.StatusCode, truncate(string(body), 200))
	}

	var envelope struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(body, &envelope); err != nil {
		return Summary{}, fmt.Errorf("openai envelope: %w", err)
	}
	if len(envelope.Choices) == 0 {
		return Summary{}, fmt.Errorf("openai empty choices")
	}

	var summary Summary
	if err := json.Unmarshal([]byte(envelope.Choices[0].Message.Content), &summary); err != nil {
		return Summary{}, fmt.Errorf("openai json schema: %w", err)
	}
	if len(summary.EventIDs) == 0 {
		summary.EventIDs = append([]string(nil), eventIDs...)
	}
	return summary, nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}
