package ai

import (
	"context"
	"testing"
)

func TestFakeParseAmount(t *testing.T) {
	c := NewFake()
	in := ParseInput{Text: "trua an pho 50k", Today: "2026-06-11", Tone: ToneSerious,
		Categories: []string{"Ăn uống", "Đi lại"}, Wallets: []string{"Tiền mặt"}}
	r, err := c.Parse(context.Background(), in)
	if err != nil {
		t.Fatal(err)
	}
	if r.Amount != 50000 {
		t.Fatalf("amount = %d, want 50000", r.Amount)
	}
	if r.Type != "expense" {
		t.Fatalf("type = %q, want expense", r.Type)
	}
	if r.Category != "Ăn uống" {
		t.Fatalf("category = %q, want first category", r.Category)
	}
	if r.OccurredAt != "2026-06-11" {
		t.Fatalf("occurred_at = %q", r.OccurredAt)
	}
}

func TestFakeParseMillions(t *testing.T) {
	c := NewFake()
	r, _ := c.Parse(context.Background(), ParseInput{Text: "mua 1tr5", Today: "2026-06-11",
		Categories: []string{"Mua sắm"}})
	if r.Amount != 1500000 {
		t.Fatalf("amount = %d, want 1500000", r.Amount)
	}
}
