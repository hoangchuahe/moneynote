# MoneyNote — Design Spec

> App mobile tính chi tiêu, local-first, có AI nhập liệu. Stack: Flutter (Dart) + Go + Claude.
> Ngày: 2026-06-11 · Trạng thái: Approved qua brainstorming, chờ user review bản viết.
> Tên "MoneyNote" là tên tạm — đổi được trước khi public store (chỉ ảnh hưởng branding/bundle id, không ảnh hưởng kiến trúc).

## 1. Mục tiêu & phạm vi

**Mục tiêu:** App tính chi tiêu cá nhân, dùng được offline 100%, nhập giao dịch nhanh bằng ngôn ngữ tự nhiên nhờ AI, đủ chất lượng để public lên App Store / Google Play khi sẵn sàng.

**Triết lý phạm vi (đã chốt):** **Local-first làm nền, kiến trúc chừa chỗ lên "app thật".**
- v1: dữ liệu sống hoàn toàn trên máy, không cần đăng nhập.
- Data model sync-ready từ ngày 1 (UUID, `updated_at`, soft-delete) để sau này bật account/sync không phải đập lại schema.
- Go backend v1 chỉ làm AI proxy; auth/sync thêm vào cùng service sau.

**Ngoài phạm vi v1:** OCR hoá đơn, account/auth, sync đa thiết bị, đa tiền tệ, monetization, AI insights định kỳ. (Ghi ở Roadmap — không thiết kế chi tiết ở đây.)

## 2. Quyết định đã chốt

| Hạng mục | Quyết định | Lý do |
|---|---|---|
| Stack | Flutter (Dart) cho mobile, Go cho backend | Yêu cầu của anh; 1 codebase Flutter build cả iOS + Android |
| Phạm vi | Local-first + Go nhẹ (AI proxy) | Offline 100%, Go có việc thật mà không over-build |
| AI v1 | Nhập ngôn ngữ tự nhiên + tự phân loại danh mục | Chung 1 backbone parse → làm 1 được 2 |
| AI engine | Claude — Haiku 4.5 (`claude-haiku-4-5-20251001`) | Rẻ, nhanh, đủ cho parse; nâng Sonnet được nếu cần |
| Vì sao cần Go | Giấu `ANTHROPIC_API_KEY` — không bao giờ nhúng key vào app | App Flutter decompile được; key lộ = bị đốt tiền |
| Tiền tệ | Chỉ VND, lưu `currency_code` sẵn | Đơn giản cho v1, chừa chỗ đa tiền tệ |
| Platform | Android-first + iOS-aware, mốc "iOS hardening" trước khi lên store | Dev trên Windows; build iOS cần Mac → dùng Codemagic CI khi tới mốc |
| State management | Riverpod | Modern, testable; là khuyến nghị đã trình ở design review và được duyệt |
| Local DB | Drift (SQLite) | Type-safe, reactive query, hỗ trợ migration |

## 3. Kiến trúc tổng thể

```
┌────────────────────────────────────┐
│  Flutter App (Dart)                 │  Android-first, iOS-aware
│  • UI screens                       │
│  • State: Riverpod                  │
│  • Local DB: Drift (SQLite)  ◄──────┼── NGUỒN SỰ THẬT, offline 100%
│  • Repository layer                 │
└───────────────┬────────────────────┘
                │ HTTPS — CHỈ khi dùng AI (optional)
                ▼
┌────────────────────────────────────┐
│  Go Backend (AI proxy)              │
│  • POST /ai/parse                   │  giữ ANTHROPIC_API_KEY
│  • GET  /health                     │
│  • (tương lai) auth, /sync          │
└───────────────┬────────────────────┘
                │ Anthropic API
                ▼
           Claude Haiku 4.5
```

**Nguyên tắc vàng:** Local DB là nguồn sự thật. App chạy đầy đủ khi offline hoặc backend chết — AI là *graceful enhancement*, không phải dependency cứng. Mọi tính năng core (nhập tay, xem báo cáo, budget) không đụng network.

**Cấu trúc repo (monorepo):**

```
moneynote/
├── app/        ← Flutter app (toàn bộ Dart trong app/lib/)
├── server/     ← Go backend
└── docs/       ← spec, plan
```

## 4. Flutter app — kiến trúc tầng

Bốn tầng, phụ thuộc một chiều từ trên xuống:

