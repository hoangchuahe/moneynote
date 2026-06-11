# MoneyNote Phase 2 — AI Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an AI layer to the existing local-first app — type "trưa nay ăn phở 50k" → a Go proxy calls Claude → the Add form is pre-filled (amount, category, date, merchant), with merchant memory and a personality toggle.

**Architecture:** New stateless Go `net/http` proxy (`server/`) exposes `POST /ai/parse`; an `AIClient` interface has a **fake** impl (regex, no key) and a **real** impl (Claude Haiku 4.5). The Flutter app gets an `AiClient` (dio), a `MerchantMemory` Drift table, a smart-input box on the Add screen, and a Settings screen for tone — all behind the existing repository/provider layering. Local DB stays the source of truth; AI is a graceful enhancement that never blocks manual entry.

**Tech Stack:** Go 1.22 (std lib `net/http`, Anthropic Go SDK for the real client only), Flutter (dio, shared_preferences, Drift migration v1→v2), Claude Haiku 4.5.

**Reference spec:** `docs/superpowers/specs/2026-06-11-phase2-ai-entry-design.md`.

**Key constraint — NO API KEY YET:** every task is built and tested with the **fake** Go client + **mocked** HTTP. The real `anthropic.go` is written (Task 9) but not unit-tested until a key exists. The app runs end-to-end against the fake server.

---

## File Structure

```
moneynote/
├── server/                          # NEW — Go backend
│   ├── go.mod
│   ├── cmd/server/main.go           # config, pick real/fake AIClient, start http
│   └── internal/
│       ├── api/
│       │   ├── types.go             # ParseRequest, ParseResponse
│       │   ├── handler.go           # POST /ai/parse, GET /health
│       │   └── middleware.go        # X-Device-Token + in-memory rate limit
│       └── ai/
│           ├── client.go            # AIClient interface, ParseInput, ParseResult
│           ├── fake.go              # regex fake (no key)
│           ├── prompt.go            # system prompt text (pure, testable)
│           └── anthropic.go         # real Claude client (Task 9, via claude-api skill)
│   └── (tests alongside: *_test.go)
└── app/                             # EXISTING Flutter — additions:
    ├── lib/
    │   ├── core/prefs.dart          # shared_preferences wrapper (tone, deviceToken, baseUrl)
    │   ├── data/
    │   │   ├── database.dart         # +MerchantMemory table, schemaVersion 2 + migration
    │   │   ├── repository.dart       # +lookupMerchant / upsertMerchant
    │   │   ├── ai_models.dart        # ParseRequest, ParseResult, AiException, Tone
    │   │   └── ai_client.dart        # dio client for POST /ai/parse
    │   ├── state/providers.dart      # +prefsProvider, aiClientProvider, merchant lookups
    │   └── features/
    │       ├── transactions/add_transaction_screen.dart  # +smart input + learn-on-correct
    │       └── settings/settings_screen.dart             # tone selector
    └── test/
        ├── core/prefs_test.dart
        ├── data/merchant_memory_test.dart
        ├── data/ai_client_test.dart
        └── widget/smart_input_test.dart
```

---

## Task 1: Install Go + scaffold the module

Go is **not on PATH** on this machine (same situation Flutter was in). Reuse the project's PATH-refresh pattern for every `go` command.

**Files:** Create `server/go.mod`.

- [ ] **Step 1: Install Go (stable)**

Download Go for Windows from https://go.dev/dl/ (the `.msi`), install (it adds `C:\Program Files\Go\bin` to PATH and creates `%USERPROFILE%\go\bin`). Open a fresh PowerShell.

- [ ] **Step 2: Verify Go is callable in this session**

Because session shells may have a stale PATH, prefix go commands with the refresh (same pattern as flutter):
```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); go version
```
Expected: `go version go1.2x.x windows/amd64`. Use this `$env:Path = ...; go ...` prefix for ALL go commands below.

