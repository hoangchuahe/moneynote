# sqlite3 3.x Migration (#12) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bỏ package EOL `sqlite3_flutter_libs`, chuyển sang `sqlite3` 3.x (tự bundle SQLite native qua build hooks / code assets), bump `drift`→2.34 (#12).

**Architecture:** Đây là migration dependency + config, KHÔNG phải feature mới — không có test RED/GREEN mới. "Test" của plan này là: bộ 96 test sẵn có phải **vẫn xanh**, app phải **build APK** và **chạy được trên emulator**. Đã spike xác minh toàn bộ (nhánh nháp đã xoá); plan này tái áp dụng sạch trên nhánh `fix/12-sqlite3-3x-migration` rồi verify.

**Tech Stack:** Flutter 3.44 / Dart 3.12, drift 2.34, sqlite3 3.3.x (build hooks via `native_toolchain_c`).

**Spec:** [docs/superpowers/specs/2026-06-13-sqlite3-3x-migration-design.md](../specs/2026-06-13-sqlite3-3x-migration-design.md)

**Bối cảnh máy dev (Windows):** mọi lệnh `flutter`/`dart` chạy từ thư mục `app/`. Nếu `flutter test` treo không output → process mồ côi: `taskkill //F //IM flutter_tester.exe; taskkill //F //IM dart.exe` rồi chạy lại. Native assets tự cấp SQLite cho `flutter test` trên Windows (đã xác minh — không cần cờ, không cần DLL).

**Lưu ý nhánh:** đã ở `fix/12-sqlite3-3x-migration` (có sẵn commit spec). `database.g.dart` bị gitignored (CI regenerate) — KHÔNG commit nó.

---

### Task 1: Migrate dependencies + harness, bỏ DLL

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/test/drift_setup.dart`
- Delete: `app/sqlite3.dll`

- [ ] **Step 1: Xác nhận không còn import trực tiếp `package:sqlite3`**

Run (từ gốc repo): `git grep -n "package:sqlite3" -- app/lib app/test`
Expected: chỉ 1 dòng — `app/test/drift_setup.dart` (file sắp thành no-op). Nếu có file khác import trực tiếp → GIỮ `sqlite3` ở dev_dependencies và đổi thành `^3.0.0` thay vì bỏ (Step 2). Theo codebase hiện tại, chỉ `drift_setup.dart` import → an toàn bỏ hẳn.

- [ ] **Step 2: Sửa `app/pubspec.yaml`**

Trong `dependencies:`, đổi dòng `drift` và XOÁ dòng `sqlite3_flutter_libs`:
```yaml
  drift: ^2.34.0
```
(tức là thay block)
```yaml
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.24
```
bằng đúng 1 dòng `  drift: ^2.34.0`.

Trong `dev_dependencies:`, đổi `drift_dev` và XOÁ `sqlite3`:
```yaml
  drift_dev: ^2.34.0
```
(thay `  drift_dev: ^2.21.0`), và xoá hẳn dòng `  sqlite3: ^2.4.0`.

- [ ] **Step 3: Viết lại `app/test/drift_setup.dart`** — TOÀN BỘ file:

```dart
/// Call once (setUpAll) in any test that opens a Drift NativeDatabase.
///
/// With sqlite3 3.x the native SQLite library is bundled via build hooks /
/// code assets, so tests no longer override the library path manually
/// (the old `package:sqlite3/open.dart` override API was removed in 3.0).
void setupSqliteForTests() {}
```

- [ ] **Step 4: Resolve dependencies**

Run (từ `app/`): `flutter pub get`
Expected: `> drift 2.34.0`, `> sqlite3 3.3.3` (hoặc 3.3.x), `+ native_toolchain_c ...`, `These packages are no longer being depended on: - sqlite3_flutter_libs ...`, kết thúc `Got dependencies!`.

- [ ] **Step 5: Regenerate drift code**

Run (từ `app/`): `dart run build_runner build --delete-conflicting-outputs`
Expected: `Built with build_runner ...; wrote N outputs.` Có thể có warning lành về manager `transactionsRefs` (app không dùng `.managers`) và warning `--delete-conflicting-outputs ... ignored` — bỏ qua cả hai.

- [ ] **Step 6: Analyze**

Run (từ `app/`): `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Chạy full test suite**

