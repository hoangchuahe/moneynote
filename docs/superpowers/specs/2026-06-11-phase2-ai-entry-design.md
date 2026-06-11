# MoneyNote Phase 2 — AI Entry — Design Spec

> AI-assisted entry: Go backend `/ai/parse` (Claude Haiku 4.5 proxy) + natural-language input + auto-categorize + merchant memory + personality toggle.
> Ngày: 2026-06-11 · Trạng thái: Approved qua brainstorming, chờ user review bản viết.
> Bổ sung cho spec gốc `2026-06-11-moneynote-design.md` (§6–§10). Phase 1 (core local app) đã xong + merged master.

## 1. Mục tiêu & phạm vi

**Mục tiêu:** Thêm lớp AI lên app local-first đã có — user gõ "trưa nay ăn phở 50k" → AI parse ra giao dịch (số tiền, danh mục, ngày, merchant) → **pre-fill form, user xác nhận**. Kèm tự phân loại, merchant memory (học correction), và personality toggle.

**Trong phạm vi P2:** Go backend AI proxy · NL entry · auto-categorize · merchant memory · personality (3 tone) · device-token + rate-limit · mock/real boundary.

**Ngoài phạm vi P2 (backlog/phase sau):** OCR hoá đơn, voice entry, chat hỏi đáp, AI insight/digest, account/auth, multi-device sync, deploy cloud, budgets/reports/recurring (P3).

**Nguyên tắc giữ nguyên từ P1:** Local DB là nguồn sự thật. AI là **graceful enhancement** — smart input lỗi/không mạng/không key → form nhập tay vẫn chạy bình thường, không bao giờ block.

## 2. Quyết định đã chốt

| Hạng mục | Quyết định | Lý do |
|---|---|---|
| AI engine | **Claude Haiku 4.5** (`claude-haiku-4-5`) | Rẻ, nhanh, đủ cho parse ngắn (chốt từ spec gốc) |
| Go router | **std lib `net/http`** (Go 1.22 ServeMux + middleware tự viết) | 2 endpoint + 2 middleware, không cần framework; dep duy nhất là Anthropic Go SDK |
| Lưu setting app-local | **`shared_preferences`** (tone, device token, base URL) | Pref app-local, không sync — tách khỏi Drift (domain data) |
| Networking dev | App đọc base URL từ config, default `http://10.0.2.2:8080` | `10.0.2.2` = cách Android emulator gọi localhost host |
| Mock/real boundary | Go `AIClient` interface: real (Anthropic SDK) nếu có `ANTHROPIC_API_KEY`, ngược lại fake | **Chưa có key vẫn build + test + chạy app full**; cắm key → tự bật real |
| Hosting | **Local-dev** (Go trên máy, emulator gọi 10.0.2.2); viết deploy-ready, chưa deploy cloud | Giữ P2 gọn; deploy là việc sau khi cần demo điện thoại thật |
| Merchant memory | **Cách C** — AI trả thêm field `merchant`; memory = `merchant → category`, match exact | Generalize tốt, tận dụng AI đang gọi sẵn (xem §6) |

## 3. Kiến trúc

```
┌──────────────────────────────────────┐
│  Flutter app (Phase 1 + lớp AI)       │
│  • AddTransactionScreen + smart input │
│  • AiClient (dio) ──────────┐         │
│  • MerchantMemory (Drift)   │         │  Local DB vẫn là nguồn sự thật
│  • Settings (shared_prefs)  │         │
└─────────────────────────────┼─────────┘
                              │ POST /ai/parse  (HTTPS; X-Device-Token)
                              ▼
┌──────────────────────────────────────┐
│  Go backend (server/) — stateless     │
│  • net/http: /ai/parse, /health       │
│  • middleware: device-token, ratelimit│
│  • AIClient: real(Anthropic) | fake   │  giữ ANTHROPIC_API_KEY
└─────────────────────────────┼─────────┘
                              │ Anthropic API (tool-use, prompt caching)
                              ▼
                       Claude Haiku 4.5
```

Repo (bổ sung vào monorepo hiện có):
```
moneynote/
├── app/      ← Flutter (đã có; P2 thêm ai_entry/, settings/, MerchantMemory, AiClient)
├── server/   ← Go backend (MỚI ở P2)
└── docs/
```

