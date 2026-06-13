# Merchant memory dọn theo category xoá mềm — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khi xoá mềm một category, soft-delete luôn các merchant mapping trỏ tới nó (bug #17) — trạng thái nhất quán, hành vi đoán được.

**Architecture:** Sửa đúng 1 hàm `softDeleteCategory` trong repository: bọc `db.transaction`, ngoài việc set `deletedAt` cho category thì set luôn `deletedAt` cho mọi dòng `merchant_memories` có `categoryId == id` — mirror y hệt pattern `softDeleteWallet` (đang soft-delete transaction liên đới). Không đổi schema, không migration. Đường re-learn (`upsertMerchant`) không cần đụng: nó tìm theo `merchant` (unique index toàn bảng) và hồi sinh đúng dòng.

**Tech Stack:** Flutter/Dart, Drift (SQLite), test với `NativeDatabase.memory()`.

**Spec:** [docs/superpowers/specs/2026-06-13-merchant-memory-category-delete-design.md](../specs/2026-06-13-merchant-memory-category-delete-design.md)

**Bối cảnh máy dev (Windows):** chạy test từ thư mục `app/`. Nếu `flutter test` treo không output → process mồ côi: `taskkill //F //IM flutter_tester.exe; taskkill //F //IM dart.exe` rồi chạy lại. (Các test ở đây dùng future await trực tiếp — insert/get/update — KHÔNG đụng Drift stream nên không cần `tester.runAsync`.)

**Quy ước:** sau khi sửa code, `flutter analyze` phải 0 lỗi trước khi commit.

---

### Task 1: `softDeleteCategory` dọn merchant mapping liên đới

**Files:**
- Modify: `app/lib/data/repository.dart` (hàm `softDeleteCategory`, hiện ở dòng ~169–174)
- Test: `app/test/data/merchant_memory_test.dart` (thêm test vào cuối `main()`)

- [ ] **Step 1: Viết 2 test RED** — thêm vào cuối hàm `main()` của `app/test/data/merchant_memory_test.dart` (trước dấu `}` đóng `main`):

```dart
  test('softDeleteCategory soft-deletes the merchant memory pointing to it',
      () async {
    final c = await repo.addCategory(name: 'Cà phê', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c.id);

    await repo.softDeleteCategory(c.id);

    final mem = await (db.select(db.merchantMemories)
          ..where((t) => t.merchant.equals('highlands')))
        .getSingle();
    expect(mem.deletedAt, isNotNull);
  });

  test('softDeleteCategory soft-deletes ALL merchant memories for that category',
      () async {
    final c = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c.id);
    await repo.upsertMerchant('phúc long', c.id);

    await repo.softDeleteCategory(c.id);

    final rows = await (db.select(db.merchantMemories)
          ..where((t) => t.categoryId.equals(c.id)))
        .get();
    expect(rows, hasLength(2));
    expect(rows.every((m) => m.deletedAt != null), isTrue);
  });
```

- [ ] **Step 2: Chạy để thấy fail**

Run (từ `app/`): `flutter test test/data/merchant_memory_test.dart`
Expected: **2 test mới FAIL** — `mem.deletedAt` là `null` (hàm hiện tại chỉ xoá mềm category, không đụng `merchant_memories`). Các test cũ vẫn PASS. (Test biên dịch được vì `softDeleteCategory` đã tồn tại.)

- [ ] **Step 3: Implement** — thay TOÀN BỘ hàm `softDeleteCategory` trong `app/lib/data/repository.dart` bằng:

```dart
  Future<void> softDeleteCategory(String id) async {
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (db.update(db.merchantMemories)
            ..where((t) => t.categoryId.equals(id)))
          .write(
        MerchantMemoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }
```

(Không cần thêm import: `Value`, `db.transaction`, `MerchantMemoriesCompanion` đều đã có sẵn trong file/scope hiện tại.)

- [ ] **Step 4: Chạy để thấy pass**

Run (từ `app/`): `flutter test test/data/merchant_memory_test.dart`
Expected: **toàn bộ PASS** (gồm 2 test mới).

- [ ] **Step 5: Thêm test guard cho đường re-learn** — thêm tiếp vào cuối `main()`:

```dart
  test('re-learning a merchant after its category was deleted still works',
      () async {
    final c1 = await repo.addCategory(name: 'Cà phê', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c1.id);
    await repo.softDeleteCategory(c1.id);

    final c2 = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c2.id);

    final got = await repo.lookupMerchant('highlands');
    expect(got, isNotNull);
    expect(got!.id, c2.id);
  });
```

- [ ] **Step 6: Chạy lại cả file**

Run (từ `app/`): `flutter test test/data/merchant_memory_test.dart`
Expected: **toàn bộ PASS**. Test guard này PASS cả trước lẫn sau khi sửa — nó khoá đảm bảo rằng việc soft-delete mapping KHÔNG phá đường hồi sinh: `upsertMerchant` tìm theo `merchant` (unique index toàn bảng), un-delete đúng dòng và gán category mới, không tạo dòng trùng.

- [ ] **Step 7: Gate — analyze + full suite**

Run (từ `app/`): `flutter analyze`
Expected: **No issues found** (0 lỗi).

Run (từ `app/`): `flutter test`
Expected: toàn bộ test của app PASS (không regress).

- [ ] **Step 8: Commit**

```bash
git add app/lib/data/repository.dart app/test/data/merchant_memory_test.dart
git commit -m "fix(data): soft-delete merchant memories when category soft-deleted (#17)"
```

---

## Hoàn tất

Sau Task 1, bug #17 đã sửa xong. Nhánh `fix/17-merchant-memory-soft-delete` chứa: commit spec + commit fix. Bước tiếp theo (ngoài plan này): mở PR vào `master`, và khi merged thì `gh issue close 17`.
