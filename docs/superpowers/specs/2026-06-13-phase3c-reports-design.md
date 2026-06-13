# MoneyNote Phase 3c — Reports & Charts — Design Spec

> Third sub-piece of Phase 3. Màn **Báo cáo**: pie chi theo danh mục + cột Thu/Chi theo tháng, vào từ Dashboard.
> Ngày: 2026-06-13 · Trạng thái: Approved qua brainstorming, chờ user review.
> Phase 3 decompose: 3a (transfer+search) ✅ · 3b (budgets) ✅ · **3c (đây)** · 3d (recurring/reminders) — mỗi cái spec→plan→build riêng.

## 1. Mục tiêu & phạm vi

**Mục tiêu:** Màn **Báo cáo** trực quan hoá chi tiêu: **pie chi theo danh mục** (tháng đang chọn) + **biểu đồ cột Thu vs Chi 6 tháng gần nhất**. Kế thừa design token từ UI redesign; charts dùng `fl_chart`.

**Trong phạm vi 3c:** lối vào từ Dashboard · `ReportsScreen` · pie expense-by-category theo tháng · cột nhóm Thu/Chi 6 tháng · hàm tổng hợp thuần (domain) · empty states · loại transfer khỏi mọi báo cáo.

**Ngoài phạm vi:** drill-down khi chạm slice pie · pie cho income · khoảng thời gian tuỳ chọn · xem theo năm · export biểu đồ · recurring (3d) · **đẩy aggregation xuống SQL (#16)** — xem §2/§4.

**Nguyên tắc giữ nguyên:** tiền là int đồng; **loại transfer** khỏi báo cáo (bài học Money Lover, master spec mục Transaction); "code computes, chart displays"; offline 100%; UI → providers → domain.

## 2. Quyết định đã chốt

| Hạng mục | Quyết định |
|---|---|
| Lối vào | **Từ Dashboard** — icon `bar_chart` ở AppBar, **chỉ hiện ở tab Tổng quan** → push `ReportsScreen`. KHÔNG thêm tab thứ 5 (giữ 4 tab) |
| Pie | **Chi theo danh mục**, tháng đang chọn (`selectedMonthProvider`); slice theo `category.color`; có khe giữa slice (`sectionsSpace`) |
| Trend | **Thu vs Chi** — cột nhóm 2 series/tháng, **6 tháng** gần nhất tính tới tháng đang chọn; **bo đỉnh cột** |
| Tổng hợp | **Hàm thuần trong `domain/reports.dart`** trên `transactionsProvider` hiện có (giống `summarize`/`spentInMonth`) — KHÔNG đụng repository/SQL |
| #16 (SQL pushdown) | **Tách riêng.** Là refactor cross-cutting (mọi màn load full list rồi tính client-side); làm lẻ cho reports sẽ phá nhất quán mà không thực sự giải quyết #16. Reports đi theo pattern thuần hiện tại |
| Card radius | **Giữ token brand 16** cho nhất quán toàn app; phần "bo tròn" nằm ở **chart** (bar bo đỉnh, pie có khe, chip/pill bo). Muốn mềm hơn nữa → bump token 16→18 **toàn cục** (1 dòng `theme.dart`) — flag, KHÔNG làm trong 3c |
| fl_chart | Thêm dependency (master spec mục Stack đã định P3) |

## 3. Lối vào & màn hình

- **`home_shell.dart`** (sửa): AppBar `actions` thêm `IconButton(Icons.bar_chart)` **chỉ khi `_index == 0`** (tab Tổng quan), đứng trước nút Settings → `Navigator.push(ReportsScreen)`.
- **`features/reports/reports_screen.dart`** (tạo) — `ConsumerWidget`:
  - **Header tháng:** ‹ `Tháng M/YYYY` › dùng `selectedMonthProvider` (đồng bộ với Dashboard — đổi tháng ở đâu cũng phản chiếu).
  - **Card 1 — ExpensePieCard:** pie chi theo danh mục + legend (chip màu danh mục · tên · `formatVnd` · %). Empty (tháng không có chi) → `EmptyState("Chưa có chi tiêu tháng này")`.
  - **Card 2 — MonthlyFlowCard:** cột nhóm Thu (income) / Chi (expense) 6 tháng + legend Thu/Chi + nhãn trục X. Empty (cả 6 tháng = 0) → `EmptyState`.
  - Tách 2 card thành widget riêng dưới `features/reports/widgets/` cho gọn + dễ test.

## 4. Tổng hợp — `domain/reports.dart` (thuần, tạo mới)

```dart
class CategorySpend {
  final String? categoryId; // null = chưa phân loại
  final int total;          // đồng VND
  const CategorySpend(this.categoryId, this.total);
}

class MonthlyFlow {
  final DateTime month;     // mốc đầu tháng
  final int income;
  final int expense;
  const MonthlyFlow(this.month, this.income, this.expense);
}

/// Expense theo danh mục trong tháng chứa [month], sắp xếp giảm dần theo total.
/// Loại income + transfer; soft-deleted đã loại sẵn bởi provider.
/// Expense có categoryId null gom vào một bucket "Chưa phân loại" (categoryId == null).
List<CategorySpend> expenseByCategory(List<Transaction> txns, DateTime month) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final byCat = <String?, int>{};
  for (final t in txns) {
    if (t.type != TransactionType.expense) continue;
    if (t.occurredAt.isBefore(start) || !t.occurredAt.isBefore(end)) continue;
    byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
  }
  final list = byCat.entries.map((e) => CategorySpend(e.key, e.value)).toList();
  list.sort((a, b) => b.total.compareTo(a.total));
  return list;
}

/// Thu/chi từng tháng cho [months] tháng gần nhất tính tới [endMonth] (gồm endMonth).
/// Loại transfer. Tháng không có giao dịch → income = expense = 0 (vẫn xuất hiện trong list).
List<MonthlyFlow> monthlyFlow(List<Transaction> txns, DateTime endMonth,
    {int months = 6}) {
  final result = <MonthlyFlow>[];
  for (var i = months - 1; i >= 0; i--) {
    final m = DateTime(endMonth.year, endMonth.month - i, 1); // tự chuẩn hoá biên năm
    final s = summarize(txns, m); // reuse calculations.dart: transfer đã loại
    result.add(MonthlyFlow(m, s.income, s.expense));
  }
  return result;
}
```

**Vì sao thuần + dùng `transactionsProvider`:** khớp pattern hiện tại (`summarize`, `spentInMonth` cùng file `calculations.dart`), test bằng `List<Transaction>` không cần DB, nhất quán toàn app. Đặt ở file `reports.dart` riêng (không nhồi `calculations.dart`) để gom logic báo cáo một chỗ. (#16 đẩy SQL là việc riêng, cross-cutting — xem §2.)

## 5. UI chi tiết & charts (fl_chart)

- **Pie (ExpensePieCard):** `PieChart` — mỗi section `value = total`, `color = category.color` (join `categoriesProvider`; expense categoryId null → xám trung tính `0xFF9E9E9E`, default của Categories), `sectionsSpace: 3`, `centerSpaceRadius` (kiểu donut); tâm hiện `Tổng` + `formatVnd(tổng chi)`. Legend cạnh bên: chip bo góc màu danh mục · tên (hoặc **"Chưa phân loại"**) · `formatVnd` · % (làm tròn).
- **Trend (MonthlyFlowCard):** `BarChart` — mỗi tháng một `BarChartGroupData` 2 rod (income, expense), `borderRadius: BorderRadius.vertical(top: Radius.circular(4))` (bo đỉnh) · income = `MoneyColors.income`, expense = `MoneyColors.expense` · `FlGridData` ngang mờ · nhãn trục X = `T{tháng}` (số tháng dương lịch — vd T1..T6; cửa sổ vắt năm → T11, T12, T1...) · ẩn số trục Y (gridline đủ đọc).
- Toàn bộ màu/typography lấy từ `Theme` + `MoneyColors` + `category.color`. Số tiền luôn qua `formatVnd` + tabular figures. Card dùng `CardTheme` mặc định (radius 16 brand).

## 6. Data flow

- `ReportsScreen` watch `transactionsProvider` + `categoriesProvider` + `selectedMonthProvider`.
- `txns` → `expenseByCategory(txns, month)` (pie) + `monthlyFlow(txns, month, months: 6)` (trend); join `categoriesProvider` để lấy tên/màu (giống `catById` ở dashboard).
- **Không thêm provider hay repository mới** — reuse `transactionsProvider` + `categoriesProvider` đã có.

## 7. Files

| File | Thay đổi |
|---|---|
| `pubspec.yaml` | **Sửa** — thêm `fl_chart` (latest stable; pin version ở plan) |
| `lib/domain/reports.dart` | **Tạo** — `CategorySpend`, `MonthlyFlow`, `expenseByCategory`, `monthlyFlow` |
| `lib/features/reports/reports_screen.dart` | **Tạo** — màn + header tháng |
| `lib/features/reports/widgets/expense_pie_card.dart` | **Tạo** — pie + legend + empty |
| `lib/features/reports/widgets/monthly_flow_card.dart` | **Tạo** — cột Thu/Chi + empty |
| `lib/features/home/home_shell.dart` | **Sửa** — icon `bar_chart` (chỉ tab Tổng quan) → push Reports |
| `test/domain/reports_test.dart` | **Tạo** — unit |
| `test/widget/reports_test.dart` | **Tạo** — widget |

## 8. Testing (TDD)

- **Unit (thuần, không DB):** `expenseByCategory` — group + sort giảm dần; loại income/transfer; bucket `null`; biên tháng; empty. `monthlyFlow` — income/expense từng tháng; cửa sổ đúng 6 tháng tính tới endMonth; loại transfer; tháng rỗng = 0; biên năm (tháng 1 lùi sang năm trước).
- **Widget:** `ReportsScreen` render legend với `formatVnd` + tên danh mục + tiêu đề 2 card; **empty states** khi tháng không chi; icon `bar_chart` ở Dashboard điều hướng sang `ReportsScreen`. fl_chart vẽ canvas → assert widget bao quanh (legend/title/empty), **không** pixel-test chart. Đọc Drift stream trong `testWidgets` phải bọc `tester.runAsync` (theo pattern các widget test hiện có).
- Full suite không hồi quy.

## 9. Roadmap Phase 3 còn lại

3d Recurring & bill reminders — spec→plan→build riêng. (#16 SQL aggregation pushdown: backlog, cross-cutting — không thuộc 3c.)
