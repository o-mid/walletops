package worker

import (
	"sync"
	"time"
)

type Stats struct {
	mu             sync.Mutex
	LastTick       time.Time
	ProcessedTotal int64
	ErrorTotal     int64
}

type Snapshot struct {
	LastTick       *time.Time `json:"last_tick"`
	ProcessedTotal int64      `json:"processed_total"`
	ErrorTotal     int64      `json:"error_total"`
}

func (s *Stats) MarkTick() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.LastTick = time.Now().UTC()
}

func (s *Stats) IncProcessed() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.ProcessedTotal++
}

func (s *Stats) IncError() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.ErrorTotal++
}

func (s *Stats) Snapshot() Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := Snapshot{
		ProcessedTotal: s.ProcessedTotal,
		ErrorTotal:     s.ErrorTotal,
	}
	if !s.LastTick.IsZero() {
		t := s.LastTick
		out.LastTick = &t
	}
	return out
}
