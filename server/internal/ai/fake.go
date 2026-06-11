package ai

import (
	"context"
	"regexp"
	"strconv"
	"strings"
)

type fakeClient struct{}

// NewFake returns an AIClient that parses with regex only (no network, no key).
func NewFake() AIClient { return fakeClient{} }

var (
	reMillions = regexp.MustCompile(`(?i)(\d+)\s*(?:tr|m)\s*(\d*)`) // 1tr5, 1m5, 2tr
	reThousand = regexp.MustCompile(`(?i)(\d+)\s*k`)                // 50k
	rePlain    = regexp.MustCompile(`(\d{4,})`)                     // 50000
)

func (fakeClient) Parse(_ context.Context, in ParseInput) (ParseResult, error) {
	amount := parseAmount(in.Text)
	category := ""
	if len(in.Categories) > 0 {
		category = in.Categories[0]
	}
	comment := map[Tone]string{
		ToneSerious: "Đã ghi nhận.",
		ToneCheer:   "Tuyệt, ghi sổ xong! 🎉",
		ToneScold:   "Lại tiêu nữa hả? 😤",
	}[in.Tone]
	if comment == "" {
		comment = "Đã ghi nhận."
	}
	return ParseResult{
		Amount:     amount,
		Type:       "expense",
		Category:   category,
		Merchant:   nil,
		OccurredAt: in.Today,
		Note:       strings.TrimSpace(in.Text),
		Confidence: 0.5,
		Comment:    comment,
	}, nil
}

func parseAmount(text string) int {
	if m := reMillions.FindStringSubmatch(text); m != nil {
		whole, _ := strconv.Atoi(m[1])
		amount := whole * 1000000
		if m[2] != "" { // "1tr5" -> 5 means 500000 (tenths of a million)
			frac, _ := strconv.Atoi(m[2])
			for frac >= 10 {
				frac /= 10
			}
			amount += frac * 100000
		}
		return amount
	}
	if m := reThousand.FindStringSubmatch(text); m != nil {
		n, _ := strconv.Atoi(m[1])
		return n * 1000
	}
	if m := rePlain.FindStringSubmatch(text); m != nil {
		n, _ := strconv.Atoi(m[1])
		return n
	}
	return 0
}
