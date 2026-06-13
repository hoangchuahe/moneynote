# MoneyNote — Giao dịch định kỳ (issue #8, phần recurring) — Design Spec

> Phase 3 (daily-use): **giao dịch định kỳ** — quy tắc lặp (template + chu kỳ + mốc) tự tạo giao dịch khi tới hạn. Offline, "code computes".
> Ngày: 2026-06-13 · Trạng thái: Approved qua brainstorming + hardened qua adversarial spec review (5 lens), chờ user review.
> Thứ tự user chốt: #6 export CSV ✅ (PR #26) → **#8a recurring (đây)** → #9 passcode.

## 1. Mục tiêu & phạm vi

**Mục tiêu:** Người dùng tạo **quy tắc định kỳ** (vd lương mùng 5 hàng tháng, Netflix ngày 1, tiền nhà…); khi mở app, kỳ tới hạn được **tự tạo thành giao dịch thật**.

**Trong phạm vi (8a):** bảng `Recurrings`; 4 chu kỳ preset Ngày/Tuần/Tháng/Năm (tháng & năm kẹp ngày); materialize lúc mở app (tạo **đúng kỳ mới nhất**, idempotent, best-effort); màn quản lý quy tắc trong Cài đặt (list + thêm/sửa/xoá).

**Ngoài phạm vi (hoãn — issue follow-up):** **8b Bill reminders / OS notifications** (user chốt hoãn hẳn, KHÔNG thêm dependency); catch-up tất cả kỳ bỏ lỡ; "mỗi N đơn vị"; recurring kiểu **transfer**; ngày kết thúc / giới hạn số lần; nút pause; snackbar báo sau khi tạo.

**Nguyên tắc giữ nguyên:** tiền `int` đồng VND > 0; transfer là loại riêng (loại khỏi recurring v1); "code computes"; offline 100%; `UI → providers → domain → data`; entity có UUID + updatedAt + soft-delete; **không thêm dependency**. **App nhắm VN (UTC+7, lệch giờ chẵn, không DST)** — nhưng logic ngày vẫn viết DST-safe (xem §4).

## 2. Quyết định đã chốt (qua brainstorming + spec review)

| Hạng mục | Quyết định |
|---|---|
| Phạm vi | **Chỉ recurring (8a)**; reminders/notifications (8b) hoãn hẳn, không thêm dep |
| Chu kỳ | Preset **Ngày / Tuần / Tháng / Năm**; monthly/yearly **kẹp ngày** (`min(ngày gốc, số ngày trong tháng)`) |
| Khi tới hạn | **Chỉ tạo kỳ mới nhất** ≤ hôm nay (1 giao dịch/rule/lần mở), bỏ qua kỳ giữa; idempotent qua `lastRunAt`; **best-effort** (lỗi không chặn mở app) |
| Mô hình ngày | **Anchor-based** (`startDate`+`cycle`+`lastRunAt`, tính occurrence thuần) — tránh trôi ngày; **weekly/daily tính bằng số ngày lịch UTC để DST-safe** |
| Loại | **Thu + Chi** (bỏ transfer ở v1) — `addRecurring` **chặn transfer** ngay khi tạo |
| Ngày giao dịch tạo ra | = **ngày đáo hạn gần nhất ≤ hôm nay** (không phải ngày mở app) |
| Báo khi tạo | **Im lặng** v1 |
| Sửa rule | **Đổi `startDate` hoặc `cycle` → reset `lastRunAt = null`** (coi như rule mới); đổi field khác (amount/note/category/wallet) giữ nguyên `lastRunAt` |
| Dừng một định kỳ | **Xoá mềm** rule; **xoá ví → cascade xoá mềm rule trỏ ví đó** (theo pattern `softDeleteWallet` hiện có) |
| Sort danh sách | `watchRecurrings` sort **`createdAt` DESC** (mới nhất trên đầu — list quản lý) |
| Lối vào | **Cài đặt → section "Tự động" → "Giao dịch định kỳ"** → `RecurringScreen` |

## 3. Schema — bảng `Recurrings` (mới)

`schemaVersion 5 → 6`. Thêm bảng vào `@DriftDatabase(tables: [...])`; migration `onUpgrade`: `if (from < 6) { await m.createTable(recurrings); await _ensureRecurringIndexes(); }`; `onCreate` gọi `_ensureRecurringIndexes()` sau `createAll()`. **`build_runner` regen `database.g.dart` TRƯỚC khi viết repo/test dùng `db.recurrings`/`RecurringsCompanion`** (theo CLAUDE.md).