1. **Presentation (UI):** các màn hình — Home/Dashboard, Add Transaction, Transactions list, Settings/quản lý danh mục & ví (phase 1); ô smart input AI trong Add Transaction (phase 2); Budgets, Reports (phase 3). Widget chỉ đọc state từ Riverpod provider và gọi action.
2. **State (Riverpod):** provider/notifier per-feature. Không chứa business logic nặng — uỷ quyền cho domain.
3. **Domain:** model thuần Dart (`Transaction`, `Category`, `Wallet`, `Budget`) + use-case (thêm/sửa/xoá giao dịch, tính tổng theo kỳ, kiểm tra budget).
4. **Data:** Drift database + DAO; `AiClient` (HTTP mỏng gọi Go). **Repository** là cửa duy nhất tầng trên được chạm — UI không bao giờ query DB hay gọi network trực tiếp.

Mỗi feature đặt trong folder riêng (`features/transactions/`, `features/budgets/`…) để file không phình to và test độc lập được.

## 5. Data model (sync-ready từ ngày 1)

Mọi entity đều có: `id` (UUID v4, sinh client-side), `created_at`, `updated_at` (UTC), `deleted_at` (nullable — soft-delete). Query mặc định lọc `deleted_at IS NULL`. Đây là phần "chừa chỗ" cho sync: máy chủ sau này merge theo `updated_at`, xoá mềm sync được thay vì mất dấu.

| Entity | Field chính | Ghi chú |
|---|---|---|
| **Transaction** | `amount` (int, đồng VND), `type` (income/expense), `category_id`, `wallet_id`, `note` (text), `occurred_at` (date) | **Tiền là số nguyên đồng — cấm float.** VND không có xu nên int là tự nhiên |
| **Category** | `name`, `icon`, `color`, `type` (income/expense), `is_default` | Seed sẵn ~10 danh mục mặc định tiếng Việt (Ăn uống, Đi lại, Hoá đơn, Mua sắm, Giải trí, Sức khoẻ, Giáo dục, Lương, Thưởng, Khác) |
| **Wallet** | `name`, `type` (cash/bank/ewallet), `initial_balance` (int), `currency_code` (luôn `"VND"` ở v1) | Số dư hiện tại = `initial_balance` + Σ giao dịch (derived, không lưu trùng) |
| **Budget** | `category_id` (nullable — null = budget tổng), `amount` (int), `period` (v1 chỉ `monthly`), `start_date` | So với tổng expense của danh mục trong tháng |

Onboarding lần đầu: tự tạo 1 wallet "Tiền mặt" + seed categories — user mở app là nhập được ngay, không bắt setup.

## 6. AI flow (backbone chung cho 2 tính năng)

**Tính năng:** (a) nhập ngôn ngữ tự nhiên, (b) tự phân loại danh mục — cùng 1 endpoint, 1 prompt.

1. User gõ vào ô smart input: `"trưa nay ăn phở 50k"`.
2. Flutter gửi `POST /ai/parse` body: `{ text, today (ISO date, để resolve "hôm qua"), categories: [tên danh mục hiện có], wallets: [tên ví] }`.
3. Go build prompt + gọi Claude Haiku với **structured output (tool use / JSON schema)** — ép schema trả về:
   ```json
   { "amount": 50000, "type": "expense", "category": "Ăn uống",
     "occurred_at": "2026-06-11", "note": "ăn phở", "confidence": 0.95 }
   ```
   `category` phải chọn từ danh sách gửi lên (hoặc `null` nếu không khớp — app fallback "Khác").
4. Go trả JSON → Flutter **pre-fill form Add Transaction** để user xem lại, sửa nếu cần, bấm lưu. **AI không bao giờ tự lưu** — AI gợi ý, người xác nhận.
5. Parse hiểu tiếng Việt: "50k" = 50.000đ, "1tr5"/"1m5" = 1.500.000đ, "hôm qua"/"thứ 2 tuần trước" → ngày cụ thể (tính từ `today`).

**Chi phí:** mỗi parse vài trăm token Haiku (~không đáng kể). System prompt cố định → bật **prompt caching** phía Anthropic để giảm thêm.

## 7. Bảo vệ AI proxy

`/ai/parse` mở toang = ai biết URL cũng đốt được credit Claude. v1 chưa có account nhưng vẫn cần cổng nhẹ:

- App sinh **device token** (UUID ngẫu nhiên, ẩn danh) lần đầu mở, lưu local, gửi kèm header `X-Device-Token` mọi request.
- Go **rate-limit per-device** (in-memory, ví dụ 30 req/giờ/device) + giới hạn độ dài `text` đầu vào (500 ký tự).
- Token không định danh người dùng — không phải auth, chỉ là chốt chặn lạm dụng. Auth thật là việc của phase account sau này.
- Server log số lượng request/device để phát hiện bất thường; không log nội dung text (privacy).

## 8. Go backend — thiết kế

