# MoneyNote Phase 3b — Budgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Monthly budgets per category + one overall budget, with passive overspend progress on the dashboard and a manage screen.

**Architecture:** A new `Budgets` Drift table (schema v3→v4 migration), a pure `spentInMonth(txns, month, {categoryId})` calc, repository `watchBudgets`/`upsertBudget`/`deleteBudget` (upsert keyed on `categoryId`, `null` = overall), a `budgetsProvider`, a dashboard budget section + a Budgets manage screen. Only `expense` counts toward a budget (income/transfer excluded). Warnings are passive (red progress), never blocking. Layering unchanged.

**Tech Stack:** Flutter (Dart 3), Riverpod, Drift (schema v4 migration + build_runner). No new packages.

**Reference spec:** `docs/superpowers/specs/2026-06-12-phase3b-budgets-design.md`.

---

## File Structure

```
app/lib/
├── domain/calculations.dart                 # MODIFY: + spentInMonth
├── data/database.dart                        # MODIFY: + Budgets table, schemaVersion 4 + migration
├── data/repository.dart                      # MODIFY: + watchBudgets/upsertBudget/deleteBudget
├── state/providers.dart                      # MODIFY: + budgetsProvider
└── features/
    ├── dashboard/dashboard_screen.dart        # MODIFY: + budget section (tap → manage)
    └── budgets/budgets_screen.dart            # NEW: manage budgets
app/test/
├── domain/calculations_test.dart             # MODIFY: + spentInMonth tests
├── data/repository_test.dart                 # MODIFY: + budget repo tests
└── widget/budgets_test.dart                  # NEW
```

No `pubspec.yaml` change.

---

## Task 1: `spentInMonth` (pure, TDD)

**Files:** Modify `app/lib/domain/calculations.dart`; modify `app/test/domain/calculations_test.dart`.

- [ ] **Step 1: Append failing tests** inside `main()` of `app/test/domain/calculations_test.dart` (uses its own helper to avoid touching the existing `txn`/`wallet` helpers):
```dart
  group('spentInMonth', () {
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

    final month = DateTime(2026, 6, 1);
    final txns = [
      etx(50000, 'food', DateTime(2026, 6, 5)),
      etx(30000, 'food', DateTime(2026, 6, 6)),
      etx(20000, 'move', DateTime(2026, 6, 7)),
      etx(99999, 'food', DateTime(2026, 5, 31)), // other month
      etx(5000000, 'salary', DateTime(2026, 6, 8), type: TransactionType.income),
      etx(1000000, null, DateTime(2026, 6, 9), type: TransactionType.transfer),
    ];

    test('per-category sums only that category expense this month', () {
      expect(spentInMonth(txns, month, categoryId: 'food'), 80000);
      expect(spentInMonth(txns, month, categoryId: 'move'), 20000);
    });

    test('overall (null) sums all expense, excludes income + transfer', () {
      expect(spentInMonth(txns, month), 100000); // 50k + 30k + 20k
    });

    test('respects month boundaries', () {
      expect(spentInMonth(txns, DateTime(2026, 5, 1), categoryId: 'food'), 99999);
    });
  });
```

- [ ] **Step 2: Run, verify FAIL**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\app; flutter test test/domain/calculations_test.dart
```
Expected: `spentInMonth` not defined.

- [ ] **Step 3: Implement** — add to `app/lib/domain/calculations.dart`:
```dart
/// Total EXPENSE in the calendar month of [month]. categoryId null = all expense
/// (for an overall budget); non-null = that category's expense. Income/transfer excluded.
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

- [ ] **Step 4: Run, verify PASS** — `flutter test test/domain/calculations_test.dart` → all pass (existing 5 + 3 new).

- [ ] **Step 5: Commit**

```powershell
Set-Location D:\Freelance\moneynote
git add app/lib/domain/calculations.dart app/test/domain/calculations_test.dart
git commit -m "feat(app): spentInMonth (per-category / overall expense, pure)"
```

---

## Task 2: Budget table + schema v4 migration

**Files:** Modify `app/lib/data/database.dart`; regenerate; modify `app/test/data/database_test.dart`.

- [ ] **Step 1: Add the table** to `database.dart` (next to the others):
```dart
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)(); // null = overall budget
  IntColumn get amount => integer()(); // monthly limit, đồng
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```
Add `Budgets` to the `@DriftDatabase(tables: [...])` list. Bump `schemaVersion` to **4** and add the budget step to the existing `onUpgrade` (keep the v2/v3 steps and `_ensureMerchantIndex`):
```dart
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _ensureMerchantIndex();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(merchantMemories);
          if (from < 3) await _ensureMerchantIndex();
          if (from < 4) await m.createTable(budgets);
        },
      );
```

