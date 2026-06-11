package api

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func okHandler(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) }

func TestRequiresDeviceToken(t *testing.T) {
	mw := NewRateLimiter(5)
	h := mw.Wrap(http.HandlerFunc(okHandler))
	req := httptest.NewRequest(http.MethodPost, "/ai/parse", nil) // no token
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestRateLimitPerDevice(t *testing.T) {
	mw := NewRateLimiter(2) // 2 allowed, 3rd blocked
	h := mw.Wrap(http.HandlerFunc(okHandler))
	do := func() int {
		req := httptest.NewRequest(http.MethodPost, "/ai/parse", nil)
		req.Header.Set("X-Device-Token", "dev-1")
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec.Code
	}
	if do() != 200 || do() != 200 {
		t.Fatal("first 2 should pass")
	}
	if do() != http.StatusTooManyRequests {
		t.Fatal("3rd should be 429")
	}
}

// The limit is per rolling hour window, not per process lifetime — a device
// that hits the cap must be allowed again once the next hour starts.
func TestRateLimitResetsAfterWindow(t *testing.T) {
	now := time.Date(2026, 6, 12, 10, 30, 0, 0, time.UTC)
	mw := NewRateLimiter(2)
	mw.now = func() time.Time { return now }
	h := mw.Wrap(http.HandlerFunc(okHandler))
	do := func() int {
		req := httptest.NewRequest(http.MethodPost, "/ai/parse", nil)
		req.Header.Set("X-Device-Token", "dev-1")
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec.Code
	}
	if do() != 200 || do() != 200 {
		t.Fatal("first 2 should pass")
	}
	if do() != http.StatusTooManyRequests {
		t.Fatal("3rd in same hour should be 429")
	}
	now = now.Add(time.Hour) // next hour window
	if do() != 200 {
		t.Fatal("request in the next hour window should pass again")
	}
}
