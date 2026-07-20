package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	DatabaseURL       string
	JWTSecret         string
	WebhookSecret     string
	AIProvider        string
	AIAPIKey          string
	AIBaseURL         string
	HTTPAddr          string
	DemoProcessDelay  time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		DatabaseURL:      os.Getenv("DATABASE_URL"),
		JWTSecret:        os.Getenv("JWT_SECRET"),
		WebhookSecret:    os.Getenv("WEBHOOK_SECRET"),
		AIProvider:       getenv("AI_PROVIDER", "mock"),
		AIAPIKey:         os.Getenv("AI_API_KEY"),
		AIBaseURL:        os.Getenv("AI_BASE_URL"),
		HTTPAddr:         getenv("HTTP_ADDR", ":8080"),
		DemoProcessDelay: parseDurationMS("DEMO_PROCESS_DELAY_MS", 0),
	}

	var missing []string
	if cfg.DatabaseURL == "" {
		missing = append(missing, "DATABASE_URL")
	}
	if cfg.JWTSecret == "" {
		missing = append(missing, "JWT_SECRET")
	}
	if cfg.WebhookSecret == "" {
		missing = append(missing, "WEBHOOK_SECRET")
	}
	if len(missing) > 0 {
		return Config{}, fmt.Errorf("missing required env: %s", strings.Join(missing, ", "))
	}
	return cfg, nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func parseDurationMS(key string, fallbackMS int) time.Duration {
	raw := os.Getenv(key)
	if raw == "" {
		return time.Duration(fallbackMS) * time.Millisecond
	}
	ms, err := strconv.Atoi(raw)
	if err != nil || ms < 0 {
		return time.Duration(fallbackMS) * time.Millisecond
	}
	return time.Duration(ms) * time.Millisecond
}