```dart
enum RecurringCycle { daily, weekly, monthly, yearly }   // đặt cạnh TransactionType trong database.dart

class Recurrings extends Table {
  TextColumn get id => text()();
  IntColumn get amount => integer()();                          // đồng VND > 0
  IntColumn get type => intEnum<TransactionType>()();           // income | expense (không transfer)
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get cycle => intEnum<RecurringCycle>()();
  DateTimeColumn get startDate => dateTime()();                 // mốc/kỳ đầu (date-only)
  DateTimeColumn get lastRunAt => dateTime().nullable()();      // occurredAt của lần tạo gần nhất; null = chưa chạy
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

```dart
// Partial index trên rule còn sống, sắp theo createdAt (như watchRecurrings) và
// khớp filter `deleted_at IS NULL` mà materialize/watch dùng. Index thường trên
// deleted_at KHÔNG phục vụ được scan `IS NULL` trong SQLite.
Future<void> _ensureRecurringIndexes() => customStatement(
    'CREATE INDEX IF NOT EXISTS idx_recurrings_active '
    'ON recurrings (created_at) WHERE deleted_at IS NULL');
```

## 4. Domain thuần — `domain/recurring.dart` (tạo mới)

Logic ngày dễ sai nhất → tách thuần, test kỹ. **Mọi occurrence là date-only (local 00:00); weekly/daily stepping tính qua UTC để không bị DST lệch ±1 ngày** (hai mốc cách 7 ngày lịch qua mốc spring-forward chỉ cách 6d23h → `.inDays` local sẽ ra 6, sai).

```dart
/// Số ngày trong tháng (m: 1..12). daysInMonth(2024,2)=29.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Dựng ngày year-month-day, chuẩn hoá tràn tháng rồi KẸP ngày về cuối tháng
/// (vd clampedDate(2026, 2, 31) -> 2026-02-28). month có thể >12 hoặc ≤0 (tự dồn năm).
DateTime clampedDate(int year, int month, int day) {
  final norm = DateTime(year, month, 1);          // DateTime chuẩn hoá tháng tràn/âm -> năm
  final dim = daysInMonth(norm.year, norm.month);
  return DateTime(norm.year, norm.month, day <= dim ? day : dim);
}

/// Số ngày lịch giữa 2 date-only (DST-safe): chênh tính trên UTC.
int _calendarDaysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;

/// Cộng [days] ngày lịch vào date-only [d], trả về local date-only (DST-safe).
DateTime _addCalendarDays(DateTime d, int days) {
  final u = DateTime.utc(d.year, d.month, d.day).add(Duration(days: days));
  return DateTime(u.year, u.month, u.day);
}

/// Occurrence gần nhất ≤ [today] tính từ [start] theo [cycle] (date-only).
/// null nếu start (date) > today.
DateTime? mostRecentOccurrence(DateTime start, RecurringCycle cycle, DateTime today) {
  final s = DateTime(start.year, start.month, start.day);
  final t = DateTime(today.year, today.month, today.day);
  if (s.isAfter(t)) return null;
  switch (cycle) {
    case RecurringCycle.daily:
      return t; // mỗi ngày đều là occurrence; gần nhất ≤ today = today
    case RecurringCycle.weekly:
      final k = _calendarDaysBetween(s, t) ~/ 7;
      return _addCalendarDays(s, 7 * k);
    case RecurringCycle.monthly:
      var diff = (t.year - s.year) * 12 + (t.month - s.month);
      var occ = clampedDate(s.year, s.month + diff, s.day);
      if (occ.isAfter(t)) occ = clampedDate(s.year, s.month + (--diff), s.day);
      return occ;
    case RecurringCycle.yearly:
      var diff = t.year - s.year;
      var occ = clampedDate(s.year + diff, s.month, s.day);
      if (occ.isAfter(t)) occ = clampedDate(s.year + (--diff), s.month, s.day);
      return occ;
  }
}