- [ ] **Step 3: Init the module**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
New-Item -ItemType Directory -Force D:\Freelance\moneynote\server | Out-Null
Set-Location D:\Freelance\moneynote\server
go mod init github.com/moneynote/server
```
Expected: creates `server/go.mod` with `module github.com/moneynote/server` and a `go 1.2x` line.

- [ ] **Step 4: Add server build artifacts to .gitignore**

Append to `D:\Freelance\moneynote\.gitignore`:
```gitignore
# Go
server/server.exe
server/*.exe
```

- [ ] **Step 5: Commit**

```powershell
Set-Location D:\Freelance\moneynote
git add server/go.mod .gitignore
git commit -m "chore: init Go module for AI proxy server"
```

---

## Task 2: AIClient interface + ParseInput/ParseResult types

The contract every AI client implements. Pure types — verified by compilation + a trivial test.

**Files:** Create `server/internal/ai/client.go`; test `server/internal/ai/client_test.go`.

- [ ] **Step 1: Write the failing test**

`server/internal/ai/client_test.go`:
```go
package ai

import "testing"

func TestParseResultZeroValue(t *testing.T) {
	var r ParseResult
	if r.Amount != 0 || r.Category != "" || r.Merchant != nil {
		t.Fatalf("unexpected zero value: %+v", r)
	}
}
```

- [ ] **Step 2: Run, verify FAIL (no types yet)**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\server; go test ./internal/ai/
```
Expected: build error — `ParseResult` undefined.

- [ ] **Step 3: Write `client.go`**

```go
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
```

- [ ] **Step 4: Run, verify PASS**

`go test ./internal/ai/` → PASS.

- [ ] **Step 5: Commit**

```powershell
git add server/internal/ai/client.go server/internal/ai/client_test.go
git commit -m "feat(server): AIClient interface + Parse types"
```

---

## Task 3: Fake AI client (regex, no key)

Lets the whole app run + tests pass without an API key. Parses "50k"/"1tr5", defaults type=expense, picks the first category, today's date.

**Files:** Create `server/internal/ai/fake.go`; test `server/internal/ai/fake_test.go`.

- [ ] **Step 1: Write the failing test**

`server/internal/ai/fake_test.go`:
```go
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
```

- [ ] **Step 2: Run, verify FAIL**

`go test ./internal/ai/` → `NewFake` undefined.

- [ ] **Step 3: Write `fake.go`**

```go
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
```

- [ ] **Step 4: Run, verify PASS**

`go test ./internal/ai/` → PASS (3 tests).

- [ ] **Step 5: Commit**

```powershell
git add server/internal/ai/fake.go server/internal/ai/fake_test.go
git commit -m "feat(server): fake AI client (regex parse, no key needed)"
```

---

## Task 4: System prompt builder (pure, testable)

The prompt text the real client will send. Pure function so it's testable without the SDK.

**Files:** Create `server/internal/ai/prompt.go`; test `server/internal/ai/prompt_test.go`.

- [ ] **Step 1: Write the failing test**

`server/internal/ai/prompt_test.go`:
```go
package ai

import "strings"

import "testing"

func TestBuildSystemPromptMentionsRules(t *testing.T) {
	p := BuildSystemPrompt()
	for _, want := range []string{"50k", "merchant", "category", "JSON"} {
		if !strings.Contains(strings.ToLower(p), strings.ToLower(want)) {
			t.Fatalf("system prompt missing %q", want)
		}
	}
}
```

- [ ] **Step 2: Run, verify FAIL**

`go test ./internal/ai/` → `BuildSystemPrompt` undefined.

- [ ] **Step 3: Write `prompt.go`**

```go
package ai

// BuildSystemPrompt returns the fixed system prompt for the parse tool.
// It is stable (cacheable) — keep all per-request data out of it.
func BuildSystemPrompt() string {
	return `Bạn là bộ phân tích chi tiêu tiếng Việt. Người dùng gõ một câu mô tả một giao dịch.
Trả về DUY NHẤT một JSON object đúng schema của tool, không thêm chữ nào ngoài tool call.

Luật:
- Số tiền là số nguyên ĐỒNG (VND). "50k"=50000, "1tr5"/"1m5"=1500000, "200"=200 nếu rõ là đồng.
- type: "expense" trừ khi câu rõ ràng là thu nhập ("lương", "được trả", "thưởng") -> "income".
- category: PHẢI chọn đúng một tên trong danh sách categories được cung cấp; nếu không khớp tốt, để chuỗi rỗng "".
- merchant: tên cửa hàng/thương hiệu/quán đã CHUẨN HOÁ chữ thường nếu có (vd "Highlands"->"highlands"); nếu câu không có vendor cụ thể (vd "ăn phở") -> null.
- occurred_at: ngày ISO YYYY-MM-DD, suy ra từ "today" được cung cấp ("hôm qua", "thứ 2 tuần trước"...). Mặc định = today.
- note: phần mô tả ngắn gọn.
- confidence: 0..1.
- comment: MỘT câu ngắn bằng tiếng Việt theo tone được yêu cầu (serious=trung tính, cheer=khen vui, scold=mắng yêu).`
}
```

- [ ] **Step 4: Run, verify PASS**

`go test ./internal/ai/` → PASS.

- [ ] **Step 5: Commit**

```powershell
git add server/internal/ai/prompt.go server/internal/ai/prompt_test.go
git commit -m "feat(server): system prompt builder (pure)"
```

---

## Task 5: HTTP types + handler (/ai/parse, /health)

**Files:** Create `server/internal/api/types.go`, `server/internal/api/handler.go`; test `server/internal/api/handler_test.go`.

- [ ] **Step 1: Write `types.go`**

```go
package api

// ParseRequest is the JSON body of POST /ai/parse.
type ParseRequest struct {
	Text       string   `json:"text"`
	Today      string   `json:"today"`
	Tone       string   `json:"tone"`
	Categories []string `json:"categories"`
	Wallets    []string `json:"wallets"`
}
```

- [ ] **Step 2: Write the failing handler test**

`server/internal/api/handler_test.go`:
```go
package api

import (
	"bytes"
	"context"
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

func TestHealth(t *testing.T) {
	h := NewHandler(ai.NewFake())
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	h.HandleHealth(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
}

var _ = context.Background
```

- [ ] **Step 3: Run, verify FAIL**

`go test ./internal/api/` → `NewHandler` undefined.

- [ ] **Step 4: Write `handler.go`**

```go
package api

import (
	"encoding/json"
	"net/http"

	"github.com/moneynote/server/internal/ai"
)

const maxTextLen = 500

type Handler struct {
	ai ai.AIClient
}

func NewHandler(client ai.AIClient) *Handler { return &Handler{ai: client} }

func (h *Handler) HandleHealth(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func (h *Handler) HandleParse(w http.ResponseWriter, r *http.Request) {
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
```

- [ ] **Step 5: Run, verify PASS**

`go test ./internal/api/` → PASS (3 tests).

- [ ] **Step 6: Commit**

```powershell
git add server/internal/api/types.go server/internal/api/handler.go server/internal/api/handler_test.go
git commit -m "feat(server): /ai/parse + /health handler with input validation"
```

---

## Task 6: Middleware — device token + in-memory rate limit

**Files:** Create `server/internal/api/middleware.go`; test `server/internal/api/middleware_test.go`.

- [ ] **Step 1: Write the failing test**

`server/internal/api/middleware_test.go`:
```go
package api

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func okHandler(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) }

func TestRequiresDeviceToken(t *testing.T) {
	mw := NewRateLimiter(5)
	h := mw.Wrap(http.HandlerFunc(okHandler))
	req := httptest.NewRequest(http.MethodPost, "/ai/parse", nil) // no token
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestRateLimitPerDevice(t *testing.T) {
	mw := NewRateLimiter(2) // 2 allowed, 3rd blocked
	h := mw.Wrap(http.HandlerFunc(okHandler))
	do := func() int {
		req := httptest.NewRequest(http.MethodPost, "/ai/parse", nil)
		req.Header.Set("X-Device-Token", "dev-1")
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec.Code
	}
	if do() != 200 || do() != 200 {
		t.Fatal("first 2 should pass")
	}
	if do() != http.StatusTooManyRequests {
		t.Fatal("3rd should be 429")
	}
}
```

- [ ] **Step 2: Run, verify FAIL**

`go test ./internal/api/` → `NewRateLimiter` undefined.

- [ ] **Step 3: Write `middleware.go`**

```go
package api

import (
	"net/http"
	"sync"
)

// RateLimiter requires an X-Device-Token header and caps requests per device
// for the process lifetime (in-memory; resets on restart — fine for v1).
type RateLimiter struct {
	limit int
	mu    sync.Mutex
	count map[string]int
}

func NewRateLimiter(limit int) *RateLimiter {
	return &RateLimiter{limit: limit, count: map[string]int{}}
}

func (rl *RateLimiter) Wrap(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token := r.Header.Get("X-Device-Token")
		if token == "" {
			writeErr(w, http.StatusUnauthorized, "missing_device_token")
			return
		}
		rl.mu.Lock()
		rl.count[token]++
		over := rl.count[token] > rl.limit
		rl.mu.Unlock()
		if over {
			writeErr(w, http.StatusTooManyRequests, "rate_limited")
			return
		}
		next.ServeHTTP(w, r)
	})
}
```

> Note: this is a simple lifetime cap. The spec's "30/hour" wording is approximated as a per-process cap for v1; a time-windowed limiter is a later refinement (out of scope, YAGNI now).

- [ ] **Step 4: Run, verify PASS**

`go test ./internal/api/` → PASS.

- [ ] **Step 5: Commit**

```powershell
git add server/internal/api/middleware.go server/internal/api/middleware_test.go
git commit -m "feat(server): device-token + in-memory rate-limit middleware"
```

---

## Task 7: Wire main.go (pick real/fake by env) + manual run

**Files:** Create `server/cmd/server/main.go`.

- [ ] **Step 1: Write `main.go`**

```go
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
```

> This references `ai.NewAnthropic` which is created in Task 9. Until then `go build` fails — that's expected; Task 9 makes it compile. (Do Tasks 8 in parallel on the Flutter side; come back to build main after Task 9.)

- [ ] **Step 2: Commit (compiles after Task 9)**

```powershell
git add server/cmd/server/main.go
git commit -m "feat(server): main wires real/fake client by ANTHROPIC_API_KEY"
```

---

## Task 8: Flutter — MerchantMemory table + repo methods (TDD)

Adds a Drift table (schema v1→v2 migration) + repository lookup/upsert.

**Files:** Modify `app/lib/data/database.dart` (+table, schemaVersion, migration), regenerate; modify `app/lib/data/repository.dart`; test `app/test/data/merchant_memory_test.dart`.

- [ ] **Step 1: Add the table + migration to `database.dart`**

Add this table class (next to the others):
```dart
class MerchantMemories extends Table {
  TextColumn get id => text()();
  TextColumn get merchant => text()(); // normalized lowercase
  TextColumn get categoryId => text().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```
Add `MerchantMemories` to the `@DriftDatabase(tables: [...])` list. Bump `schemaVersion` to `2` and add a migration:
```dart
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(merchantMemories);
        },
      );
```

- [ ] **Step 2: Regenerate Drift code**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\app; dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Write the failing test**

`app/test/data/merchant_memory_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  late AppDatabase db;
  late AppRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AppRepository(db);
  });
  tearDown(() => db.close());

  test('lookupMerchant returns null when nothing learned', () async {
    expect(await repo.lookupMerchant('highlands'), isNull);
  });

  test('upsert then lookup returns the learned category', () async {
    final c = await repo.addCategory(name: 'Cà phê', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c.id);
    final got = await repo.lookupMerchant('highlands');
    expect(got, isNotNull);
    expect(got!.id, c.id);
  });

  test('upsert twice updates, no duplicate', () async {
    final c1 = await repo.addCategory(name: 'Cà phê', type: CategoryType.expense);
    final c2 = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c1.id);
    await repo.upsertMerchant('highlands', c2.id);
    final got = await repo.lookupMerchant('highlands');
    expect(got!.id, c2.id);
  });
}
```

- [ ] **Step 4: Run, verify FAIL**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\app; flutter test test/data/merchant_memory_test.dart
```
Expected: `lookupMerchant`/`upsertMerchant` not defined.

- [ ] **Step 5: Add repo methods to `repository.dart`**

```dart
  /// Returns the learned Category for a normalized merchant, or null.
  Future<Category?> lookupMerchant(String merchant) async {
    final key = merchant.trim().toLowerCase();
    final mem = await (db.select(db.merchantMemories)
          ..where((t) => t.merchant.equals(key) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (mem == null) return null;
    return (db.select(db.categories)
          ..where((t) => t.id.equals(mem.categoryId) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Learns/updates merchant -> category.
  Future<void> upsertMerchant(String merchant, String categoryId) async {
    final key = merchant.trim().toLowerCase();
    final now = DateTime.now();
    final existing = await (db.select(db.merchantMemories)
          ..where((t) => t.merchant.equals(key)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.merchantMemories).insert(MerchantMemoriesCompanion.insert(
            id: _uuid.v4(),
            merchant: key,
            categoryId: categoryId,
            createdAt: now,
            updatedAt: now,
          ));
    } else {
      await (db.update(db.merchantMemories)..where((t) => t.id.equals(existing.id)))
          .write(MerchantMemoriesCompanion(
        categoryId: Value(categoryId),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ));
    }
  }
```

- [ ] **Step 6: Run, verify PASS**

`flutter test test/data/merchant_memory_test.dart` → PASS (3 tests).

- [ ] **Step 7: Commit**

```powershell
Set-Location D:\Freelance\moneynote
git add app/lib/data/database.dart app/lib/data/repository.dart app/test/data/merchant_memory_test.dart
git commit -m "feat(app): MerchantMemory table (schema v2) + lookup/upsert"
```

---

## Task 9: Real Anthropic client (via claude-api skill)

This is the ONLY file that calls Claude. It will not be unit-tested until an API key exists. **Do NOT hand-write the SDK calls from memory.**

**Files:** Create `server/internal/ai/anthropic.go`.

- [ ] **Step 1: Add the Anthropic Go SDK dependency**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\server; go get github.com/anthropics/anthropic-sdk-go
```

- [ ] **Step 2: Invoke the claude-api skill to generate the implementation**

Use the **claude-api skill** (it pulls current Go SDK bindings via its live sources). Requirements for the generated `anthropic.go`:
- Package `ai`. Export `func NewAnthropic(apiKey string) AIClient`.
- Implement `Parse(ctx, ParseInput) (ParseResult, error)` by calling **Claude Haiku 4.5** (model id `claude-haiku-4-5`).
- Force **structured output via tool use**: define one tool whose input schema mirrors `ParseResult` (amount int, type enum income|expense, category string, merchant string|null, occurred_at string, note string, confidence number, comment string); set tool_choice to force that tool; unmarshal the tool-use input into `ParseResult`.
- System prompt = `BuildSystemPrompt()` (Task 4) with **prompt caching** (`cache_control`) on the system block; put the per-request data (text, today, tone, categories list, wallets list) in the user message.
- On any SDK/timeout error, return the zero `ParseResult` and the error (the handler maps it to `502 ai_unavailable`).

- [ ] **Step 3: Verify it compiles**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\server; go build ./...
```
Expected: builds clean (now that `NewAnthropic` exists, `main.go` from Task 7 also compiles).

- [ ] **Step 4: Run the full Go test suite + vet**

```powershell
go test ./... ; go vet ./...
```
Expected: all tests pass (ai + api packages); vet clean. (anthropic.go has no unit test — it needs a real key; that's expected.)

- [ ] **Step 5: Manual smoke (fake mode, no key)**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\server; go run ./cmd/server
```
In another shell: `curl -s -X POST localhost:8080/ai/parse -H "X-Device-Token: t1" -d '{"text":"an pho 50k","today":"2026-06-11","tone":"serious","categories":["Ăn uống"],"wallets":["Tiền mặt"]}'` → expect JSON with `"amount":50000`. Stop the server (Ctrl+C).

- [ ] **Step 6: Commit**

```powershell
Set-Location D:\Freelance\moneynote
git add server/internal/ai/anthropic.go server/go.mod server/go.sum
git commit -m "feat(server): real Claude Haiku 4.5 client (tool-use structured output + caching)"
```

---

## Task 10: Flutter — prefs wrapper (tone, device token, base URL)

**Files:** Create `app/lib/core/prefs.dart`; add `shared_preferences` + `uuid` (already present) deps; test `app/test/core/prefs_test.dart`.

- [ ] **Step 1: Add dependency**

In `app/pubspec.yaml` dependencies add `shared_preferences: ^2.3.2`, then:
```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\app; flutter pub get
```

- [ ] **Step 2: Write the failing test**

`app/test/core/prefs_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneynote/core/prefs.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tone defaults to serious and persists', () async {
    final prefs = await AppPrefs.load();
    expect(prefs.tone, Tone.serious);
    await prefs.setTone(Tone.scold);
    final again = await AppPrefs.load();
    expect(again.tone, Tone.scold);
  });

  test('device token is generated once and stable', () async {
    final prefs = await AppPrefs.load();
    final t1 = prefs.deviceToken;
    expect(t1, isNotEmpty);
    final again = await AppPrefs.load();
    expect(again.deviceToken, t1);
  });

  test('base url defaults to emulator host', () async {
    final prefs = await AppPrefs.load();
    expect(prefs.baseUrl, 'http://10.0.2.2:8080');
  });
}
```

- [ ] **Step 3: Run, verify FAIL**

`flutter test test/core/prefs_test.dart` → `AppPrefs` undefined.

- [ ] **Step 4: Write `prefs.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum Tone { serious, cheer, scold }

class AppPrefs {
  final SharedPreferences _p;
  AppPrefs._(this._p);

  static const _kTone = 'tone';
  static const _kToken = 'device_token';
  static const _kBaseUrl = 'ai_base_url';

  static Future<AppPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    if (!p.containsKey(_kToken)) {
      await p.setString(_kToken, const Uuid().v4());
    }
    return AppPrefs._(p);
  }

  Tone get tone => Tone.values.firstWhere(
        (t) => t.name == _p.getString(_kTone),
        orElse: () => Tone.serious,
      );
  Future<void> setTone(Tone t) => _p.setString(_kTone, t.name);

  String get deviceToken => _p.getString(_kToken)!;
  String get baseUrl => _p.getString(_kBaseUrl) ?? 'http://10.0.2.2:8080';
}
```

- [ ] **Step 5: Run, verify PASS**

`flutter test test/core/prefs_test.dart` → PASS (3 tests).

- [ ] **Step 6: Commit**

```powershell
Set-Location D:\Freelance\moneynote
git add app/pubspec.yaml app/lib/core/prefs.dart app/test/core/prefs_test.dart
git commit -m "feat(app): AppPrefs (tone, device token, base url via shared_preferences)"
```

---

## Task 11: Flutter — AI models + AiClient (dio, mock HTTP)

**Files:** Create `app/lib/data/ai_models.dart`, `app/lib/data/ai_client.dart`; add `dio` dep; test `app/test/data/ai_client_test.dart`.

- [ ] **Step 1: Add dependency**

Add `dio: ^5.7.0` to `app/pubspec.yaml`, then `flutter pub get` (with PATH refresh).

- [ ] **Step 2: Write `ai_models.dart`**

```dart
import 'package:moneynote/core/prefs.dart';

class ParseRequest {
  final String text;
  final String today; // ISO yyyy-MM-dd
  final Tone tone;
  final List<String> categories;
  final List<String> wallets;
  const ParseRequest({
    required this.text,
    required this.today,
    required this.tone,
    required this.categories,
    required this.wallets,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'today': today,
        'tone': tone.name,
        'categories': categories,
        'wallets': wallets,
      };
}

class ParseResult {
  final int amount;
  final String type; // income | expense
  final String? category;
  final String? merchant;
  final String occurredAt;
  final String note;
  final double confidence;
  final String comment;
  const ParseResult({
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.occurredAt,
    required this.note,
    required this.confidence,
    required this.comment,
  });

  factory ParseResult.fromJson(Map<String, dynamic> j) => ParseResult(
        amount: (j['amount'] as num).toInt(),
        type: j['type'] as String? ?? 'expense',
        category: (j['category'] as String?)?.isEmpty ?? true
            ? null
            : j['category'] as String,
        merchant: j['merchant'] as String?,
        occurredAt: j['occurred_at'] as String,
        note: j['note'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        comment: j['comment'] as String? ?? '',
      );
}

class AiException implements Exception {
  final String code;
  AiException(this.code);
  @override
  String toString() => 'AiException($code)';
}
```

- [ ] **Step 3: Write the failing test**

`app/test/data/ai_client_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/data/ai_client.dart';
import 'package:moneynote/data/ai_models.dart';

class _StubAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  _StubAdapter(this.status, this.body);
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(body, status,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
}

ParseRequest _req() => const ParseRequest(
    text: 'an pho 50k', today: '2026-06-11', tone: Tone.serious,
    categories: ['Ăn uống'], wallets: ['Tiền mặt']);

void main() {
  test('maps 200 JSON to ParseResult', () async {
    final dio = Dio()
      ..httpClientAdapter = _StubAdapter(200,
          '{"amount":50000,"type":"expense","category":"Ăn uống","merchant":null,"occurred_at":"2026-06-11","note":"an pho","confidence":0.9,"comment":"ok"}');
    final client = AiClient(dio, baseUrl: 'http://x', deviceToken: 't1');
    final r = await client.parse(_req());
    expect(r.amount, 50000);
    expect(r.category, 'Ăn uống');
    expect(r.merchant, isNull);
  });

  test('throws AiException on 429', () async {
    final dio = Dio()..httpClientAdapter = _StubAdapter(429, '{"error":"rate_limited"}');
    final client = AiClient(dio, baseUrl: 'http://x', deviceToken: 't1');
    expect(() => client.parse(_req()), throwsA(isA<AiException>()));
  });
}
```

- [ ] **Step 4: Run, verify FAIL**

`flutter test test/data/ai_client_test.dart` → `AiClient` undefined.

- [ ] **Step 5: Write `ai_client.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:moneynote/data/ai_models.dart';

class AiClient {
  final Dio _dio;
  final String baseUrl;
  final String deviceToken;
  AiClient(this._dio, {required this.baseUrl, required this.deviceToken});

  Future<ParseResult> parse(ParseRequest req) async {
    try {
      final resp = await _dio.post(
        '$baseUrl/ai/parse',
        data: req.toJson(),
        options: Options(
          headers: {'X-Device-Token': deviceToken},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return ParseResult.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw AiException(status == 429 ? 'rate_limited' : 'ai_unavailable');
    }
  }
}
```

- [ ] **Step 6: Run, verify PASS**

`flutter test test/data/ai_client_test.dart` → PASS (2 tests).

- [ ] **Step 7: Commit**

```powershell
Set-Location D:\Freelance\moneynote
git add app/pubspec.yaml app/lib/data/ai_models.dart app/lib/data/ai_client.dart app/test/data/ai_client_test.dart
git commit -m "feat(app): ParseRequest/Result models + AiClient (dio) with error mapping"
```

---

## Task 12: Flutter — providers wiring

**Files:** Modify `app/lib/state/providers.dart`.

- [ ] **Step 1: Add providers**

```dart
import 'package:dio/dio.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/data/ai_client.dart';

final prefsProvider = FutureProvider<AppPrefs>((ref) => AppPrefs.load());

final aiClientProvider = Provider<AiClient?>((ref) {
  final prefs = ref.watch(prefsProvider).valueOrNull;
  if (prefs == null) return null;
  return AiClient(Dio(), baseUrl: prefs.baseUrl, deviceToken: prefs.deviceToken);
});
```

- [ ] **Step 2: Verify analyze**

`flutter analyze` → "No issues found!".

- [ ] **Step 3: Commit**

```powershell
git add app/lib/state/providers.dart
git commit -m "feat(app): prefs + aiClient providers"
```

---

## Task 13: Flutter — smart input on Add screen + learn-on-correction (+ widget test)

Integrates AI into the existing `AddTransactionScreen`: a text box + "Phân tích" button that calls AI, applies merchant memory, pre-fills the form; on save, learns if the user changed the AI-suggested category.

**Files:** Modify `app/lib/features/transactions/add_transaction_screen.dart`; test `app/test/widget/smart_input_test.dart`.

- [ ] **Step 1: Add smart-input state + logic to the screen**

In `_AddTransactionScreenState` add fields:
```dart
  final _smartCtrl = TextEditingController();
  bool _parsing = false;
  String? _merchant;            // from last AI parse (null if none)
  String? _aiSuggestedCategoryId; // category AI/memory suggested, to detect correction
```
Dispose `_smartCtrl` in `dispose()`.

Add the parse method (resolves category name→id, applies merchant memory override):
```dart
  Future<void> _runSmartParse() async {
    final text = _smartCtrl.text.trim();
    if (text.isEmpty) return;
    final client = ref.read(aiClientProvider);
    final prefs = ref.read(prefsProvider).valueOrNull;
    if (client == null || prefs == null) return;
    final cats = ref.read(categoriesProvider).valueOrNull ?? [];
    setState(() => _parsing = true);
    try {
      final today = DateTime.now();
      final res = await client.parse(ParseRequest(
        text: text,
        today:
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        tone: prefs.tone,
        categories: cats.map((c) => c.name).toList(),
        wallets:
            (ref.read(walletsProvider).valueOrNull ?? []).map((w) => w.name).toList(),
      ));

      // Resolve AI category name -> id
      String? catId = res.category == null
          ? null
          : cats.where((c) => c.name == res.category).map((c) => c.id).cast<String?>().firstOrNull;

      // Merchant memory override (takes priority over AI guess)
      if (res.merchant != null) {
        final learned = await ref.read(repositoryProvider).lookupMerchant(res.merchant!);
        if (learned != null) catId = learned.id;
      }

      if (!mounted) return;
      setState(() {
        _type = res.type == 'income'
            ? TransactionType.income
            : TransactionType.expense;
        _amountCtrl.text = res.amount.toString();
        _categoryId = catId;
        _aiSuggestedCategoryId = catId;
        _merchant = res.merchant;
        if (res.note.isNotEmpty) _noteCtrl.text = res.note;
      });
      if (res.comment.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.comment)));
      }
    } on AiException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI không khả dụng, nhập tay nhé')));
      }
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }
```
Add imports: `package:moneynote/data/ai_models.dart`, `package:moneynote/state/providers.dart` already imported; add `package:moneynote/core/prefs.dart` if needed. Add `firstOrNull` via `package:collection/collection.dart` OR replace with a manual helper — use a small inline: change the `.firstOrNull` to a helper `_firstOrNull(...)`:
```dart
  String? _firstWhereNameId(List<Category> cats, String name) {
    for (final c in cats) {
      if (c.name == name) return c.id;
    }
    return null;
  }
```
and use `catId = _firstWhereNameId(cats, res.category!);`.

In `_save()`, before the `addTransaction` call, learn on correction:
```dart
    if (_merchant != null && _categoryId != _aiSuggestedCategoryId && _categoryId != null) {
      await ref.read(repositoryProvider).upsertMerchant(_merchant!, _categoryId!);
    }
```

Add the smart-input widget at the TOP of the `ListView` children in `build`:
```dart
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('smartInput'),
                  controller: _smartCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Gõ "trưa nay ăn phở 50k"…',
                    prefixIcon: Icon(Icons.auto_awesome),
                  ),
                  onSubmitted: (_) => _runSmartParse(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('parseButton'),
                onPressed: _parsing ? null : _runSmartParse,
                child: _parsing
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Phân tích'),
              ),
            ],
          ),
          const Divider(height: 24),
```

- [ ] **Step 2: Write the widget test (mock AiClient via provider override)**

`app/test/widget/smart_input_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/data/ai_client.dart';
import 'package:moneynote/data/ai_models.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../drift_setup.dart';

class _FakeAiClient extends AiClient {
  _FakeAiClient() : super(_NoopDio(), baseUrl: 'x', deviceToken: 't');
  @override
  Future<ParseResult> parse(ParseRequest req) async => const ParseResult(
        amount: 50000, type: 'expense', category: 'Ăn uống', merchant: null,
        occurredAt: '2026-06-11', note: 'ăn phở', confidence: 0.9, comment: 'ok');
}

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('smart input parses and pre-fills the form', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final prefs = await AppPrefs.load();

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        prefsProvider.overrideWith((ref) async => prefs),
        aiClientProvider.overrideWithValue(_FakeAiClient()),
      ],
      child: const MaterialApp(home: AddTransactionScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byKey(const Key('smartInput')), 'ăn phở 50k');
    await tester.tap(find.byKey(const Key('parseButton')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('50000'), findsOneWidget); // amount field pre-filled

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}

// Minimal Dio stand-in so the superclass ctor is satisfied (parse is overridden).
class _NoopDio implements Object {}
```
> Note: `AiClient`'s constructor takes a `Dio`. If `_NoopDio` can't satisfy the type, change `_FakeAiClient` to wrap a real `Dio()` (never used because `parse` is overridden): `_FakeAiClient() : super(Dio(), baseUrl: 'x', deviceToken: 't');` and import dio. Use whichever compiles.

- [ ] **Step 3: Run, verify FAIL then implement adjustments, then PASS**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\app; flutter test test/widget/smart_input_test.dart
```
Adjust pump timings if the pre-fill hasn't landed. Expected: PASS.

- [ ] **Step 4: Analyze + commit**

`flutter analyze` → clean.
```powershell
Set-Location D:\Freelance\moneynote
git add app/lib/features/transactions/add_transaction_screen.dart app/test/widget/smart_input_test.dart
git commit -m "feat(app): smart input on Add screen (AI parse + merchant memory + learn-on-correct)"
```

---

## Task 14: Flutter — Settings screen (tone) + wire into shell

**Files:** Create `app/lib/features/settings/settings_screen.dart`; modify `app/lib/features/home/home_shell.dart` (add a Settings entry, e.g. an AppBar action).

- [ ] **Step 1: Write `settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(prefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (prefs) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Giọng điệu AI'),
            ),
            for (final t in Tone.values)
              RadioListTile<Tone>(
                title: Text(_toneLabel(t)),
                value: t,
                groupValue: prefs.tone,
                onChanged: (v) async {
                  if (v == null) return;
                  await prefs.setTone(v);
                  ref.invalidate(prefsProvider);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _toneLabel(Tone t) => switch (t) {
        Tone.serious => 'Nghiêm túc',
        Tone.cheer => 'Khen 🎉',
        Tone.scold => 'Mắng yêu 😤',
      };
}
```

- [ ] **Step 2: Add a Settings action to `home_shell.dart`**

In the `AppBar` of `HomeShell`, add:
```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
```
Add import `package:moneynote/features/settings/settings_screen.dart`.

- [ ] **Step 3: Analyze + commit**

`flutter analyze` → clean.
```powershell
git add app/lib/features/settings/settings_screen.dart app/lib/features/home/home_shell.dart
git commit -m "feat(app): Settings screen (AI tone) + shell entry"
```

---

## Task 15: End-to-end on emulator (fake server)

**Files:** none (verification).

- [ ] **Step 1: Run the full test suites**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
Set-Location D:\Freelance\moneynote\server; go test ./...
Set-Location D:\Freelance\moneynote\app; flutter test
```
Expected: Go all pass; Flutter all pass (Phase 1 tests + prefs + merchant memory + ai_client + smart_input).

- [ ] **Step 2: Start the fake server**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\server; go run ./cmd/server
```
(Leave running — "AI: FAKE mode".)

- [ ] **Step 3: Run the app on Pixel_6 and smoke-test**

Launch emulator (cold + software GPU per project notes), `flutter run`. Then:
1. Open Add → type `ăn phở 50k` in the smart input → tap **Phân tích** → amount + category pre-fill, a comment snackbar shows.
2. Change the category, save → re-parse a similar line for the same merchant later (when using real Claude) would reuse the learned category.
3. Settings → switch tone to "Mắng yêu" → parse again → comment tone changes.
4. AI off (stop server) → parse → toast "AI không khả dụng", manual entry still works.

- [ ] **Step 4: Commit any fixes; Phase 2 code complete**

---

## Self-Review (completed)

**Spec coverage (`2026-06-11-phase2-ai-entry-design.md`):**
- §2 std lib net/http → Tasks 5–7. shared_preferences → Task 10. 10.0.2.2 base URL → Task 10. mock/real boundary (AIClient interface) → Tasks 2/3/9. Claude Haiku 4.5 → Task 9. ✓
- §4 server folder structure (api/, ai/) → Tasks 2–7, 9. ✓
- §5 parse contract (request/response, merchant, error codes) → types (Task 5), handler validation/errors (Task 5), AiClient mapping (Task 11). ✓
- §6 merchant memory cách C (MerchantMemory table, apply/learn) → Task 8 (table+repo), Task 13 (apply override + learn-on-correct). ✓
- §7 smart input + settings + comment → Tasks 13, 14. ✓
- §8 error/offline (graceful, manual still works) → Task 13 catch AiException; handler errors Task 5. ✓
- §9 testing (Go mock client, middleware; Flutter mock HTTP, merchant memory, widget) → Tasks 3/5/6 + 8/11/13. ✓
- §10 no-key plan (fake mode) → Tasks 3, 7, 9 step 5, 15. ✓

**Placeholder scan:** Task 9 (anthropic.go) intentionally delegates SDK specifics to the claude-api skill — this is a precise, documented instruction (not a vague TODO), and the code is untestable until a key exists. Flagged explicitly. No other placeholders.

**Type consistency:** `AIClient.Parse(ctx, ParseInput) (ParseResult, error)` used in fake/handler/main/anthropic. `ParseResult` fields consistent Go↔Dart (amount/type/category/merchant/occurred_at/note/confidence/comment). Repo methods `lookupMerchant`/`upsertMerchant` consistent across Tasks 8 and 13. `Tone` enum (serious/cheer/scold) consistent Go↔Dart. Drift companion `MerchantMemoriesCompanion`.

**Known risks flagged:** Go not installed (Task 1). anthropic.go untested without key (Task 9). Drift schema v1→v2 migration must run (Task 8) — existing on-device data upgrades, doesn't reset.
