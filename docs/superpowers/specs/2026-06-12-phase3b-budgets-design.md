# MoneyNote Phase 3b — Budgets — Design Spec

> Second sub-piece of Phase 3. Monthly budgets per category + an overall budget, with passive overspend warnings on the dashboard.
> Ngày: 2026-06-12 · Trạng thái: Approved qua brainstorming, chờ user review.
> Phase 3 đã decompose thành 4 sub-piece: 3a (transfer+search) ✅ merged, **3b** (đây), 3c (reports/charts), 3d (recurring/reminders) — mỗi cái spec→plan→build riêng.

## 1. Mục tiêu & phạm vi

**Mục tiêu:** Cho phép đặt **hạn mức chi theo tháng** cho từng danh mục và một hạn mức **tổng**, theo dõi chi thực tế vs hạn mức, **cảnh báo vượt** (passive) trên dashboard.

**Trong phạm vi 3b:** bảng Budget · đặt/sửa/xoá budget per-danh-mục + tổng · tính chi tháng theo danh mục · progress + cảnh báo vượt trên dashboard · màn quản lý budget.

**Ngoài phạm vi:** reports/charts (3c), recurring (3d), budget tuần/năm, lịch sử budget theo từng tháng, chặn chi khi vượt.

**Nguyên tắc giữ nguyên:** tiền int đồng; chỉ **expense** tính vào budget (loại income + transfer); offline; UI → providers → repository/domain.

## 2. Quyết định đã chốt

| Hạng mục | Quyết định |
|---|---|
| Mức budget | **Per danh mục + tổng** — `categoryId` nullable, `null` = ngân sách tổng (khớp spec gốc §5) |
| Mô hình | **Hạn mức tháng lặp lại** (đặt 1 lần, áp mọi tháng) — **bỏ `period` + `start_date`** (YAGNI; thêm khi cần weekly/yearly) |
| Uniqueness | **Upsert theo `categoryId`** ở repository (1 budget/danh mục, 1 budget tổng) — KHÔNG dùng unique constraint DB (NULL-uniqueness SQLite lằng nhằng) |
| Cảnh báo | **Passive** — progress đỏ + text khi vượt, **không chặn** chi tiêu |
| Vị trí | **Tích hợp dashboard** (section "Ngân sách" + màn quản lý mở từ đó) — không thêm tab |

## 3. Data model — bảng `Budget` (schema v3→v4)

```dart
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)(); // null = overall
  IntColumn get amount => integer()(); // monthly limit, đồng
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```
- Thêm `Budgets` vào `@DriftDatabase`, bump `schemaVersion` → **4**, migration `onUpgrade`: `if (from < 4) await m.createTable(budgets)` (giữ các bước v2/v3 cũ). `onCreate` đã `createAll()`.
- Sync-ready (UUID + updatedAt + soft-delete) như các entity khác.

## 4. Calculation — `spentInMonth` (thuần, thêm vào `domain/calculations.dart`)

```dart
/// Tổng EXPENSE trong tháng chứa [month]. categoryId null = mọi expense (budget tổng);
/// non-null = expense của danh mục đó. Loại income + transfer.
int spentInMonth(List<Transaction> txns, DateTime month, {String? categoryId}) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  var sum = 0;
  for (final t in txns) {
    if (t.occurredAt.isBefore(start) || !t.occurredAt.isBefore(end)) continue;
    if (t.type != TransactionType.expense) continue;
    if (categoryId != null && t.categoryId != categoryId) continue;
    sum += t.amount;
  }
  return sum;
}
```
UI tính `spent = spentInMonth(txns, month, categoryId: b.categoryId)`, `over = spent > b.amount`, `ratio = (spent / b.amount).clamp(0, 1)`.

## 5. UI (tích hợp dashboard)

- **Dashboard** (`dashboard_screen.dart`): thêm section **"Ngân sách"** dưới card thu/chi. Mỗi budget 1 dòng: tên danh mục (hoặc **"Tổng"** khi categoryId null) · `LinearProgressIndicator(value: ratio)` (đỏ khi `over`, ngược lại màu chủ đạo) · text `formatVnd(spent) / formatVnd(limit)` (đỏ + "⚠ vượt" khi over). Chỉ render khi có ≥1 budget. Section bấm được → mở `BudgetsScreen`.
- **`features/budgets/budgets_screen.dart`** (mở từ dashboard): Scaffold "Ngân sách"; list budget (kèm progress như trên); **FAB thêm** → dialog: dropdown chọn danh mục **+ mục "Tổng"** (categoryId null) + ô số tiền; **tap dòng để sửa** số tiền; **long-press để xoá** (soft-delete). Dùng `showAddBudget`/edit dialog.

## 6. Data flow

- `state/providers.dart`: `budgetsProvider = StreamProvider<List<Budget>>((ref) => ref.watch(repositoryProvider).watchBudgets())`.
- Dashboard watch `budgetsProvider` + `transactionsProvider` + `selectedMonthProvider` → tính progress.
- `repository.dart`:
  - `Stream<List<Budget>> watchBudgets()` (deletedAt null).
  - `Future<void> upsertBudget(String? categoryId, int amount)` — tìm budget hiện có theo categoryId (`isNull()` cho tổng, `equals()` cho danh mục); update nếu có (clear deletedAt), insert nếu chưa.
  - `Future<void> deleteBudget(String id)` (soft-delete).

## 7. Files

| File | Thay đổi |
|---|---|
| `lib/data/database.dart` | **Sửa** — bảng Budgets, schemaVersion 4 + migration |
| `lib/data/repository.dart` | **Sửa** — watchBudgets / upsertBudget / deleteBudget |
| `lib/domain/calculations.dart` | **Sửa** — `spentInMonth` |
| `lib/state/providers.dart` | **Sửa** — `budgetsProvider` |
| `lib/features/dashboard/dashboard_screen.dart` | **Sửa** — section Ngân sách + tap mở manage |
| `lib/features/budgets/budgets_screen.dart` | **Tạo** — quản lý budget |

## 8. Testing

- **Unit:** `spentInMonth` (per danh mục; tổng = mọi expense; loại income+transfer; biên tháng).
- **Repo:** `upsertBudget` (insert mới; update khi đã có; tổng qua categoryId null; không tạo trùng); `watchBudgets` (loại soft-deleted); `deleteBudget`.
- **Widget:** dashboard hiện section ngân sách với progress + trạng thái vượt (đỏ) khi spent > limit; `BudgetsScreen` thêm budget → xuất hiện.
- Full suite không hồi quy (migration v4 + calculations cũ).

## 9. Roadmap Phase 3 còn lại

3c Reports & charts · 3d Recurring & bill reminders — mỗi cái spec→plan→build riêng.
