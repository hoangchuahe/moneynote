package main

import (
	"log"
	"net/http"
	"os"

	"github.com/moneynote/server/internal/ai"
	"github.com/moneynote/server/internal/api"
)

func main() {
	var client ai.AIClient
	if key := os.Getenv("ANTHROPIC_API_KEY"); key != "" {
		client = ai.NewAnthropic(key)
		log.Println("AI: REAL mode (Claude Haiku 4.5)")
	} else {
		client = ai.NewFake()
		log.Println("AI: FAKE mode (no ANTHROPIC_API_KEY) — regex parsing")
	}

	h := api.NewHandler(client)
	rl := api.NewRateLimiter(200)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", h.HandleHealth)
	mux.Handle("POST /ai/parse", rl.Wrap(http.HandlerFunc(h.HandleParse)))

	addr := ":8080"
	log.Printf("listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
