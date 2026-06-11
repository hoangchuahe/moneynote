package ai

import (
	"strings"
	"testing"
)

func TestBuildSystemPromptMentionsRules(t *testing.T) {
	p := BuildSystemPrompt()
	for _, want := range []string{"50k", "merchant", "category", "JSON"} {
		if !strings.Contains(strings.ToLower(p), strings.ToLower(want)) {
			t.Fatalf("system prompt missing %q", want)
		}
	}
}