/// Occurrence kế tiếp > [today] (để màn hình hiện "Kỳ tới").
DateTime nextOccurrenceAfter(DateTime start, RecurringCycle cycle, DateTime today) {
  final s = DateTime(start.year, start.month, start.day);
  final t = DateTime(today.year, today.month, today.day);
  if (s.isAfter(t)) return s;                       // chưa tới kỳ đầu
  switch (cycle) {
    case RecurringCycle.daily:
      return _addCalendarDays(t, 1);
    case RecurringCycle.weekly:
      final k = _calendarDaysBetween(s, t) ~/ 7;
      return _addCalendarDays(s, 7 * (k + 1));
    case RecurringCycle.monthly:
      var diff = (t.year - s.year) * 12 + (t.month - s.month);
      var occ = clampedDate(s.year, s.month + diff, s.day);
      while (!occ.isAfter(t)) occ = clampedDate(s.year, s.month + (++diff), s.day);
      return occ;
    case RecurringCycle.yearly:
      var diff = t.year - s.year;
      var occ = clampedDate(s.year + diff, s.month, s.day);
      while (!occ.isAfter(t)) occ = clampedDate(s.year + (++diff), s.month, s.day);
      return occ;
  }
}
```
**Vì sao idempotent đúng:** dãy occurrence theo thời gian **tăng chặt theo ngày đầy đủ (year-month-day)** vì mỗi kỳ neo vào tháng/năm sau (KHÔNG phải vì day-of-month không giảm — neo ngày 31 cho dãy day 31,28,31,30 không đơn điệu). So sánh `occ.isAfter(lastRun)` trên date-only do đó luôn đúng.

## 5. Materialize lúc mở app — repository

```dart
/// Tạo giao dịch cho kỳ mới nhất đã tới hạn của mỗi rule còn sống. Idempotent.
/// Trả số giao dịch đã tạo. [today] truyền vào để test xác định.
Future<int> materializeDueRecurrings(DateTime today) async {
  final rules = await (db.select(db.recurrings)..where((t) => t.deletedAt.isNull())).get();
  var created = 0;
  for (final r in rules) {
    final occ = mostRecentOccurrence(r.startDate, r.cycle, today);
    if (occ == null) continue;
    final lastRun = r.lastRunAt == null
        ? null
        : DateTime(r.lastRunAt!.year, r.lastRunAt!.month, r.lastRunAt!.day); // date-only
    if (lastRun != null && !occ.isAfter(lastRun)) continue;                  // đã tạo kỳ này
    await db.transaction(() async {                                          // atomic: insert + lastRunAt cùng commit
      await addTransaction(
        amount: r.amount, type: r.type, categoryId: r.categoryId,
        walletId: r.walletId, note: r.note, occurredAt: occ,
      );
      await (db.update(db.recurrings)..where((t) => t.id.equals(r.id))).write(
          RecurringsCompanion(lastRunAt: Value(occ), updatedAt: Value(DateTime.now())));
    });
    created++;
  }
  return created;
}
```
- **Atomic:** insert giao dịch + ghi `lastRunAt` trong **một `db.transaction`** (theo pattern `softDeleteWallet`) → không có cửa sổ crash tạo trùng.
- **Idempotent:** mở lại cùng kỳ → `occ == lastRun` → bỏ qua. Kỳ mới → tạo 1.
- **Chỉ kỳ mới nhất:** dùng `mostRecentOccurrence` (không lặp tạo từng kỳ bỏ lỡ).
- **Wiring (chốt 1 cách):** sửa **thân `_seedProvider` trong `main.dart`**: sau `await seedIfEmpty(db)`, dựng `final repo = AppRepository(ref.watch(databaseProvider));` rồi gọi **best-effort, không chặn mở app**:
  ```dart
  try { await repo.materializeDueRecurrings(DateTime.now()); } catch (_) { /* best-effort: bỏ qua, không chặn launch */ }
  ```
  **KHÔNG** thêm FutureProvider thứ hai; `_Root` giữ nguyên. Test gọi thẳng `repo.materializeDueRecurrings(fixedToday)` trên DB in-memory.

## 6. Repository + provider

`AppRepository` thêm:
- `Stream<List<Recurring>> watchRecurrings()` — loại soft-deleted, **sort `createdAt` DESC**.
- `Future<Recurring> addRecurring({amount, type, categoryId?, walletId, note, cycle, startDate})` — validate `amount > 0`; **`type == transfer` → `throw ArgumentError('type không được là transfer trong định kỳ v1')`** trước khi persist.
- `Future<void> updateRecurring(id, {...})` — **nếu `startDate` hoặc `cycle` đổi so với bản ghi cũ → set `lastRunAt = null`**; nếu chỉ đổi amount/note/categoryId/walletId → giữ `lastRunAt`. (Validate amount/transfer như add.)
- `Future<void> softDeleteRecurring(id)`.
- `materializeDueRecurrings(DateTime today)` (mục 5).
- **`softDeleteWallet` (sửa, mở rộng cascade hiện có):** trong cùng `db.transaction`, soft-delete thêm `Recurrings` có `walletId == id` (giống cascade transaction đã có). *(Category: KHÔNG cascade — giao dịch tạo ra trỏ category đã xoá mềm sẽ hiện "Chưa phân loại", nhất quán với hành vi hiện tại của app/CSV export.)*

`state/providers.dart` thêm `recurringsProvider = StreamProvider<List<Recurring>>(...)`.

## 7. UI

- **`settings_screen.dart` (sửa):** thêm `const Divider()` + `_SectionHeader('Tự động')` + `ListTile(key: Key('recurringRules'), leading: Icon(Icons.repeat), title: Text('Giao dịch định kỳ'))` ở **cuối** ListView → `Navigator.push(RecurringScreen)`. *(Section hiện có chỉ gồm: Giọng điệu AI / Giao diện / Phong cách / Máy chủ AI — KHÔNG có "Dữ liệu".)*
- **`features/recurring/recurring_screen.dart` (tạo):** `ConsumerWidget`, AppBar "Giao dịch định kỳ".
  - Watch `recurringsProvider` + `categoriesProvider` + `walletsProvider`.
  - List rule: leading icon màu theo type (`MoneyColors.income`/`expense`), title `formatVnd(amount)` + tên danh mục, subtitle nhãn chu kỳ + "Kỳ tới: `formatDmy(nextOccurrenceAfter(startDate, cycle, DateTime.now()))`". Chạm → form sửa.
  - **Xoá:** `Dismissible(key: Key('dismiss_<id>'), direction: endToStart, confirmDismiss: dialog xác nhận)` → `softDeleteRecurring`.
  - Empty state "Chưa có giao dịch định kỳ". FAB `+` → form thêm.
- **`features/recurring/recurring_edit_screen.dart` (tạo):** form thêm/sửa. **Xây mới theo phong cách `AddTransactionScreen`** — KHÔNG import widget từ `add_transaction_screen.dart` (các picker là private inline của file đó). **Chỉ tái dùng từ `lib/core`:** input-formatter nghìn + `parseVndInput` (amount), `formatDmy` (hiển thị ngày), `formatVnd` (preview).
  - Fields: amount; type **`SegmentedButton<TransactionType>`** (Thu/Chi); danh mục (lọc theo type); ví; ghi chú; **chu kỳ `SegmentedButton<RecurringCycle>` (`key: Key('cycleSegment')`, 4 nhãn: Hàng ngày/Hàng tuần/Hàng tháng/Hàng năm)**; ngày bắt đầu (date picker, default hôm nay). Lưu → `addRecurring`/`updateRecurring`.

## 8. Files

| File | Thay đổi |
|---|---|
| `lib/data/database.dart` | **Sửa** — `enum RecurringCycle`; bảng `Recurrings`; `@DriftDatabase tables`; `schemaVersion 6` + migration + `_ensureRecurringIndexes` |
| `lib/data/database.g.dart` | **Regen** (`build_runner` trước khi code repo/test) |
| `lib/domain/recurring.dart` | **Tạo** — `daysInMonth`, `clampedDate`, `_calendarDaysBetween`, `_addCalendarDays`, `mostRecentOccurrence`, `nextOccurrenceAfter` |
| `lib/data/repository.dart` | **Sửa** — watch/add/update/softDelete + `materializeDueRecurrings`; mở rộng cascade trong `softDeleteWallet` |
| `lib/state/providers.dart` | **Sửa** — `recurringsProvider` |
| `lib/main.dart` | **Sửa** — `_seedProvider`: materialize best-effort (try/catch) sau seed |
| `lib/features/settings/settings_screen.dart` | **Sửa** — section "Tự động" + ListTile "Giao dịch định kỳ" |
| `lib/features/recurring/recurring_screen.dart` | **Tạo** — list + empty + FAB + Dismissible xoá |
| `lib/features/recurring/recurring_edit_screen.dart` | **Tạo** — form thêm/sửa |
| `test/domain/recurring_test.dart` | **Tạo** — unit ngày |
| `test/data/recurring_repository_test.dart` | **Tạo** — add/validate/update/materialize/cascade |
| `test/widget/recurring_test.dart` | **Tạo** — Settings→màn, thêm/sửa/xoá, empty |

`pubspec.yaml`: **không đổi**.

## 9. Testing (TDD)

**Unit `domain/recurring_test.dart`:**
- `daysInMonth`: thường + Feb leap (2024→29, 2025→28).
- `clampedDate`: 31→cuối tháng (Feb28/30), tràn tháng dồn năm (month 13→năm sau), month âm sau `--diff`.
- `mostRecentOccurrence`: daily=today; **weekly stepping đúng dãy cách 7 ngày lịch** (nhiều tuần liên tiếp — chứng cho UTC-arith); monthly neo ngày 31 (Jan31→Feb28→Mar31; today=Feb15/Feb28/Mar1/Mar31/Apr30); yearly leap (start 2024-02-29; today 2025-02-28→occ 2025-02-28, today 2028-03-01→occ 2028-02-29); **start>today→null**; **start==today→today (daily & weekly)**.
- `nextOccurrenceAfter`: từng cycle; **chưa tới kỳ đầu (start>today→start)**; **yearly Feb-29 anchor (2024-02-29, today 2025-02-28 → 2026-02-28)**; **monthly clamp (start Jan31, today Feb28 → Mar31)**.
- **Dãy tăng chặt:** start ngày 31 monthly, sinh occurrence Jan→Feb→Mar→Apr, assert dãy ngày đầy đủ **strictly increasing** (chốt lập luận idempotency §4).

**Integration `data/recurring_repository_test.dart`** (in-memory DB, `today` cố định):
- `addRecurring`: lưu đúng; `amount<=0`→`throwsArgumentError`; **`type: transfer`→`throwsArgumentError`** (chặn lúc tạo).
- `materializeDueRecurrings`: tạo **đúng 1** giao dịch ở kỳ mới nhất; **occurredAt == `mostRecentOccurrence(start,cycle,today)`** (KHÔNG phải today); re-fetch rule assert **`lastRunAt == occurrence`** (không phải today); gọi lại cùng `today`→tạo **0** (idempotent); `today` qua kỳ sau→tạo thêm 1.
- **Bỏ qua kỳ giữa:** rule monthly `lastRunAt` 3 tháng trước → 1 lần materialize tạo **đúng 1** (occurredAt = kỳ mới nhất, không phải kỳ bỏ lỡ đầu); `watchAllTransactions` đúng 1 dòng mới.
- `startDate` tương lai → 0; rule **soft-deleted** → bỏ qua.
- `updateRecurring`: đổi `cycle`/`startDate` → `lastRunAt` về null; đổi amount → giữ `lastRunAt`.
- **Cascade:** `softDeleteWallet` → rule trỏ ví đó bị soft-delete; materialize sau đó bỏ qua nó.

**Widget `widget/recurring_test.dart`** (`await seedIfEmpty(db)` trước khi mount form — dropdown danh mục/ví cần FK seed; theo pattern `add_transaction_test.dart`/`budgets_test.dart`):
- Settings có "Giao dịch định kỳ" → push `RecurringScreen`.
- Empty state "Chưa có giao dịch định kỳ".
- Thêm rule qua form (chọn `cycleSegment` = Hàng tuần → nhãn "Hàng tuần" hiện) → hiện trong list với `formatVnd` + **"Kỳ tới: <dd/MM/yyyy cụ thể>"** tính từ startDate + today cố định.
- Sửa rule: mở form prefilled, đổi amount, lưu → list cập nhật.
- Xoá: swipe `Dismissible` → confirm dialog → item biến mất.
- Đọc Drift stream trong `testWidgets` theo pattern hiện có (timed pump / `runAsync`); `bigView`.

**Seam chưa test (chấp nhận v1):** wiring `materializeDueRecurrings(DateTime.now())` trong `main.dart` dùng `now()` cứng nên không test tự động được; logic đã phủ qua test gọi thẳng `materializeDueRecurrings(fixedToday)`.

`flutter analyze` 0 lỗi; full suite không hồi quy.

## 10. Sau khi xong

Đóng phần recurring của #8. Mở **issue follow-up "Bill reminders (flutter_local_notifications)"** cho 8b. Tiếp theo: **#9 passcode/biometric**.
