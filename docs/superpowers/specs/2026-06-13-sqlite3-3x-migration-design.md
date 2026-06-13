# MoneyNote — Migrate sang `sqlite3` 3.x (bỏ `sqlite3_flutter_libs`) — Design Spec

> Tech-debt #12. `sqlite3_flutter_libs` đã EOL (bản mới nhất `0.6.0+eol` xoá sạch code). Lối đi chính thức của maintainer: **bỏ hẳn** package này và dùng `sqlite3` 3.x — package này tự bundle SQLite native qua **build hooks / code assets**.
> Ngày: 2026-06-13 · Trạng thái: Approved qua brainstorming (đã spike xác minh), chờ user review · Issue: #12

## 1. Bối cảnh & vấn đề

- `sqlite3_flutter_libs 0.5.x` EOL; bản "mới" `0.6.0+eol` chỉ là **tombstone** (xoá hết code). Không có "0.5→0.6" để bump.
- Maintainer chỉ rõ: từ `sqlite3` **3.x**, `sqlite3_flutter_libs` không còn cần — `sqlite3` 3.x tự bundle SQLite native qua build hooks (kéo `native_toolchain_c`).
- `drift` cần **≥ 2.32** mới chạy `sqlite3` 3.x (đang 2.31, mới nhất 2.34).
- Code assets **stable từ Flutter 3.38 / Dart 3.10**; máy dev + CI dùng `channel: stable` (local 3.44 / Dart 3.12). Đủ điều kiện.

⇒ #12 không phải "bump version" mà là **một migration** sang cơ chế bundle native mới.

## 2. Spike đã xác minh (2026-06-13, nhánh nháp `spike/12-sqlite3-3x` đã xoá)

Bằng chứng thực tế, không phải giả định:

- `flutter pub get`: drift 2.31→**2.34**, sqlite3 2.9.4→**3.3.3**, sqlparser→0.44.5, **+`native_toolchain_c` 0.19.1**, **−`sqlite3_flutter_libs`** — resolve sạch.
- `dart run build_runner build` (drift 2.34): codegen OK. 1 warning **lành**: manager API không đặt được tên cho `transactionsRefs` (Transactions trỏ Wallets 2 lần qua `walletId`+`toWalletId`) — app dùng drift **classic query API**, không dùng `.managers`, nên vô hại.
- **`flutter test` (Windows): 96/96 PASS** sau khi `drift_setup.dart` thành no-op — native assets **tự cấp** SQLite. KHÔNG cần cờ `flutter config --enable-native-assets`, KHÔNG cần `app/sqlite3.dll`.
- `flutter build apk --debug`: ✅ 57.6s — NDK cross-compile + đóng gói code asset OK.
- **Break duy nhất**: sqlite3 3.0 **bỏ `package:sqlite3/open.dart`** (`open.overrideFor` / `OperatingSystem`). Đây là lý do harness cũ không biên dịch — fix bằng cách no-op harness.

## 3. Quyết định đã chốt

| Hạng mục | Quyết định |
|---|---|
| Cơ chế native | Bỏ `sqlite3_flutter_libs`; `sqlite3` 3.x bundle qua build hooks (`native_toolchain_c`) |
| drift | Bump `drift` + `drift_dev` → `^2.34.0` (tối thiểu 2.32 cho sqlite3 3.x; lấy bản mới nhất) |
| dev `sqlite3` | **Bỏ** dependency trực tiếp (drift kéo 3.x transitively; sau no-op harness không còn `import 'package:sqlite3/...'`). Plan **grep xác nhận** không còn import trực tiếp trước khi bỏ |
| Test harness | `drift_setup.dart` → **no-op** (giữ nguyên chữ ký `setupSqliteForTests()` để mọi file test khỏi sửa) |
| `app/sqlite3.dll` | **Xoá** khỏi repo (native assets cấp SQLite cho cả test trên Windows) |
| CI | Bỏ bước `apt-get install -y libsqlite3-dev`; giữ `channel: stable` (đã ≥3.38, ubuntu có sẵn C compiler cho `native_toolchain_c`) |
| App code | **Không đổi** (drift classic API ổn định; test + APK đã chứng minh) |
| Manager warning | Không thêm `@ReferenceName` (lành, YAGNI) |

## 4. Thay đổi cụ thể

### 4.1 `app/pubspec.yaml`
- Bỏ dòng `sqlite3_flutter_libs: ^0.5.24`
- `drift: ^2.21.0` → `drift: ^2.34.0`
- `drift_dev: ^2.21.0` → `drift_dev: ^2.34.0`
- Bỏ dev `sqlite3: ^2.4.0` (sau khi grep xác nhận không còn import trực tiếp `package:sqlite3`)

### 4.2 `app/test/drift_setup.dart` — toàn bộ file:
```dart
/// Call once (setUpAll) in any test that opens a Drift NativeDatabase.
///
/// With sqlite3 3.x the native SQLite library is bundled via build hooks /
/// code assets, so tests no longer override the library path manually
/// (the old `package:sqlite3/open.dart` override API was removed in 3.0).
void setupSqliteForTests() {}
```

### 4.3 Xoá file `app/sqlite3.dll` (`git rm`)

### 4.4 `.github/workflows/ci.yml`
Bỏ 2 dòng trong job `app` (giữ nguyên `flutter pub get` / `build_runner` / `flutter analyze` / `flutter test`):
```yaml
      # NativeDatabase tests need the system sqlite3 on Linux.
      - run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev
```

### 4.5 Regenerate `database.g.dart`
Sau khi bump, chạy `dart run build_runner build` (file gitignored; local + CI đều regenerate). Không commit file này.

## 5. Verification gate
- `flutter analyze` → 0 lỗi
- `flutter test` → 96/96 (Windows, native assets auto)
- `flutter build apk --debug` → thành công
- **Chạy trên emulator Pixel_6**: mở app, thêm + xem 1 giao dịch, xác nhận DB mở + migration chạy ở runtime (spike mới *build*, chưa *run* — đây là cổng runtime cuối)
- Push → **CI xanh** (xác minh đường Linux: native assets + bỏ libsqlite3-dev)

## 6. Ngoài phạm vi / caveat
- Emulator = **x86_64**; arm64-v8a .so cũng ship (native_toolchain_c build mọi ABI Android) → chạy trên máy arm64 thật 1 lần là **optional, sau merge**.
- Không pin Flutter version trong CI (giữ `stable`).
- Không dọn manager warning (`@ReferenceName`).
- Không đụng `#11 riverpod 2→3`.

## 7. Gate cuối trước khi đóng issue
analyze 0 + test xanh + APK build + **emulator runtime OK** + CI xanh. Commit message gợi ý: `chore(deps): migrate to sqlite3 3.x via build hooks, drop sqlite3_flutter_libs (#12)`. Đóng #12 sau khi merge.
