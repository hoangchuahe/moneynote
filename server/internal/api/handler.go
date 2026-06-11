package api

import (
	"encoding/json"
	"net/http"

	"github.com/moneynote/server/internal/ai"
)

const (
	maxTextLen = 500
	maxBodyLen = 64 << 10 // 64 KiB — generous for text + category/wallet names
)

type Handler struct {
	ai ai.AIClient
}

func NewHandler(client ai.AIClient) *Handler { return &Handler{ai: client} }

func (h *Handler) HandleHealth(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func (h *Handler) HandleParse(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyLen)
	var req ParseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeErr(w, http.StatusBadRequest, "invalid_input")
		return
	}
	if req.Text == "" || len(req.Text) > maxTextLen || req.Today == "" {
		writeErr(w, http.StatusBadRequest, "invalid_input")
		return
	}
	tone := ai.Tone(req.Tone)
	if tone != ai.ToneCheer && tone != ai.ToneScold {
		tone = ai.ToneSerious
	}
	res, err := h.ai.Parse(r.Context(), ai.ParseInput{
		Text: req.Text, Today: req.Today, Tone: tone,
		Categories: req.Categories, Wallets: req.Wallets,
	})
	if err != nil {
		writeErr(w, http.StatusBadGateway, "ai_unavailable")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(res)
}

func writeErr(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_, _ = w.Write([]byte(`{"error":"` + msg + `"}`))
}