- [ ] **Step 2: Regenerate**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\app; dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Append a failing test** to `app/test/data/database_test.dart` (inside `main()`):
```dart
  test('can insert and read a budget (overall + per-category)', () async {
    final now = DateTime(2026, 6, 11);
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: 'b1', categoryId: const Value(null), amount: 5000000, createdAt: now, updatedAt: now));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: 'b2', categoryId: const Value('food'), amount: 2000000, createdAt: now, updatedAt: now));
    final rows = await db.select(db.budgets).get();
    expect(rows, hasLength(2));
    expect(rows.firstWhere((b) => b.id == 'b1').categoryId, isNull);
    expect(rows.firstWhere((b) => b.id == 'b2').amount, 2000000);
  });
```
> Note: inserting `categoryId: const Value('food')` references a category id that doesn't exist, but FK enforcement is off (no `PRAGMA foreign_keys` in this project), so this is fine for the table test.

- [ ] **Step 4: Run, verify PASS** — `flutter test test/data/database_test.dart` → both tests pass (the v4 schema `onCreate` path runs for the in-memory db).

- [ ] **Step 5: Commit**

```powershell
Set-Location D:\Freelance\moneynote
git add app/lib/data/database.dart app/test/data/database_test.dart
git commit -m "feat(app): Budgets table (schema v4 + migration)"
```

---

## Task 3: Budget repository methods (TDD)

**Files:** Modify `app/lib/data/repository.dart`; modify `app/test/data/repository_test.dart`.

- [ ] **Step 1: Append failing tests** inside `main()` of `app/test/data/repository_test.dart`:
```dart
  test('upsertBudget inserts then updates (one per category)', () async {
    final c = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    await repo.upsertBudget(c.id, 2000000);
    var budgets = await repo.watchBudgets().first;
    expect(budgets, hasLength(1));
    expect(budgets.single.amount, 2000000);

    await repo.upsertBudget(c.id, 2500000); // update, not duplicate
    budgets = await repo.watchBudgets().first;
    expect(budgets, hasLength(1));
    expect(budgets.single.amount, 2500000);
  });

  test('upsertBudget supports an overall (null category) budget', () async {
    await repo.upsertBudget(null, 10000000);
    final budgets = await repo.watchBudgets().first;
    expect(budgets, hasLength(1));
    expect(budgets.single.categoryId, isNull);
    expect(budgets.single.amount, 10000000);
  });

  test('deleteBudget soft-deletes', () async {
    await repo.upsertBudget(null, 10000000);
    final b = (await repo.watchBudgets().first).single;
    await repo.deleteBudget(b.id);
    expect(await repo.watchBudgets().first, isEmpty);
  });
```

- [ ] **Step 2: Run, verify FAIL** — `flutter test test/data/repository_test.dart` → `upsertBudget`/`watchBudgets`/`deleteBudget` undefined.

- [ ] **Step 3: Add methods** inside `AppRepository` in `repository.dart` (uses existing `_uuid`):
```dart
  Stream<List<Budget>> watchBudgets() => (db.select(db.budgets)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  /// Sets the monthly budget for [categoryId] (null = overall). Updates the
  /// existing row for that category (un-deleting if needed), or inserts a new one.
  Future<void> upsertBudget(String? categoryId, int amount) async {
    final now = DateTime.now();
    final existing = await (db.select(db.budgets)
          ..where((t) => categoryId == null
              ? t.categoryId.isNull()
              : t.categoryId.equals(categoryId)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
            id: _uuid.v4(),
            categoryId: Value(categoryId),
            amount: amount,
            createdAt: now,
            updatedAt: now,
          ));
    } else {
      await (db.update(db.budgets)..where((t) => t.id.equals(existing.id)))
          .write(BudgetsCompanion(
        amount: Value(amount),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ));
    }
  }

  Future<void> deleteBudget(String id) async {
    final now = DateTime.now();
    await (db.update(db.budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
```

