# Phase 3c — Reports & Charts — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a **Báo cáo** screen — expense-by-category pie + Thu/Chi 6-month bar trend (fl_chart) — reachable from the Dashboard.

**Architecture:** Pure aggregation functions in `domain/reports.dart` over the existing `transactionsProvider` stream (mirrors `summarize`/`spentInMonth`). Two **data-driven** chart widgets (`ExpensePieCard`, `MonthlyFlowCard`) take plain props so they test without a DB; `ReportsScreen` wires providers → domain → cards. No new providers, no repository/SQL changes. (#16 SQL pushdown stays a separate cross-cutting task.)

**Tech Stack:** Flutter/Dart, Riverpod, Drift (SQLite), **fl_chart** (new), `NativeDatabase.memory()` for widget tests.

**Spec:** [docs/superpowers/specs/2026-06-13-phase3c-reports-design.md](../specs/2026-06-13-phase3c-reports-design.md)

**Bối cảnh máy dev (Windows):** chạy mọi lệnh từ thư mục `app/`. Nếu `flutter test` treo không output → process mồ côi: `taskkill //F //IM flutter_tester.exe; taskkill //F //IM dart.exe` rồi chạy lại. Không cần `build_runner` (không đổi schema Drift). Đọc Drift **stream** (`watchX().first`) trong `testWidgets` phải bọc `tester.runAsync`; các test ở đây dùng one-shot `.get()` + `addTransaction` (await trực tiếp) nên KHÔNG cần.

**Quy ước:** `flutter analyze` 0 lỗi trước mỗi commit; test RED trước, GREEN tối thiểu, commit gộp test+impl.

**Lưu ý fl_chart:** code dưới nhắm API fl_chart ~0.69/0.70. Sau Task 1, xem version `pub add` resolve về; nếu khác, đối chiếu nhanh tên thuộc tính (`PieChartSectionData`, `BarChartRodData.borderRadius`, `FlTitlesData`/`SideTitles.getTitlesWidget`) và chỉnh cho khớp — logic không đổi.

---

### Task 1: Thêm dependency fl_chart

**Files:**
- Modify: `app/pubspec.yaml` (mục `dependencies`)

- [ ] **Step 1: Add the package**

Run (từ `app/`): `flutter pub add fl_chart`
Expected: thêm dòng `fl_chart: ^<version>` vào `dependencies` trong `pubspec.yaml`, tự chạy `flutter pub get` thành công (cập nhật `pubspec.lock`).

- [ ] **Step 2: Verify resolve sạch**

Run (từ `app/`): `flutter pub get`
Expected: `Got dependencies!` không lỗi version conflict.

- [ ] **Step 3: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "chore(deps): add fl_chart for reports charts (#7)"
```

---

### Task 2: Domain — `expenseByCategory`

**Files:**
- Create: `app/lib/domain/reports.dart`
- Test: `app/test/domain/reports_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `app/test/domain/reports_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/reports.dart';

Transaction etx(int amount, String? categoryId, DateTime when,
        {TransactionType type = TransactionType.expense}) =>
    Transaction(
      id: '$amount-$categoryId-$when-${type.name}',
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: 'w1',
      toWalletId: null,
      note: '',
      occurredAt: when,
      createdAt: when,
      updatedAt: when,
    );

void main() {
  group('expenseByCategory', () {
    test('groups expense by category, sorted desc, excludes income+transfer', () {
      final txns = [
        etx(50000, 'food', DateTime(2026, 6, 5)),
        etx(30000, 'food', DateTime(2026, 6, 6)),
        etx(90000, 'move', DateTime(2026, 6, 7)),
        etx(5000000, 'salary', DateTime(2026, 6, 8), type: TransactionType.income),
        etx(1000000, null, DateTime(2026, 6, 9), type: TransactionType.transfer),
      ];
      final r = expenseByCategory(txns, DateTime(2026, 6, 1));
      expect(r.map((e) => e.categoryId).toList(), ['move', 'food']);
      expect(r.first.total, 90000);
      expect(r[1].total, 80000);
    });

    test('expense without category goes to a null bucket', () {
      final r = expenseByCategory(
          [etx(40000, null, DateTime(2026, 6, 5))], DateTime(2026, 6, 1));
      expect(r.single.categoryId, isNull);
      expect(r.single.total, 40000);
    });

    test('respects month boundaries', () {
      final txns = [
        etx(11111, 'food', DateTime(2026, 5, 31)),
        etx(22222, 'food', DateTime(2026, 6, 1)),
        etx(33333, 'food', DateTime(2026, 7, 1)),
      ];
      expect(expenseByCategory(txns, DateTime(2026, 6, 1)).single.total, 22222);
    });

    test('empty when no expense in month', () {
      expect(expenseByCategory([], DateTime(2026, 6, 1)), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run (từ `app/`): `flutter test test/domain/reports_test.dart`
Expected: FAIL biên dịch — `reports.dart` / `expenseByCategory` / `CategorySpend` chưa tồn tại.

- [ ] **Step 3: Implement**

Create `app/lib/domain/reports.dart`:

```dart
import 'package:moneynote/data/database.dart';

/// Tổng expense của một danh mục trong một tháng. categoryId null = chưa phân loại.
class CategorySpend {
  final String? categoryId;
  final int total; // đồng VND
  const CategorySpend(this.categoryId, this.total);
}

/// Expense theo danh mục trong tháng chứa [month], sắp xếp giảm dần theo total.
/// Loại income + transfer; soft-deleted đã loại sẵn bởi provider.
/// Expense categoryId null gom vào một bucket (categoryId == null).
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
```

- [ ] **Step 4: Run to verify it passes**

Run (từ `app/`): `flutter test test/domain/reports_test.dart`
Expected: PASS (4 test của group `expenseByCategory`).

- [ ] **Step 5: Commit**

```bash
git add app/lib/domain/reports.dart app/test/domain/reports_test.dart
git commit -m "feat(domain): expenseByCategory aggregation for reports (#7)"
```

---

### Task 3: Domain — `monthlyFlow`

**Files:**
- Modify: `app/lib/domain/reports.dart`
- Test: `app/test/domain/reports_test.dart` (thêm group)

- [ ] **Step 1: Write the failing tests**

Thêm group này vào cuối `main()` trong `app/test/domain/reports_test.dart` (sau group `expenseByCategory`, trước dấu `}` đóng `main`). Helper `etx` đã có sẵn ở đầu file.

```dart
  group('monthlyFlow', () {
    test('returns N months ending at endMonth, oldest first', () {
      final r = monthlyFlow([], DateTime(2026, 6, 1), months: 6);
      expect(r.length, 6);
      expect(r.first.month, DateTime(2026, 1, 1));
      expect(r.last.month, DateTime(2026, 6, 1));
    });

    test('income and expense per month, transfers excluded', () {
      final txns = [
        etx(5000000, 'salary', DateTime(2026, 6, 5), type: TransactionType.income),
        etx(200000, 'food', DateTime(2026, 6, 6)),
        etx(1000000, null, DateTime(2026, 6, 7), type: TransactionType.transfer),
        etx(300000, 'food', DateTime(2026, 5, 6)),
      ];
      final r = monthlyFlow(txns, DateTime(2026, 6, 1), months: 6);
      final june = r.firstWhere((f) => f.month == DateTime(2026, 6, 1));
      final may = r.firstWhere((f) => f.month == DateTime(2026, 5, 1));
      expect(june.income, 5000000);
      expect(june.expense, 200000); // transfer loại
      expect(may.expense, 300000);
    });

    test('empty months are zero and window crosses the year boundary', () {
      final r = monthlyFlow([], DateTime(2026, 1, 1), months: 3);
      expect(r.map((f) => f.month).toList(),
          [DateTime(2025, 11, 1), DateTime(2025, 12, 1), DateTime(2026, 1, 1)]);
      expect(r.every((f) => f.income == 0 && f.expense == 0), isTrue);
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run (từ `app/`): `flutter test test/domain/reports_test.dart`
Expected: FAIL biên dịch — `monthlyFlow` / `MonthlyFlow` chưa tồn tại. (Group `expenseByCategory` không chạy được vì file không compile.)

- [ ] **Step 3: Implement**

Thêm vào `app/lib/domain/reports.dart`: (a) import `calculations.dart` ở đầu file, (b) class `MonthlyFlow` + hàm `monthlyFlow` ở cuối file.

Đầu file, ngay dưới import hiện có:

```dart
import 'package:moneynote/domain/calculations.dart';
```

Cuối file:

```dart
/// Thu/chi của một tháng (mốc đầu tháng).
class MonthlyFlow {
  final DateTime month;
  final int income;
  final int expense;
  const MonthlyFlow(this.month, this.income, this.expense);
}

/// Thu/chi từng tháng cho [months] tháng gần nhất tính tới [endMonth] (gồm endMonth),
/// cũ → mới. Loại transfer (qua summarize). Tháng rỗng → income = expense = 0.
List<MonthlyFlow> monthlyFlow(List<Transaction> txns, DateTime endMonth,
    {int months = 6}) {
  final result = <MonthlyFlow>[];
  for (var i = months - 1; i >= 0; i--) {
    final m = DateTime(endMonth.year, endMonth.month - i, 1); // tự chuẩn hoá biên năm
    final s = summarize(txns, m);
    result.add(MonthlyFlow(m, s.income, s.expense));
  }
  return result;
}
```

- [ ] **Step 4: Run to verify it passes**

Run (từ `app/`): `flutter test test/domain/reports_test.dart`
Expected: PASS toàn bộ (cả `expenseByCategory` + `monthlyFlow`).

- [ ] **Step 5: Commit**

```bash
git add app/lib/domain/reports.dart app/test/domain/reports_test.dart
git commit -m "feat(domain): monthlyFlow income/expense aggregation (#7)"
```

---

### Task 4: Widget — `ExpensePieCard` (data-driven)

**Files:**
- Create: `app/lib/features/reports/widgets/expense_pie_card.dart`
- Test: `app/test/widget/reports_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `app/test/widget/reports_test.dart` (import tối thiểu cho Task 4; Task 5–7 sẽ bổ sung import + group dần, mỗi task tự compile & PASS):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/features/reports/widgets/expense_pie_card.dart';

Widget host(Widget child) => MaterialApp(
      theme: buildTheme(AppThemeStyle.classic, Brightness.light),
      home: Scaffold(body: child),
    );

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('ExpensePieCard', () {
    testWidgets('renders legend with names, amounts and percents', (tester) async {
      bigView(tester);
      await tester.pumpWidget(host(const ExpensePieCard(slices: [
        CategorySlice(label: 'Ăn uống', color: Color(0xFFEF5350), total: 600000),
        CategorySlice(label: 'Đi lại', color: Color(0xFF42A5F5), total: 400000),
      ])));
      await tester.pump();

      expect(find.text('Chi theo danh mục'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('600.000 ₫'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('1.000.000 ₫'), findsOneWidget); // tổng cạnh tiêu đề
    });

    testWidgets('shows empty state when no slices', (tester) async {
      bigView(tester);
      await tester.pumpWidget(host(const ExpensePieCard(slices: [])));
      await tester.pump();
      expect(find.text('Chưa có chi tiêu tháng này'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run (từ `app/`): `flutter test test/widget/reports_test.dart`
Expected: FAIL biên dịch — `ExpensePieCard` / `CategorySlice` chưa tồn tại.

- [ ] **Step 3: Implement**

Create `app/lib/features/reports/widgets/expense_pie_card.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/widgets/empty_state.dart';

/// View-model một lát pie: nhãn + màu + tổng (đã resolve khỏi Drift Category).
class CategorySlice {
  final String label;
  final Color color;
  final int total;
  const CategorySlice(
      {required this.label, required this.color, required this.total});
}

class ExpensePieCard extends StatelessWidget {
  final List<CategorySlice> slices;
  const ExpensePieCard({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.pie_chart_outline,
            title: 'Chưa có chi tiêu tháng này',
            hint: 'Thêm giao dịch chi để xem cơ cấu danh mục',
          ),
        ),
      );
    }
    final total = slices.fold<int>(0, (s, e) => s + e.total);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Chi theo danh mục',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                Text(formatVnd(total),
                    style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 34,
                    sections: [
                      for (final s in slices)
                        PieChartSectionData(
                          value: s.total.toDouble(),
                          color: s.color,
                          radius: 18,
                          showTitle: false,
                        ),
                    ],
                  )),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final s in slices)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(s.label,
                                      style: const TextStyle(fontSize: 12))),
                              Text(formatVnd(s.total),
                                  style:
                                      TextStyle(fontSize: 11, color: muted)),
                              const SizedBox(width: 8),
                              Text('${(s.total / total * 100).round()}%',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run (từ `app/`): `flutter test test/widget/reports_test.dart`
Expected: PASS — 2 test của group `ExpensePieCard` (lúc này file test chỉ import + test pie nên compile độc lập).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reports/widgets/expense_pie_card.dart app/test/widget/reports_test.dart
git commit -m "feat(reports): ExpensePieCard widget (#7)"
```

---

### Task 5: Widget — `MonthlyFlowCard` (data-driven)

**Files:**
- Create: `app/lib/features/reports/widgets/monthly_flow_card.dart`
- Test: `app/test/widget/reports_test.dart` (thêm group)

- [ ] **Step 1: Write the failing tests**

Thêm 2 import vào đầu `app/test/widget/reports_test.dart`:

```dart
import 'package:moneynote/domain/reports.dart';
import 'package:moneynote/features/reports/widgets/monthly_flow_card.dart';
```

Rồi thêm group này vào `main()` (sau group `ExpensePieCard`):

```dart
  group('MonthlyFlowCard', () {
    testWidgets('renders Thu/Chi legend and month labels', (tester) async {
      bigView(tester);
      final flows = [
        for (var m = 1; m <= 6; m++)
          MonthlyFlow(DateTime(2026, m, 1), 1000000 * m, 500000 * m),
      ];
      await tester.pumpWidget(host(MonthlyFlowCard(flows: flows)));
      await tester.pump();

      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Chi'), findsOneWidget);
      expect(find.text('T1'), findsOneWidget);
      expect(find.text('T6'), findsOneWidget);
    });

    testWidgets('shows empty state when all months are zero', (tester) async {
      bigView(tester);
      final flows = [
        for (var m = 1; m <= 6; m++) MonthlyFlow(DateTime(2026, m, 1), 0, 0),
      ];
      await tester.pumpWidget(host(MonthlyFlowCard(flows: flows)));
      await tester.pump();
      expect(find.text('Chưa có thu chi nào'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run (từ `app/`): `flutter test test/widget/reports_test.dart`
Expected: FAIL biên dịch — `MonthlyFlowCard` chưa tồn tại.

- [ ] **Step 3: Implement**

Create `app/lib/features/reports/widgets/monthly_flow_card.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/domain/reports.dart';

class MonthlyFlowCard extends StatelessWidget {
  final List<MonthlyFlow> flows;
  const MonthlyFlowCard({super.key, required this.flows});

  @override
  Widget build(BuildContext context) {
    final hasData = flows.any((f) => f.income > 0 || f.expense > 0);
    if (!hasData) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.bar_chart,
            title: 'Chưa có thu chi nào',
            hint: 'Thêm giao dịch để xem xu hướng 6 tháng',
          ),
        ),
      );
    }
    final money = moneyColorsOf(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final maxV = flows
        .map((f) => f.income > f.expense ? f.income : f.expense)
        .fold<int>(0, (m, v) => v > m ? v : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Thu / chi · 6 tháng',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                _dot(money.income, 'Thu', muted),
                const SizedBox(width: 12),
                _dot(money.expense, 'Chi', muted),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(BarChartData(
                maxY: maxV * 1.1,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= flows.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('T${flows[i].month.month}',
                              style: TextStyle(fontSize: 11, color: muted)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < flows.length; i++)
                    BarChartGroupData(x: i, barsSpace: 3, barRods: [
                      BarChartRodData(
                        toY: flows[i].income.toDouble(),
                        color: money.income,
                        width: 10,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: flows[i].expense.toDouble(),
                        color: money.expense,
                        width: 10,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ]),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color, String label, Color muted) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: muted)),
        ],
      );
}
```

- [ ] **Step 4: Run to verify it passes**

Run (từ `app/`): `flutter test test/widget/reports_test.dart`
Expected: PASS — `ExpensePieCard` (2) + `MonthlyFlowCard` (2).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reports/widgets/monthly_flow_card.dart app/test/widget/reports_test.dart
git commit -m "feat(reports): MonthlyFlowCard widget (#7)"
```

---

### Task 6: `ReportsScreen` — wiring providers → domain → cards

**Files:**
- Create: `app/lib/features/reports/reports_screen.dart`
- Test: `app/test/widget/reports_test.dart` (thêm group)

- [ ] **Step 1: Write the failing tests**

Thêm các import DB + màn vào đầu `app/test/widget/reports_test.dart`, và `setUpAll(setupSqliteForTests);` làm dòng đầu trong `main()`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/reports/reports_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';
```

Rồi thêm group này vào `main()` (sau group `MonthlyFlowCard`):

```dart
  group('ReportsScreen', () {
    Widget app(AppDatabase db, DateTime month) => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            selectedMonthProvider.overrideWith((ref) => month),
          ],
          child: MaterialApp(
            theme: buildTheme(AppThemeStyle.classic, Brightness.light),
            home: const ReportsScreen(),
          ),
        );

    testWidgets('shows the expense category for the selected month',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      final repo = AppRepository(db);
      final cats = await db.select(db.categories).get();
      final food = cats.firstWhere((c) => c.name == 'Ăn uống');
      final w = (await db.select(db.wallets).get()).first;
      await repo.addTransaction(
        amount: 250000,
        type: TransactionType.expense,
        categoryId: food.id,
        walletId: w.id,
        occurredAt: DateTime(2026, 6, 10),
      );
      addTearDown(db.close);
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Báo cáo'), findsOneWidget);
      expect(find.text('Tháng 6/2026'), findsOneWidget);
      expect(find.text('Ăn uống'), findsWidgets);
      expect(find.text('250.000 ₫'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('prev-month button moves the selected month', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('reportsPrevMonth')));
      await tester.pump();
      expect(find.text('Tháng 5/2026'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run (từ `app/`): `flutter test test/widget/reports_test.dart`
Expected: FAIL biên dịch — `ReportsScreen` chưa tồn tại.

- [ ] **Step 3: Implement**

Create `app/lib/features/reports/reports_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/domain/reports.dart';
import 'package:moneynote/features/reports/widgets/expense_pie_card.dart';
import 'package:moneynote/features/reports/widgets/monthly_flow_card.dart';
import 'package:moneynote/state/providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: txnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (txns) {
          final catById = {for (final c in categories) c.id: c};
          final slices = [
            for (final s in expenseByCategory(txns, month))
              CategorySlice(
                label: catById[s.categoryId]?.name ?? 'Chưa phân loại',
                color: Color(catById[s.categoryId]?.color ?? 0xFF9E9E9E),
                total: s.total,
              ),
          ];
          final flows = monthlyFlow(txns, month, months: 6);
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      key: const Key('reportsPrevMonth'),
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () =>
                          ref.read(selectedMonthProvider.notifier).state =
                              DateTime(month.year, month.month - 1, 1),
                    ),
                    Text('Tháng ${month.month}/${month.year}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    IconButton(
                      key: const Key('reportsNextMonth'),
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () =>
                          ref.read(selectedMonthProvider.notifier).state =
                              DateTime(month.year, month.month + 1, 1),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ExpensePieCard(slices: slices),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: MonthlyFlowCard(flows: flows),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run (từ `app/`): `flutter test test/widget/reports_test.dart`
Expected: PASS toàn bộ file (ExpensePieCard ×2, MonthlyFlowCard ×2, ReportsScreen ×2).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reports/reports_screen.dart app/test/widget/reports_test.dart
git commit -m "feat(reports): ReportsScreen wiring pie + trend (#7)"
```

---

### Task 7: Lối vào từ Dashboard (icon `bar_chart`)

**Files:**
- Modify: `app/lib/features/home/home_shell.dart`
- Test: `app/test/widget/reports_test.dart` (thêm group)

- [ ] **Step 1: Write the failing test**

Thêm import `home_shell.dart` vào đầu `app/test/widget/reports_test.dart`:

```dart
import 'package:moneynote/features/home/home_shell.dart';
```

Rồi thêm group này vào `main()` (sau group `ReportsScreen`):

```dart
  group('dashboard entry to reports', () {
    testWidgets('bar_chart icon on the dashboard opens ReportsScreen',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      bigView(tester);

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildTheme(AppThemeStyle.classic, Brightness.light),
          home: const HomeShell(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('openReports')), findsOneWidget);
      await tester.tap(find.byKey(const Key('openReports')));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo'), findsOneWidget); // app bar của ReportsScreen

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run (từ `app/`): `flutter test test/widget/reports_test.dart -k "dashboard entry"`
Expected: FAIL — không tìm thấy widget có `Key('openReports')`.

- [ ] **Step 3: Implement**

Trong `app/lib/features/home/home_shell.dart`:

(a) Thêm import ở đầu file:

```dart
import 'package:moneynote/features/reports/reports_screen.dart';
```

(b) Thay khối `actions:` của `AppBar` (hiện chỉ có nút Settings) bằng:

```dart
        actions: [
          if (_index == 0)
            IconButton(
              key: const Key('openReports'),
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Báo cáo',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
```

- [ ] **Step 4: Run to verify it passes**

Run (từ `app/`): `flutter test test/widget/reports_test.dart`
Expected: PASS toàn bộ file (gồm group lối vào dashboard).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/home/home_shell.dart app/test/widget/reports_test.dart
git commit -m "feat(reports): open Reports from the dashboard app bar (#7)"
```

---

### Task 8: Gate — analyze + format + full suite

**Files:** (không tạo mới — kiểm tra toàn bộ)

- [ ] **Step 1: Analyze**

Run (từ `app/`): `flutter analyze`
Expected: **No issues found!** Nếu có cảnh báo (vd `const`, import thừa, `withOpacity` deprecate) → sửa rồi chạy lại.

- [ ] **Step 2: Format**

Run (từ `app/`): `dart format lib test`
Expected: report các file đã format. Nếu có thay đổi, gộp vào commit gate.

- [ ] **Step 3: Full suite**

Run (từ `app/`): `flutter test`
Expected: toàn bộ test PASS (≈96 cũ + ~11 mới của reports), không hồi quy. Nếu treo không output → kill process mồ côi (xem preamble) rồi chạy lại.

- [ ] **Step 4: Commit (nếu format đổi file)**

```bash
git add -A
git commit -m "style(reports): dart format + analyze gate (#7)"
```

---

## Hoàn tất

Sau Task 8, Phase 3c xong trên nhánh `feat/7-reports-charts`: domain aggregation thuần (`reports.dart`) + 2 chart card data-driven + `ReportsScreen` + lối vào dashboard, phủ unit + widget test. Bước tiếp (ngoài plan): mở PR vào `master`; khi merged thì `gh issue close 7`.

**Self-review note (đã rà):** mọi requirement của spec §3–§8 đều có task tương ứng; không placeholder; tên kiểu (`CategorySpend`, `MonthlyFlow`, `CategorySlice`, `expenseByCategory`, `monthlyFlow`) nhất quán giữa các task; `#16` (SQL pushdown) cố ý KHÔNG nằm trong plan (đã ghi ở spec §2). Card radius giữ token 16 (không đụng `theme.dart`).
