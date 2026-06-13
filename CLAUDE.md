# CLAUDE.md

Hướng dẫn cho agent/dev mới làm việc trong repo **MoneyNote**. Đọc cái này trước khi build/test.

## Repo là gì

App ghi chi tiêu **local-first** (tiếng Việt, offline), nhập bằng ngôn ngữ tự nhiên qua Claude. Monorepo:

- `app/` — Flutter (Dart 3, Riverpod, Drift/SQLite). Toàn bộ logic + UI; SQLite trên máy là **nguồn sự thật**.
- `server/` — Go, proxy AI **stateless** tới Claude Haiku 4.5 (giữ `ANTHROPIC_API_KEY` khỏi app). `POST /ai/parse`, `GET /health`.
- `docs/superpowers/` — spec + plan từng phase (quy trình: brainstorming → spec → plan → TDD).

## Build & chạy (app)

Chạy mọi lệnh app **từ thư mục `app/`**.

- Code sinh của Drift (`lib/data/database.g.dart`) **bị gitignore** (`*.g.dart`) → phải sinh trước khi build/test lần đầu, và mỗi khi sửa bảng/entity trong `lib/data/database.dart`:
  ```
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  ```
- Chạy app: `flutter run` (Windows desktop, hoặc emulator Android `Pixel_6`: `flutter emulators --launch Pixel_6`).
- Yêu cầu: Dart SDK ≥ 3.4 (`pubspec.yaml`); Flutter ≥ 3.38 (cần code assets cho sqlite3 3.x — máy dev đang 3.44).

## Server (Go)

Chạy từ `server/`:
```
go vet ./...
go test ./...
go run ./cmd/server                              # FAKE mode (regex, không cần API key)
ANTHROPIC_API_KEY=sk-... go run ./cmd/server     # gọi Claude thật
```
App trỏ `http://10.0.2.2:8080` mặc định (emulator → host); đổi URL trong Cài đặt cho thiết bị thật.

## Test

- App: `flutter test` (từ `app/`) — unit + widget, Drift in-memory.
- Server: `go test ./...` (từ `server/`) — handler/middleware/prompt, AI client giả.
- **CI và test KHÔNG bao giờ gọi Anthropic API thật** (fake client regex).
- **sqlite3 cho test (sau #12):** dùng `sqlite3` 3.x, native được bundle qua build hooks / code assets. `flutter test` tự nạp SQLite trên cả Windows lẫn Linux — **không** cần `sqlite3.dll`, **không** cần `libsqlite3-dev`, **không** cần `flutter config --enable-native-assets`. `test/drift_setup.dart` là no-op (giữ chữ ký `setupSqliteForTests()` cho test cũ).

## Bẫy hay gặp (máy dev Windows)

- `flutter test` treo, không in gì → process mồ côi từ lần chạy trước chặn lần sau. Kill rồi chạy lại:
  ```
  taskkill //F //IM flutter_tester.exe
  taskkill //F //IM dart.exe
  ```
- Go có thể không nằm trong PATH của shell mặc định: binary ở `C:\Users\NCPC\AppData\Local\Programs\Go\bin\go.exe`.

## Quy ước test (Drift + Riverpod)

- Trong `testWidgets`, đọc **stream** Drift (`repo.watchX().first`) **phải** bọc `tester.runAsync(() async { ... })` — await thẳng trong FakeAsync zone sẽ deadlock (timeout). Future một lần (insert/get/update) await thẳng được.
- Seed DB test: `AppDatabase(NativeDatabase.memory())` + `seedIfEmpty(db)`; đọc one-shot bằng `db.select(...).get()` (đừng đọc `.first` của stream trong thân test).
- Override provider: `ProviderScope(overrides: [databaseProvider.overrideWithValue(db), selectedMonthProvider.overrideWith((ref) => DateTime(...))])`.
- Widget test cần chỗ rộng để khỏi overflow: set `tester.view.physicalSize` lớn rồi reset trong `addTearDown`.

## Quy ước code

- **TDD nghiêm:** mỗi phase có design spec + plan trong `docs/superpowers/`. Test RED → code GREEN tối thiểu → commit gộp test+impl. `flutter analyze` 0 lỗi trước mỗi commit.
- **Git:** một nhánh per-issue (vd `feat/7-reports-charts`, `fix/17-...`), merge qua **PR** vào `master` — không commit thẳng `master`. Commit message tiếng Anh: `feat(app):` / `fix(server):` / `chore:` / `docs:` / `style:`.
- **Tiền = số nguyên đồng VND, cấm float.** Hiển thị qua `formatVnd` → `50.000 ₫` (dấu chấm phân nhóm, khoảng trắng, ₫). Chi/transfer **không có dấu trừ** — màu mang nghĩa (xanh = thu, đỏ = chi, xám = chuyển khoản).
- **Báo cáo / summary loại transfer** (transfer không phải thu cũng không phải chi — bài học Money Lover). "Code computes, LLM narrates" — AI chỉ parse + bình luận, **không** tính toán tài chính.
- **Kiến trúc app:** `UI (features/) → Riverpod (state/providers.dart) → domain/ (hàm thuần, dễ test) → data/ (repository + Drift)`. Mọi entity mang UUID + `updatedAt` + soft-delete `deletedAt` (sync-ready từ ngày đầu).

## CI

GitHub Actions chạy `flutter analyze` + `flutter test` (app) và `go vet` + `go test` (server) trên mỗi PR. Không gọi Anthropic API thật.
