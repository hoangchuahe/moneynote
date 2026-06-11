package api

import (
	"net/http"
	"sync"
)

// RateLimiter requires an X-Device-Token header and caps requests per device
// for the process lifetime (in-memory; resets on restart — fine for v1).
type RateLimiter struct {
	limit int
	mu    sync.Mutex
	count map[string]int
}

func NewRateLimiter(limit int) *RateLimiter {
	return &RateLimiter{limit: limit, count: map[string]int{}}
}

func (rl *RateLimiter) Wrap(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token := r.Header.Get("X-Device-Token")
		if token == "" {
			writeErr(w, http.StatusUnauthorized, "missing_device_token")
			return
		}
		rl.mu.Lock()
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
