package httpapi

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
)

type HealthHandler struct {
	Pool           *pgxpool.Pool
	WorkerSnapshot func() any
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
	WriteJSON(w, http.StatusOK, body)
}
