package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

const parseToolName = "record_transaction"

type anthropicClient struct {
	client anthropic.Client
}

// NewAnthropic returns an AIClient backed by Claude Haiku 4.5.
func NewAnthropic(apiKey string) AIClient {
	return &anthropicClient{client: anthropic.NewClient(option.WithAPIKey(apiKey))}
}

// Parse calls Claude Haiku 4.5 with forced tool use to extract a ParseResult.
func (a *anthropicClient) Parse(ctx context.Context, in ParseInput) (ParseResult, error) {
	// Build the user message that carries all per-request data.
	userText := buildUserMessage(in)

	// Define the single tool whose schema mirrors ParseResult.
	tool := anthropic.ToolParam{
		Name:        parseToolName,
		Description: anthropic.String("Record a financial transaction extracted from the user's input."),
		InputSchema: anthropic.ToolInputSchemaParam{
			Properties: map[string]any{
				"amount": map[string]any{
					"type":        "integer",
					"description": "Amount in VND (Vietnamese dong), always positive.",
				},
				"type": map[string]any{
					"type":        "string",
					"enum":        []string{"income", "expense"},
					"description": "Transaction direction.",
				},
				"category": map[string]any{
					"type":        "string",
					"description": "Category chosen from the provided list, or empty string if none fits.",
				},
				"merchant": map[string]any{
					"type":        []string{"string", "null"},
					"description": "Normalized lowercase merchant/vendor name, or null if not identifiable.",
				},
				"occurred_at": map[string]any{
					"type":        "string",
					"description": "ISO date YYYY-MM-DD when the transaction occurred.",
				},
				"note": map[string]any{
					"type":        "string",
					"description": "Short human-readable description of the transaction.",
				},
				"confidence": map[string]any{
					"type":        "number",
					"description": "Extraction confidence between 0 and 1.",
				},
				"comment": map[string]any{
					"type":        "string",
					"description": "One short Vietnamese sentence matching the requested tone.",
				},
			},
			// Required fields — all except merchant (nullable).
			Required: []string{
				"amount", "type", "category",
				"occurred_at", "note", "confidence", "comment",
			},
		},
	}

	resp, err := a.client.Messages.New(ctx, anthropic.MessageNewParams{
		Model:     anthropic.ModelClaudeHaiku4_5,
		MaxTokens: 1024,
		// System prompt with prompt-caching ephemeral marker.
		// The system prompt is stable across requests, so caching it saves
		// input tokens on repeated calls.
		System: []anthropic.TextBlockParam{
			{
				Text:         BuildSystemPrompt(),
				CacheControl: anthropic.NewCacheControlEphemeralParam(),
			},
		},
		Tools: []anthropic.ToolUnionParam{
			{OfTool: &tool},
		},
		// Force Claude to call exactly this tool so we always get structured output.
		ToolChoice: anthropic.ToolChoiceParamOfTool(parseToolName),
		Messages: []anthropic.MessageParam{
			anthropic.NewUserMessage(anthropic.NewTextBlock(userText)),
		},
	})
	if err != nil {
		return ParseResult{}, fmt.Errorf("claude API error: %w", err)
	}

	// Walk content blocks looking for the tool_use block.
	for _, block := range resp.Content {
		toolUse, ok := block.AsAny().(anthropic.ToolUseBlock)
		if !ok || toolUse.Name != parseToolName {
			continue
		}

		// toolUse.JSON.Input.Raw() returns the raw JSON of the tool input.
		raw := toolUse.JSON.Input.Raw()

		// Intermediate struct that matches the JSON schema above.
		// We use a pointer for merchant to handle null correctly.
		var raw2 struct {
			Amount     int      `json:"amount"`
			Type       string   `json:"type"`
			Category   string   `json:"category"`
			Merchant   *string  `json:"merchant"`
			OccurredAt string   `json:"occurred_at"`
			Note       string   `json:"note"`
			Confidence float64  `json:"confidence"`
			Comment    string   `json:"comment"`
		}
		if err := json.Unmarshal([]byte(raw), &raw2); err != nil {
			return ParseResult{}, fmt.Errorf("parse tool output: %w", err)
		}

		return ParseResult{
			Amount:     raw2.Amount,
			Type:       raw2.Type,
			Category:   raw2.Category,
			Merchant:   raw2.Merchant,
			OccurredAt: raw2.OccurredAt,
			Note:       raw2.Note,
			Confidence: raw2.Confidence,
			Comment:    raw2.Comment,
		}, nil
	}

	return ParseResult{}, fmt.Errorf("claude returned no tool-use block (stop_reason=%s)", resp.StopReason)
}

// buildUserMessage formats all per-request data into a clear natural-language
// prompt so Claude can pick categories and wallets from the provided lists.
func buildUserMessage(in ParseInput) string {
	var b strings.Builder
	b.WriteString("Text: ")
	b.WriteString(in.Text)
	b.WriteString("\nToday: ")
	b.WriteString(in.Today)
	b.WriteString("\nTone: ")
	b.WriteString(string(in.Tone))
	if len(in.Categories) > 0 {
		b.WriteString("\nCategories: ")
		b.WriteString(strings.Join(in.Categories, ", "))
	}
	if len(in.Wallets) > 0 {
		b.WriteString("\nWallets: ")
		b.WriteString(strings.Join(in.Wallets, ", "))
	}
	return b.String()
}
