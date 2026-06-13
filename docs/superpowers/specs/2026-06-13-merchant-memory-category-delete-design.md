# MoneyNote — Merchant memory dọn theo category xoá mềm — Design Spec

> Bug fix #17: khi xoá mềm một category, soft-delete luôn các merchant mapping trỏ tới nó, để trạng thái nhất quán và hành vi đoán được.
> Ngày: 2026-06-13 · Trạng thái: Approved qua brainstorming, chờ user review · Issue: #17

## 1. Bối cảnh & vấn đề

`lookupMerchant()` ([repository.dart](../../../app/lib/data/repository.dart)) lọc cả `merchant_memories.deletedAt IS NULL` lẫn `categories.deletedAt IS NULL`, nên khi category đích bị xoá mềm thì lookup trả `null` — đúng về phía người dùng. **Nhưng** dòng mapping trong `merchant_memories` không ai đụng tới: `deletedAt` vẫn `null`, vẫn trỏ tới một category đã chết. Ba hệ quả:

1. **Trạng thái mâu thuẫn** — mapping "sống" trỏ category "chết"; việc "quên" merchant xảy ra *tình cờ* nhờ filter phía category, không phải có chủ đích.
2. **Code chết** — nhánh `deletedAt.isNull()` ở query merchant trong `lookupMerchant` hiện không bao giờ kích hoạt (chẳng có code nào set `deletedAt` cho merchant memory).
3. **Rủi ro sync/tương lai** — nếu category được khôi phục (qua sync, hoặc khi thêm `restoreCategory` về sau), mapping cũ "sống lại" im lặng → khó đoán.

## 2. Mục tiêu & phạm vi

**Mục tiêu:** Quyết một hành vi rõ ràng và nhất quán — **xoá mềm category ⇒ soft-delete luôn các merchant mapping trỏ tới nó**, trong cùng một `db.transaction` (mirror đúng pattern `softDeleteWallet`).

**Trong phạm vi:** sửa hàm `softDeleteCategory` + thêm test.

**Ngoài phạm vi (YAGNI):** `restoreCategory`; background sweeper dọn mapping mồ côi cũ; đổi `lookupMerchant` hay `upsertMerchant`; thay đổi schema/migration. Issue ghi rõ "edge case nhỏ, không crash, làm lúc rảnh".

**Nguyên tắc giữ nguyên:** soft-delete khắp nơi (sync-ready: UUID + `updatedAt` + `deletedAt`); UI → providers → repository; mirror pattern xoá mềm có liên đới của `softDeleteWallet`.

## 3. Quyết định đã chốt

| Hạng mục | Quyết định |
|---|---|
| Cơ chế | **Soft-delete** mapping (không hard-delete) — giữ triết lý sync-ready, khớp `softDeleteWallet`/`softDeleteTransaction` |
| Thời điểm dọn | **Lúc xoá category**, trong cùng `db.transaction` với việc xoá category — không xử lý lúc restore |
| Hành vi revive | Xoá category = **quên hẳn** merchant learning của nó; khôi phục category sau này **KHÔNG** làm sống lại mapping cũ (đoán được) |
| Re-learn | Vẫn chạy, **không cần đổi gì**: `upsertMerchant` tìm theo merchant key (unique index `uq_merchant_memories_merchant` toàn bảng) và **hồi sinh đúng dòng** — set `deletedAt = null`, gán category mới |

## 4. Thay đổi code

**File:** `app/lib/data/repository.dart` — chỉ sửa `softDeleteCategory` (hiện [dòng ~169](../../../app/lib/data/repository.dart#L169)), bọc `db.transaction`, mirror `softDeleteWallet`:

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

Không đổi schema, không migration, không đụng `lookupMerchant`/`upsertMerchant`.

## 5. Test (TDD — thêm vào `app/test/data/merchant_memory_test.dart`)

TDD nghiêm: viết test RED trước → chạy thấy fail → implement GREEN.

1. **(RED→GREEN chính) xoá category dọn mapping:** `addCategory(c)` → `upsertMerchant('highlands', c.id)` → `softDeleteCategory(c.id)`. Query trực tiếp `db.select(db.merchantMemories)..where((t) => t.merchant.equals('highlands'))`: dòng vẫn tồn tại và `deletedAt != null`. → Hôm nay FAIL (deletedAt vẫn null).
2. **Re-learn vẫn chạy:** sau bước 1, `upsertMerchant('highlands', c2.id)` (c2 là category mới, sống) → `lookupMerchant('highlands')` trả `c2`. Bảo vệ đường unique-index + revive (không tạo dòng trùng, không vi phạm unique).
3. **Nhiều merchant → 1 category:** map 2 merchant khác nhau vào cùng `c` → `softDeleteCategory(c)` → **cả 2** dòng đều `deletedAt != null`.

(Hành vi "lookupMerchant trả null sau khi xoá category" đã đúng hôm nay nhờ filter phía category — có thể thêm 1 assert nhỏ để khoá hành vi người dùng, nhưng không bắt buộc.)

## 6. Gate

`flutter analyze` 0 lỗi + toàn bộ `flutter test` xanh trước khi commit. Commit message: `fix(data): soft-delete merchant memories when category soft-deleted (#17)`.
