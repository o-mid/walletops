package worker

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/omid/walletops/api/internal/events"
	"github.com/omid/walletops/api/internal/rules"
)

const (
	MaxAttempts = 5
	PollEvery   = 2 * time.Second
	BatchSize   = 20
)

type Worker struct {
	events *events.Store
	rules  *rules.Store
	log    *slog.Logger
	Stats  *Stats
	every  time.Duration
}

func New(eventsStore *events.Store, rulesStore *rules.Store, log *slog.Logger) *Worker {
	if log == nil {
		log = slog.Default()
	}
	return &Worker{
		events: eventsStore,
		rules:  rulesStore,
		log:    log,
		Stats:  &Stats{},
		every:  PollEvery,
	}
}

func (w *Worker) Run(ctx context.Context) {
	ticker := time.NewTicker(w.every)
	defer ticker.Stop()

	w.tick(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			w.tick(ctx)
		}
	}
}

func (w *Worker) tick(ctx context.Context) {
	w.Stats.MarkTick()
	for i := 0; i < BatchSize; i++ {
		ok, err := w.ProcessOne(ctx)
		if err != nil {
			w.Stats.IncError()
			w.log.Error("worker process", "err", err)
		}
		if !ok {
			return
		}
	}
}

// ProcessOne claims and processes a single eligible event.
// ok=false means the queue was empty.
func (w *Worker) ProcessOne(ctx context.Context) (ok bool, err error) {
	ev, err := w.events.ClaimNext(ctx, MaxAttempts)
	if errors.Is(err, events.ErrNotFound) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, w.Finish(ctx, ev)
}

// Finish runs match/validate on an already-claimed event.
func (w *Worker) Finish(ctx context.Context, ev events.Event) error {
	matchedID, procErr := w.process(ctx, ev)
	if procErr != nil {
		updated, markErr := w.events.MarkAttemptFailed(ctx, ev.ID, procErr.Error())
		if markErr != nil {
			return fmt.Errorf("mark failed event_id=%s: %w", ev.ID, markErr)
		}
		w.Stats.IncError()
		w.log.Info("event attempt failed",
			"event_id", ev.ID,
			"attempt", updated.AttemptCount,
			"status", updated.Status,
			"err", procErr.Error(),
		)
		return nil
	}

	if err := w.events.MarkProcessed(ctx, ev.ID, matchedID); err != nil {
		return fmt.Errorf("mark processed event_id=%s: %w", ev.ID, err)
	}
	w.Stats.IncProcessed()
	w.log.Info("event processed", "event_id", ev.ID, "matched_rule_id", matchedID)
	return nil
}

func (w *Worker) process(ctx context.Context, ev events.Event) (*string, error) {
	amount, err := payloadAmount(ev.Payload)
	if err != nil {
		return nil, err
	}

	candidates, err := w.rules.EnabledByUserAndType(ctx, ev.UserID, ev.Type)
	if err != nil {
		return nil, err
	}
	for _, rule := range candidates {
		if rule.Threshold == nil || (amount != nil && *amount <= *rule.Threshold) {
			id := rule.ID
			return &id, nil
		}
	}
	return nil, nil
}

func payloadAmount(raw json.RawMessage) (*float64, error) {
	if len(raw) == 0 {
		return nil, fmt.Errorf("payload required")
	}
	var obj map[string]json.RawMessage
	if err := json.Unmarshal(raw, &obj); err != nil {
		return nil, fmt.Errorf("payload must be a json object")
	}
	rawAmount, ok := obj["amount"]
	if !ok {
		return nil, nil
	}
	var amount float64
	if err := json.Unmarshal(rawAmount, &amount); err != nil {
		return nil, fmt.Errorf("payload.amount must be a number")
	}
	return &amount, nil
}
