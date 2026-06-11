package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/moneynote/server/internal/ai"
)

func TestHandleParseOK(t *testing.T) {
	h := NewHandler(ai.NewFake())
	body, _ := json.Marshal(ParseRequest{Text: "an pho 50k", Today: "2026-06-11",
		Tone: "serious", Categories: []string{"Ăn uống"}, Wallets: []string{"Tiền mặt"}})
	req := httptest.NewRequest(http.MethodPost, "/ai/parse", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	h.HandleParse(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body)
	}
	var out ai.ParseResult
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if out.Amount != 50000 {
		t.Fatalf("amount = %d", out.Amount)
	}
}

func TestHandleParseRejectsLongText(t *testing.T) {
	h := NewHandler(ai.NewFake())
	long := make([]byte, 600)
	for i := range long {
		long[i] = 'a'
	}
	body, _ := json.Marshal(ParseRequest{Text: string(long), Today: "2026-06-11"})
	req := httptest.NewRequest(http.MethodPost, "/ai/parse", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	h.HandleParse(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}

// A short "text" hidden in a megabyte-sized body must be rejected before the
// server buffers it all (body cap), not parsed and answered.
func TestHandleParseRejectsHugeBody(t *testing.T) {
	h := NewHandler(ai.NewFake())
	huge := string(bytes.Repeat([]byte{'x'}, 1<<20)) // 1 MiB filler
	body, _ := json.Marshal(ParseRequest{Text: "an pho 50k", Today: "2026-06-11",
		Categories: []string{huge}})
	req := httptest.NewRequest(http.MethodPost, "/ai/parse", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	h.HandleParse(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}

func TestHealth(t *testing.T) {
	h := NewHandler(ai.NewFake())
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	h.HandleHealth(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
}
