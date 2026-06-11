package ai

import "context"

// Tone of the personality comment.
type Tone string

const (
	ToneSerious Tone = "serious"
	ToneCheer   Tone = "cheer"
	ToneScold   Tone = "scold"
)

// ParseInput is everything the AI needs to parse one line of text.
type ParseInput struct {
	Text       string
	Today      string // ISO date, e.g. "2026-06-11"
	Tone       Tone
	Categories []string
	Wallets    []string
}

// ParseResult is the structured transaction the AI extracted.
type ParseResult struct {
	Amount     int     `json:"amount"`
	Type       string  `json:"type"`     // "income" | "expense"
	Category   string  `json:"category"` // must be from input list, or "" -> caller falls back
	Merchant   *string `json:"merchant"` // normalized lowercase vendor, or nil
	OccurredAt string  `json:"occurred_at"`
	Note       string  `json:"note"`
	Confidence float64 `json:"confidence"`
	Comment    string  `json:"comment"`
}

// AIClient parses natural-language text into a ParseResult.
type AIClient interface {
	Parse(ctx context.Context, in ParseInput) (ParseResult, error)
}
