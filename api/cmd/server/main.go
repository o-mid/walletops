package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omid/walletops/api/internal/ai"
	"github.com/omid/walletops/api/internal/auth"
	"github.com/omid/walletops/api/internal/config"
	"github.com/omid/walletops/api/internal/db"
	"github.com/omid/walletops/api/internal/demo"
	"github.com/omid/walletops/api/internal/events"
	"github.com/omid/walletops/api/internal/httpapi"
	"github.com/omid/walletops/api/internal/rules"
	"github.com/omid/walletops/api/internal/webhook"
	"github.com/omid/walletops/api/internal/worker"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

	cfg, err := config.Load()
	if err != nil {
		log.Error("config", "err", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Error("db connect", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		log.Error("db ping", "err", err)
		os.Exit(1)
	}
	if err := db.Migrate(ctx, pool); err != nil {
		log.Error("migrate", "err", err)
		os.Exit(1)
	}
	log.Info("migrations applied")

	authStore := auth.NewStore(pool)
	tokens := auth.NewTokenIssuer(cfg.JWTSecret)
	authHandler := auth.NewHandler(authStore, tokens)
	rulesStore := rules.NewStore(pool)
	rulesHandler := rules.NewHandler(rulesStore)
	eventStore := events.NewStore(pool)
	eventsHandler := events.NewHandler(eventStore)
	webhookHandler := webhook.NewHandler(eventStore, cfg.WebhookSecret)
	aiProvider, err := ai.NewProvider(cfg)
	if err != nil {
		log.Error("ai provider", "err", err)
		os.Exit(1)
	}
	aiHandler := ai.NewHandler(eventStore, rulesStore, ai.NewStore(pool), aiProvider)
	demoHandler := demo.NewHandler(eventStore, rulesStore)
	wrk := worker.NewWithDelay(eventStore, rulesStore, log, cfg.DemoProcessDelay)
	if cfg.DemoProcessDelay > 0 {
		log.Info("demo process delay enabled", "delay", cfg.DemoProcessDelay.String())
	}
	go wrk.Run(ctx)
	requireAuth := auth.RequireAuth(tokens, func(w http.ResponseWriter, code, msg string) {
		httpapi.WriteError(w, http.StatusUnauthorized, code, msg)
	})


	mux := http.NewServeMux()
	mux.Handle("GET /v1/health", httpapi.HealthHandler{
		Pool: pool,
		WorkerSnapshot: func() any {
			return wrk.Stats.Snapshot()
		},
		QueueSnapshot: func(ctx context.Context) (any, error) {
			return eventStore.QueueStats(ctx)
		},
	})


	mux.HandleFunc("POST /v1/auth/register", authHandler.Register)
	mux.HandleFunc("POST /v1/auth/login", authHandler.Login)
	mux.HandleFunc("POST /v1/auth/refresh", authHandler.Refresh)
	mux.Handle("GET /v1/me", requireAuth(http.HandlerFunc(authHandler.Me)))
	mux.Handle("GET /v1/alert-rules", requireAuth(http.HandlerFunc(rulesHandler.List)))
	mux.Handle("POST /v1/alert-rules", requireAuth(http.HandlerFunc(rulesHandler.Create)))
	mux.Handle("GET /v1/alert-rules/{id}", requireAuth(http.HandlerFunc(rulesHandler.Get)))
	mux.Handle("PATCH /v1/alert-rules/{id}", requireAuth(http.HandlerFunc(rulesHandler.Patch)))
	mux.Handle("DELETE /v1/alert-rules/{id}", requireAuth(http.HandlerFunc(rulesHandler.Delete)))
	mux.HandleFunc("POST /v1/webhooks/events", webhookHandler.Ingest)
	mux.Handle("GET /v1/events", requireAuth(http.HandlerFunc(eventsHandler.List)))
	mux.Handle("GET /v1/events/{id}", requireAuth(http.HandlerFunc(eventsHandler.Get)))
	mux.Handle("POST /v1/demo/simulate", requireAuth(http.HandlerFunc(demoHandler.Simulate)))
	mux.Handle("POST /v1/ai/summarize", requireAuth(http.HandlerFunc(aiHandler.Summarize)))




	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Info("listening", "addr", cfg.HTTPAddr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("listen", "err", err)
			stop()
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("shutdown", "err", err)
	}
}
