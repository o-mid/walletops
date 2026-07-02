package config

import (
	"fmt"
	"os"
	"strings"
)

type Config struct {
	DatabaseURL   string
	JWTSecret     string
	WebhookSecret string
	AIProvider    string
	AIAPIKey      string
	HTTPAddr      string
}

func Load() (Config, error) {
	cfg := Config{
		DatabaseURL:   os.Getenv("DATABASE_URL"),
		JWTSecret:     os.Getenv("JWT_SECRET"),
		WebhookSecret: os.Getenv("WEBHOOK_SECRET"),
		AIProvider:    getenv("AI_PROVIDER", "mock"),
		AIAPIKey:      os.Getenv("AI_API_KEY"),
		HTTPAddr:      getenv("HTTP_ADDR", ":8080"),
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