- [ ] **Step 4: Run, verify PASS** — `flutter test test/data/repository_test.dart` → all pass.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/data/repository.dart app/test/data/repository_test.dart
git commit -m "feat(app): budget repo (watchBudgets/upsertBudget/deleteBudget)"
```

---

## Task 4: `budgetsProvider`

**Files:** Modify `app/lib/state/providers.dart`.

- [ ] **Step 1: Add the provider**:
```dart
final budgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(repositoryProvider).watchBudgets(),
);
```
(`Budget` is exported from `database.dart`, already imported in providers.dart.)

- [ ] **Step 2: Verify** — `cd app ; flutter analyze` → "No issues found!".

- [ ] **Step 3: Commit**

```powershell
git add app/lib/state/providers.dart
git commit -m "feat(app): budgetsProvider"
```

---

## Task 5: Budgets screen + dashboard section (+ widget test)

**Files:** Create `app/lib/features/budgets/budgets_screen.dart`; modify `app/lib/features/dashboard/dashboard_screen.dart`; test `app/test/widget/budgets_test.dart`.

- [ ] **Step 1: Create `budgets_screen.dart`:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/state/providers.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catName = {for (final c in categories) c.id: c.name};
    final month = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ngân sách')),
      body: budgets.isEmpty
          ? const Center(child: Text('Chưa có ngân sách nào'))
          : ListView(
              children: [
                for (final b in budgets)
                  _BudgetTile(
                    name: b.categoryId == null
                        ? 'Tổng'
                        : (catName[b.categoryId] ?? '—'),
                    spent: spentInMonth(txns, month, categoryId: b.categoryId),
                    limit: b.amount,
                    onTap: () => _editBudget(context, ref, b),
                    onLongPress: () =>
                        ref.read(repositoryProvider).deleteBudget(b.id),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addBudget(context, ref, categories),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addBudget(
      BuildContext context, WidgetRef ref, List<Category> categories) async {
    final expenseCats =
        categories.where((c) => c.type == CategoryType.expense).toList();
    String? categoryId; // null = Tổng
    final amountCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Thêm ngân sách'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String?>(
                value: categoryId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tổng')),
                  for (final c in expenseCats)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => categoryId = v),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Hạn mức/tháng'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                ref.read(repositoryProvider).upsertBudget(categoryId, amount);
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBudget(
      BuildContext context, WidgetRef ref, Budget b) async {
    final amountCtrl = TextEditingController(text: b.amount.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa hạn mức'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Hạn mức/tháng'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              ref.read(repositoryProvider).upsertBudget(b.categoryId, amount);
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

/// Shared progress tile (used by the Budgets screen and the dashboard section).
class _BudgetTile extends StatelessWidget {
  final String name;
  final int spent;
  final int limit;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _BudgetTile({
    required this.name,
    required this.spent,
    required this.limit,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final over = spent > limit;
    final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: ratio,
            color: over ? Colors.red : null,
          ),
          const SizedBox(height: 4),
          Text(
            '${formatVnd(spent)} / ${formatVnd(limit)}${over ? '  ⚠ vượt' : ''}',
            style: TextStyle(color: over ? Colors.red : null),
          ),
        ],
      ),
    );
  }
}

/// Public compact row for the dashboard (reuses the same visuals).
Widget budgetSummaryTile(
        {required String name, required int spent, required int limit}) =>
    _BudgetTile(name: name, spent: spent, limit: limit);
```

- [ ] **Step 2: Add a budget section to `dashboard_screen.dart`.** In the `data:` builder of the dashboard's `transactionsProvider.when(...)`, also read budgets + month, and insert a tappable budget Card BETWEEN the summary `Card` and the `'Gần đây'` padding. First add reads at the top of `build` (the dashboard is a ConsumerWidget):
```dart
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
```
Then, in the `ListView` children (after the summary Card, before the 'Gần đây' Text), insert:
```dart
            // Always-present budget card: rows when budgets exist, otherwise a
            // "Thêm ngân sách →" tap target so the FIRST budget has an entry point
            // (resolves the chicken-and-egg: budgets are added from BudgetsScreen,
            // reachable only by tapping this card).
            Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BudgetsScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text('Ngân sách'),
                      ),
                      if (budgets.isEmpty)
                        const ListTile(
                          dense: true,
                          title: Text('Thêm ngân sách →'),
                        )
                      else
                        for (final b in budgets)
                          budgetSummaryTile(
                            name: b.categoryId == null
                                ? 'Tổng'
                                : (catName[b.categoryId] ?? '—'),
                            spent: spentInMonth(txns, month,
                                categoryId: b.categoryId),
                            limit: b.amount,
                          ),
                    ],
                  ),
                ),
              ),
            ),
```
Add import to dashboard: `package:moneynote/features/budgets/budgets_screen.dart`. `catName`, `txns`, `month` are already in scope in the dashboard build (month from `selectedMonthProvider`, txns from the `.when` data, catName from the categories map). `spentInMonth` comes from the already-imported `calculations.dart`.