Run (từ `app/`): `flutter test`
Expected: `All tests passed!` (96 test). Đây là cổng chính: harness no-op + native assets phải cho toàn bộ test DB chạy.

- [ ] **Step 8: Xoá DLL không còn cần**

Run (từ gốc repo): `git rm app/sqlite3.dll`
Expected: `rm 'app/sqlite3.dll'`. (Không file nào còn tham chiếu — `drift_setup.dart` đã no-op.)

- [ ] **Step 9: Build APK (xác minh Android cross-compile + đóng gói code asset)**

Run (từ `app/`): `flutter build apk --debug`
Expected: `√ Built build\app\outputs\flutter-apk\app-debug.apk`.

- [ ] **Step 10: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/test/drift_setup.dart
git commit -m "chore(deps): migrate to sqlite3 3.x via build hooks, drop sqlite3_flutter_libs (#12)"
```
(`git rm` ở Step 8 đã stage việc xoá `app/sqlite3.dll` — nó vào chung commit này. `database.g.dart` gitignored, không add.)

---

### Task 2: Bỏ bước cài libsqlite3-dev trong CI

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Sửa `.github/workflows/ci.yml`** — trong job `app`, XOÁ 2 dòng sau (comment + step):

```yaml
      # NativeDatabase tests need the system sqlite3 on Linux.
      - run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev
```

Giữ nguyên các step còn lại (`flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test`). `channel: stable` đã ≥3.38 nên native assets chạy; ubuntu-latest có sẵn C compiler cho `native_toolchain_c`.

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: drop libsqlite3-dev install (sqlite3 3.x bundles native via build hooks, #12)"
```

---

### Task 3: Verify runtime trên emulator Pixel_6

Đây là cổng runtime cuối (spike mới *build* APK, chưa *chạy*). Không sửa code — chỉ chạy & quan sát.

- [ ] **Step 1: Khởi động emulator**

Run (từ `app/`): `flutter emulators --launch Pixel_6`
Đợi tới khi máy ảo boot xong (màn hình Android hiện).

- [ ] **Step 2: Xác nhận emulator đã kết nối**

Run (từ `app/`): `flutter devices`
Expected: thấy 1 dòng kiểu `sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64`. Ghi lại id (vd `emulator-5554`).

- [ ] **Step 3: Cài + chạy app, quan sát DB mở được**

Run (từ `app/`): `flutter run -d emulator-5554`
Quan sát console: KHÔNG được có exception kiểu `SqliteException`, `Failed to load dynamic library`, `Couldn't open ... database`. App phải boot tới màn **Tổng quan** (Dashboard). Vì lần chạy đầu seed ví + danh mục mặc định vào DB, việc Dashboard render được = native SQLite đã nạp + DB mở + migration chạy.

- [ ] **Step 4: Kiểm chứng ghi/đọc (nếu drive được UI)**

Trong app trên emulator: bấm **Thêm**, nhập 1 khoản (vd 50.000), lưu → quay lại thấy giao dịch trong danh sách. Nếu không drive được UI tự động, riêng việc app boot tới Dashboard ở Step 3 đã đủ bằng chứng DB hoạt động.

Thoát: gõ `q` trong console `flutter run`.

- [ ] **Step 5: (Không commit)** Task này chỉ verify. Nếu phát hiện lỗi runtime → sửa trên nhánh rồi quay lại Task 1 verify lại.

---

## Hoàn tất

Sau Task 1–3, nhánh `fix/12-sqlite3-3x-migration` có: commit spec + commit migration + commit CI. Cổng cuối: `flutter analyze` 0 · `flutter test` 96/96 · `flutter build apk` OK · emulator runtime OK. Bước tiếp (ngoài plan): mở PR vào `master`, đợi **CI xanh** (xác minh đường Linux), merge, rồi `gh issue close 12`. Caveat arm64 (chạy máy thật 1 lần) là optional sau merge.