## 4. Go backend (`server/`)

```
server/
├── go.mod
├── cmd/server/main.go        ← load config, chọn AIClient (real nếu có key, else fake), start http
└── internal/
    ├── api/
    │   ├── handler.go        ← POST /ai/parse, GET /health
    │   ├── middleware.go     ← X-Device-Token (bắt buộc) + rate-limit in-memory 30/giờ/device
    │   └── types.go          ← ParseRequest, ParseResponse (JSON shapes)
    └── ai/
        ├── client.go         ← interface AIClient { Parse(ctx, ParseInput) (ParseResult, error) }
        ├── anthropic.go       ← real: Claude Haiku 4.5 qua Anthropic Go SDK, tool-use structured output, prompt caching
        ├── fake.go           ← fake: regex parse "số+k/tr", category đầu danh sách — cho dev/test KHÔNG key
        └── prompt.go         ← system prompt + tool JSON schema + build per-request input
```

- **Stateless, không DB.** Rate-limit + device-token tracking giữ in-memory (reset khi restart — đủ v1).
- `ANTHROPIC_API_KEY` đọc từ env, **không bao giờ** ở client.
- `main.go` chọn client: có key → `anthropic.New(...)`; không key → `fake.New()` + log cảnh báo "AI: FAKE mode (no ANTHROPIC_API_KEY)".
- **prompt.go:** system prompt cố định (luật parse tiếng Việt + ép chọn category từ danh sách + chuẩn hoá merchant + sinh comment theo tone) → đặt `cache_control` để **prompt caching**; phần volatile (text/today/categories/wallets/tone) đặt sau.

> ⚠️ **Implementation note:** khi viết `anthropic.go` PHẢI dùng **skill claude-api** lấy đúng binding Go SDK (messages, tool-use ép structured output, prompt caching, model id `claude-haiku-4-5`) — không code Claude theo trí nhớ.

## 5. Parse contract

**Request** — `POST /ai/parse`, header `X-Device-Token: <uuid>`:
```json
{
  "text": "trưa nay ăn phở 50k",
  "today": "2026-06-11",
  "tone": "serious",
  "categories": ["Ăn uống", "Đi lại", "Hoá đơn", "..."],
  "wallets": ["Tiền mặt", "Vietcombank"]
}
```
`tone` ∈ `serious` | `cheer` | `scold`.

**Response 200:**
```json
{
  "amount": 50000,
  "type": "expense",
  "category": "Ăn uống",
  "merchant": null,
  "occurred_at": "2026-06-11",
  "note": "ăn phở",
  "confidence": 0.95,
  "comment": "Phở trưa hợp lý đó, ghi sổ nha."
}
```
- `category` PHẢI thuộc danh sách gửi lên, hoặc `null` → app fallback "Khác".
- `merchant`: tên vendor/brand/quán **chuẩn hoá lowercase** nếu có (vd "Highlands 40k" → `"highlands"`); `null` nếu text không có vendor cụ thể (vd "ăn phở" → null, vì "phở" là món, không phải vendor).
- Parse tiếng Việt: `"50k"`=50.000, `"1tr5"`/`"1m5"`=1.500.000, `"hôm qua"`/`"thứ 2 tuần trước"` → ngày cụ thể tính từ `today`.

**Error codes:** `400 invalid_input` (thiếu field / text > 500 ký tự) · `401 missing_device_token` · `429 rate_limited` · `502 ai_unavailable` · `504 ai_timeout`. Không leak chi tiết nội bộ.

## 6. Merchant memory (cách C)

**Mục đích thật:** tăng độ chính xác category + **không bắt user sửa cùng một merchant hai lần**. (Lưu ý: KHÔNG giảm số lần gọi LLM — vẫn cần LLM cho số tiền/ngày; chỉnh lại cách diễn đạt sai ở spec gốc §6.)

**Bảng Drift `MerchantMemory`** (sync-ready):
| Field | Kiểu |
|---|---|
| `id` | TEXT (UUID) PK |
| `merchant` | TEXT — đã normalize lowercase, **unique** trong các dòng chưa xoá |
| `categoryId` | TEXT → Categories.id |
| `createdAt`, `updatedAt` | DateTime |
| `deletedAt` | DateTime? (soft-delete) |