- [ ] **Step 3: Write the widget test** `app/test/widget/budgets_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/budgets/budgets_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('budgets screen shows an over-budget category in red text',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    final repo = AppRepository(db);
    // one-shot reads (NO stream .first in FakeAsync — it hangs)
    final cats = await db.select(db.categories).get();
    final food = cats.firstWhere((c) => c.name == 'Ăn uống');
    final w = (await db.select(db.wallets).get()).first;
    await repo.upsertBudget(food.id, 100000); // limit 100k
    await repo.addTransaction(
        amount: 150000,
        type: TransactionType.expense,
        categoryId: food.id,
        walletId: w.id); // spent 150k > 100k
    addTearDown(db.close);

    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: BudgetsScreen()),
    ));
    // let the budget/txn/category streams emit, then render
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.textContaining('⚠ vượt'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
```
> **Widget-test playbook (this app):** never read a Drift stream's `.first` in the test body's setup — it hangs FakeAsync (use one-shot `db.select(...).get()`); after `pumpWidget`, `pump(300ms)` + `pump()` lets the in-widget StreamProviders emit; finish with `pumpWidget(SizedBox.shrink()) + pump(Duration.zero)` to flush Drift timers. If `selectedMonthProvider` defaults to the real current month and the seeded transaction's `occurredAt` is `DateTime.now()`, they match — the over state shows. (Both use "now".)

- [ ] **Step 4: Run + verify** — `flutter test test/widget/budgets_test.dart` → PASS. `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```powershell
Set-Location D:\Freelance\moneynote
git add app/lib/features/budgets/budgets_screen.dart app/lib/features/dashboard/dashboard_screen.dart app/test/widget/budgets_test.dart
git commit -m "feat(app): budgets screen + dashboard budget section (progress + overspend)"
```

---

## Task 6: Full suite + emulator e2e

**Files:** none (verification).

- [ ] **Step 1: Full suite + analyze**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
Set-Location D:\Freelance\moneynote\app
flutter analyze
flutter test
```
Expected: analyze clean; all tests pass (prior 39 + spentInMonth 3 + budget db 1 + budget repo 3 + budgets widget 1).

- [ ] **Step 2: Run on Pixel_6 (no backend/network needed)**

```powershell
cd D:\Freelance\moneynote\app ; flutter run
```
Verify:
1. Dashboard shows a "Ngân sách" card with "Thêm ngân sách →" (no budgets yet). Tap it → BudgetsScreen.
2. FAB → add "Ăn uống" = 100.000. Back on the dashboard, the card now shows the Ăn uống row with a progress bar.
3. Add a 150.000 expense in Ăn uống → the budget bar turns red with "⚠ vượt" on both the dashboard card and BudgetsScreen.
4. In BudgetsScreen: tap a row → edit its amount; long-press a row → it's removed.

- [ ] **Step 3: Commit any fixes; Phase 3b complete.**

---

## Self-Review (completed)

**Spec coverage (`2026-06-12-phase3b-budgets-design.md`):**
- §3 Budget table (categoryId nullable, amount, sync fields) + schema v4 migration → Task 2. ✓
- §4 `spentInMonth` (per-category / overall / excludes income+transfer / month boundary) → Task 1. ✓
- §5 dashboard budget section (progress + overspend, tap → manage) + Budgets manage screen (add/edit/delete) → Task 5. ✓
- §6 data flow (budgetsProvider, watchBudgets/upsertBudget/deleteBudget, upsert keyed on categoryId incl null) → Tasks 3, 4. ✓
- §8 testing (spentInMonth unit; upsert/watch/delete repo; widget over-state) → Tasks 1, 3, 5. ✓

**Placeholder scan:** No TBD/TODO. The first-budget chicken-and-egg (dashboard section was the only path to BudgetsScreen) is resolved in Task 5: the dashboard budget Card is always rendered, showing a "Thêm ngân sách →" tap target when empty and budget rows when present — so the create path always exists.

**Type consistency:** `spentInMonth(txns, month, {categoryId})` consistent across Task 1, 5. `Budget`/`BudgetsCompanion` from generated code. Repo `watchBudgets()`/`upsertBudget(String?, int)`/`deleteBudget(String)` consistent across Tasks 3, 5. `budgetsProvider` consistent. `_BudgetTile`/`budgetSummaryTile` consistent within Task 5.

**Known risks flagged:** widget test must avoid stream `.first` in setup (use `.get()`) — playbook in Task 5. First-budget entry point must be added on the dashboard (Task 5/6).
