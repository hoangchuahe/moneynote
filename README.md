# MoneyNote

> **Ghi chi tiêu trong 3 giây, bằng tiếng Việt, offline** — không cần link ngân hàng, không quảng cáo, không paywall.

A local-first personal expense tracker with natural-language entry powered by Claude. Type *"trưa nay ăn phở 50k"* and the app fills in the amount (50,000₫), category (Ăn uống), date, and note — you just confirm.

**Stack:** Flutter (Dart 3, Riverpod, Drift/SQLite) · Go (AI proxy) · Claude Haiku 4.5 (structured output via tool use, prompt caching)

## Why it's built this way

- **Local-first, no account.** The SQLite database on the device is the source of truth. The app works 100% offline — AI entry is a graceful enhancement, never a dependency. No bank linking by design: it's the #1 complaint in every competing app.
- **AI parses, the user confirms.** The smart input pre-fills the form; nothing is saved without explicit confirmation. Money amounts are integer VND everywhere — *code computes, the LLM narrates*.
- **Merchant memory.** Correct a category once and the app remembers the merchant → category mapping locally. You never fix the same merchant twice.
- **Personality toggle.** Each parse returns a one-line comment in the tone you pick: Nghiêm túc (neutral) / Khen 🎉 (cheer) / Mắng yêu 😤 (playful scold).
- **Sync-ready schema from day 1.** Every entity carries a client-side UUID, `updated_at`, and soft-delete `deleted_at` — accounts/sync can be added later without a schema rewrite.

## Architecture

```
┌────────────────────────────────────┐
│  Flutter App (Dart)                │  Android-first, iOS-aware
│  UI → Riverpod → Domain → Data     │
│  Drift (SQLite) ◄── source of truth│  offline 100%
└───────────────┬────────────────────┘
                │ HTTPS — only for AI entry (optional)
                ▼
┌────────────────────────────────────┐
│  Go backend (stateless AI proxy)   │  keeps ANTHROPIC_API_KEY off-device
│  POST /ai/parse · GET /health      │  device-token + hourly rate limit
└───────────────┬────────────────────┘
                ▼
         Claude Haiku 4.5
```

The Go proxy exists for one reason: the Anthropic API key must never ship inside a decompilable mobile app. v1 is a single stateless binary — no database, in-memory rate limiting, deployable anywhere.

## Repo layout

```
app/      Flutter app (all Dart in app/lib)
server/   Go backend (cmd/server + internal/{ai,api})
docs/     design specs & implementation plans
```

## Features

- ✅ Manual entry in ≤ 3 seconds (keypad-first, thousands grouping, default wallet)
- ✅ Natural-language entry in Vietnamese: "50k", "1tr5", "hôm qua", "thứ 2 tuần trước"
- ✅ Auto-categorization + merchant memory (learns from corrections)
- ✅ Wallets (cash/bank/e-wallet) with transfers between them
- ✅ Monthly budgets (per-category + overall) with overspend warning
- ✅ Dashboard (month summary, budgets, recent), search & filters
- ✅ Soft-delete with undo · dark mode · personality toggle
- 🔜 Reports (category pie, monthly trend) · recurring & bill reminders · CSV export · passcode/biometric

## Run it

**App** (Windows/macOS/Linux, Android emulator or device):

```bash
cd app
flutter pub get
flutter run
```

**Server** — runs in fake mode (regex parser, no key needed) so the full flow is testable for free:

```bash
cd server
go run ./cmd/server                 # FAKE mode — no API key required
ANTHROPIC_API_KEY=sk-... go run ./cmd/server   # real Claude parsing
```

The app talks to `http://10.0.2.2:8080` by default (Android emulator → host loopback); change the server URL in Settings for a real device.

## Tests

```bash
cd app && flutter test      # unit + widget tests (Drift in-memory)
cd server && go test ./...  # handler/middleware/prompt tests, mock AI client
```

CI never calls the real Anthropic API.

## Design docs

Every phase ships with a design spec and an implementation plan under [docs/superpowers/](docs/superpowers/) — from the master design ([moneynote-design](docs/superpowers/specs/2026-06-11-moneynote-design.md)) through AI entry, transfers/search, and budgets.