**Apply (sau parse, trước pre-fill):** nếu `result.merchant != null` → `repo.lookupMerchant(merchant)`; nếu có → **override `result.category`** bằng category đã học (ưu tiên hơn AI guess).

**Learn (khi lưu giao dịch gốc-từ-AI):** nếu giao dịch đến từ smart input, có `merchant != null`, và user đã **đổi category** so với cái pre-fill → `repo.upsertMerchant(merchant, chosenCategoryId)`.

Repo methods mới: `Future<Category?> lookupMerchant(String merchant)` · `Future<void> upsertMerchant(String merchant, String categoryId)`.

## 7. Flutter side

- **`lib/data/ai_client.dart`** — `AiClient` (dio): `Future<ParseResult> parse(ParseRequest)`; timeout 8s + retry 1; map lỗi HTTP → `AiException(code)`. Đọc base URL + device token từ prefs.
- **`lib/core/prefs.dart`** — wrapper `shared_preferences`: `tone` (default `serious`), `deviceToken` (sinh UUID lần đầu), `aiBaseUrl` (default `http://10.0.2.2:8080`).
- **`lib/features/ai_entry/`** — ô **smart input** gắn phía trên form trong `AddTransactionScreen` hiện có: gõ text → nút "Phân tích" → gọi AiClient → (apply merchant memory) → **pre-fill** các field của form. Form tay giữ nguyên.
- **`lib/features/settings/settings_screen.dart`** — màn nhỏ chọn tone (Nghiêm túc / Khen 🎉 / Mắng yêu 😤); thêm vào tab/menu. `comment` từ response hiện qua snackbar/dòng nhỏ sau parse.
- **State:** provider cho prefs + một controller xử lý smart-input (loading/error/result) — UI vẫn chỉ đọc provider, không gọi network trực tiếp (giữ kiến trúc P1).

## 8. Error / offline handling

- AiClient lỗi (timeout/mạng/429/502/không key-thật) → `AiException` → smart input hiện toast nhẹ ("AI không khả dụng, nhập tay nhé"), **form tay vẫn lưu bình thường**. Không block.
- Confidence thấp / thiếu field → pre-fill phần parse được, để trống phần thiếu (không đoán bừa).
- Backend: validate input (text ≤ 500), map lỗi Anthropic → error code sạch (§5).

## 9. Testing

- **Go:**
  - `handler_test.go` — inject **fake/stub AIClient** (không gọi Anthropic): /ai/parse trả shape đúng; /health 200.
  - Table-driven validate request: text rỗng / > 500 ký tự / thiếu field → 400.
  - `middleware_test.go` — thiếu device-token → 401; vượt rate-limit → 429.
  - `fake_test.go` — regex parse "50k"/"1tr5" đúng.
- **Flutter:**
  - `ai_client_test.dart` — mock HTTP: map response → ParseResult; map lỗi → AiException. **Không gọi backend thật.**
  - `merchant_memory_test.dart` — Drift in-memory: upsert + lookup; apply override đúng category đã học; **không override khi chưa học**.
  - Widget test smart-input — mock AiClient → gõ text → bấm phân tích → form pre-fill đúng (amount/category).
- **CI không bao giờ gọi Anthropic thật.**

## 10. "Chưa có API key" — vẫn build + chạy được

1. `cd server && go run ./cmd/server` → khởi động ở **FAKE mode** (log cảnh báo), lắng nghe `:8080`.
2. App (emulator) gõ "ăn phở 50k" → fake parse regex → form pre-fill → lưu được. Toàn bộ flow + test chạy không cần key.
3. **Bật real Claude:** `set ANTHROPIC_API_KEY=sk-...` → restart server → tự dùng Claude Haiku 4.5. (App không đổi gì.)

## 11. Roadmap sau P2

OCR hoá đơn (vision) · voice entry · chat hỏi đáp · AI insight/digest · deploy cloud (Fly.io/Render) — mỗi cái spec riêng khi tới lượt. P3 (budgets/reports/recurring/transfer UI/search) độc lập với P2.