- **1 binary**, HTTP server dùng **chi** router (hoặc std lib `net/http` nếu muốn zero-dep — quyết ở plan).
- **v1 stateless, không database** — chỉ proxy AI. Rate-limit giữ in-memory (chấp nhận reset khi restart; đủ cho v1).
- Cấu trúc chừa chỗ:
  ```
  server/
  ├── cmd/server/main.go
  └── internal/
      ├── api/      ← handler, middleware (device token, rate limit)
      ├── ai/       ← Anthropic client, prompt builder, schema
      ├── auth/     ← (tương lai)
      └── sync/     ← (tương lai)
  ```
- Endpoints v1: `POST /ai/parse`, `GET /health`.
- `ANTHROPIC_API_KEY` đọc từ env. Dùng **Anthropic Go SDK** chính thức, gọi tool-use để ép structured output.
- Deploy v1: chạy đâu cũng được (1 binary) — local khi dev, VPS/Fly.io/Render khi cần demo thật. Không chốt nhà cung cấp ở spec này.

## 9. Error handling

- **Ghi local DB:** mọi write trong transaction của SQLite — không bao giờ mất/hỏng data vì crash giữa chừng.
- **AI call phía app:** timeout 8s, retry 1 lần; thất bại → toast nhẹ "AI không khả dụng" và **form nhập tay vẫn dùng bình thường** (smart input chỉ là một ô phía trên form). Không bao giờ block flow nhập liệu vì network.
- **AI parse confidence thấp / thiếu field:** vẫn pre-fill phần parse được, field thiếu để trống cho user điền — không đoán bừa.
- **Backend:** validate input (text ≤ 500 chars, JSON đúng shape), map lỗi Anthropic (timeout/rate-limit/5xx) về error code sạch (`502 ai_unavailable`, `429 rate_limited`…), không leak chi tiết nội bộ.

## 10. Testing

- **Flutter:**
  - Unit: repository (với Drift in-memory DB), util tiền tệ (format VND, parse "50k"-style hiển thị), logic budget.
  - Widget test: flow thêm giao dịch tay (mở form → nhập → lưu → thấy trong list).
  - AI client test với mock HTTP — không gọi backend thật.
- **Go:**
  - Unit handler với **mock Anthropic client** (interface) — test build prompt đúng, map response/lỗi đúng.
  - Table-driven test cho edge case parse request (text rỗng, quá dài, thiếu field).
  - Middleware test: rate limit, device token.
- **Nguyên tắc:** CI không bao giờ gọi Anthropic API thật.

## 11. Mốc "iOS hardening" (trước khi lên App Store)

Toàn bộ giai đoạn dev diễn ra trên Windows + Android emulator. Code **iOS-aware từ ngày 1**: dùng `SafeArea`, widget/behavior adaptive nơi quan trọng, chỉ chọn plugin hỗ trợ cả 2 platform. Khi app đủ chín, chạy checkpoint:

1. Có Mac access: **Codemagic free tier** (build cloud) — chưa cần mua Mac.
2. Điền `ios/` config: signing, permission strings trong `Info.plist`.
3. Test trên iOS thật/simulator: safe area (tai thỏ), font, keyboard tiếng Việt, date picker, format VND.
4. Apple Developer **$99/năm** + ký app.
5. Build qua Codemagic → TestFlight → App Store review.

Lưu ý đã phân tích: cùng 1 codebase, không viết lại cho iOS (~95% dùng nguyên); mốc này là **điền config + verify tận mắt + polish 1–2 ngày**, không phải port.

## 12. Roadmap

| Phase | Nội dung | Ghi chú |
|---|---|---|
| **1 — Core** | Scaffold repo phần `app/` (Flutter; `server/` để phase 2); Drift schema + seed, CRUD giao dịch, danh mục, ví, dashboard cơ bản (tổng thu/chi tháng, list gần nhất) | **Chưa có AI, chưa cần backend.** App dùng được end-to-end offline |
| **2 — AI** | Go server `/ai/parse` + device token + rate limit; smart input trong app; auto-categorize | Phần khác biệt của app |
| **3 — Reports & Budget** | Pie chart theo danh mục, trend theo tháng, budget + cảnh báo vượt | |
| **4 — iOS hardening** | Mục 11 → TestFlight | |
| **Sau v1** | OCR hoá đơn (vision) · account/auth · sync đa thiết bị · đa tiền tệ · premium · AI insights | Mỗi cái 1 spec riêng khi tới lượt |

Mỗi phase có plan riêng (writing-plans) và dùng được thật khi xong — không có phase nào kết thúc ở trạng thái nửa vời.

## 13. Tech stack tổng hợp

| Lớp | Chọn |
|---|---|
| Mobile | Flutter (Dart 3), Riverpod, Drift (SQLite), dio (HTTP), fl_chart (charts — phase 3) |
| Backend | Go, chi router (hoặc std lib), Anthropic Go SDK |
| AI | Claude Haiku 4.5, structured output qua tool use, prompt caching |
| iOS CI | Codemagic (phase 4) |
