package httpapi

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
)

type HealthHandler struct {
	Pool           *pgxpool.Pool
	WorkerSnapshot func() any
	QueueSnapshot  func(ctx context.Context) (any, error)
}

func (h HealthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if err := h.Pool.Ping(r.Context()); err != nil {
		WriteJSON(w, http.StatusServiceUnavailable, map[string]any{
			"status": "unavailable",
		})
		return
	}

	body := map[string]any{"status": "ok"}
	if h.WorkerSnapshot != nil {
		body["worker"] = h.WorkerSnapshot()
	}
	if h.QueueSnapshot != nil {
		queue, err := h.QueueSnapshot(r.Context())
		if err != nil {
			WriteJSON(w, http.StatusServiceUnavailable, map[string]any{
				"status": "unavailable",
				"error":  "queue_stats_failed",
			})
			return
		}
		body["queue"] = queue
	}
	WriteJSON(w, http.StatusOK, body)
}
