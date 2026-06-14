package api

import (
	"net/http"
	"sync"
	"time"
)

// RateLimiter requires an X-Device-Token header and caps requests per device
// per hour window (in-memory; resets on restart — fine for v1).
type RateLimiter struct {
	limit int
	now   func() time.Time // injectable for tests
	mu    sync.Mutex
	win   time.Time // start of the hour the counts belong to
	count map[string]int
}

func NewRateLimiter(limit int) *RateLimiter {
	return &RateLimiter{limit: limit, now: time.Now, count: map[string]int{}}
}

func (rl *RateLimiter) Wrap(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token := r.Header.Get("X-Device-Token")
		if token == "" {
			writeErr(w, http.StatusUnauthorized, "missing_device_token")
			return
		}
		if l := len(token); l < 16 || l > 64 {
			writeErr(w, http.StatusUnauthorized, "missing_device_token")
			return
		}
		win := rl.now().Truncate(time.Hour)
		rl.mu.Lock()
		if !win.Equal(rl.win) {
			rl.win = win
			rl.count = map[string]int{}
		}
		rl.count[token]++
		over := rl.count[token] > rl.limit
		rl.mu.Unlock()
		if over {
			writeErr(w, http.StatusTooManyRequests, "rate_limited")
			return
		}
		next.ServeHTTP(w, r)
	})
}
