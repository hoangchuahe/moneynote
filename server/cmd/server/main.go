package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"github.com/moneynote/server/internal/ai"
	"github.com/moneynote/server/internal/api"
)

// listenAddr maps the PORT env value to a listen address (":8080" default).
func listenAddr(port string) string {
	if port == "" {
		port = "8080"
	}
	return ":" + port
}

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

	srv := &http.Server{
		Addr:    listenAddr(os.Getenv("PORT")),
		Handler: mux,
		// Slowloris guards; WriteTimeout leaves room for the Claude call.
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Printf("listening on %s", srv.Addr)
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
