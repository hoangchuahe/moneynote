package api

import (
	"net/http"
	"net/http/httptest"
	"testing"
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
