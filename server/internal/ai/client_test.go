package ai

import "testing"

func TestParseResultZeroValue(t *testing.T) {
	var r ParseResult
	if r.Amount != 0 || r.Category != "" || r.Merchant != nil {
		t.Fatalf("unexpected zero value: %+v", r)
	}
}
