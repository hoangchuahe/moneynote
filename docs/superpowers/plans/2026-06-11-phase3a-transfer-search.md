# MoneyNote Phase 3a — Transfer UI + Search/Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the create-transfer flow (a "Chuyển" mode on the Add screen) and search/filter (text + category + date range) on the transactions list — Flutter-only, no new dependencies.

**Architecture:** Transfer reuses the existing P1 data layer (`addTransaction` already supports `type: transfer` + `toWalletId`; `balanceOf`/`summarize` already handle transfers); 3a adds only UI + one validation. Search/filter is a pure `filterTransactions(txns, TxnFilter)` applied in-memory over the existing `transactionsProvider`, driven by a `txnFilterProvider`. Layering unchanged: UI → providers → repository/domain.

**Tech Stack:** Flutter (Dart 3), Riverpod, Drift (no schema change), Material `showDateRangePicker`. No new packages.

**Reference spec:** `docs/superpowers/specs/2026-06-11-phase3a-transfer-search-design.md`.

---

## File Structure

```
app/lib/
├── domain/transaction_filter.dart          # NEW: TxnFilter + filterTransactions (pure)
├── state/providers.dart                     # MODIFY: + txnFilterProvider
├── data/repository.dart                     # MODIFY: addTransaction transfer validation
└── features/transactions/
    ├── add_transaction_screen.dart          # MODIFY: "Chuyển" segment + from/to wallets
    └── transactions_list_screen.dart        # MODIFY: search bar + filter sheet + apply
app/test/
├── domain/transaction_filter_test.dart      # NEW
├── data/repository_test.dart                # MODIFY: + transfer validation tests
└── widget/transfer_test.dart                # NEW (transfer create flow)
└── widget/search_filter_test.dart           # NEW (search filters list)
```

No `pubspec.yaml` change. `database.dart` unchanged (transfer fields already exist).

---

## Task 1: `filterTransactions` (pure, strict TDD)

**Files:** Create `app/lib/domain/transaction_filter.dart`; test `app/test/domain/transaction_filter_test.dart`.

- [ ] **Step 1: Write the failing test**

`app/test/domain/transaction_filter_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/transaction_filter.dart';

Transaction txn({
  required String id,
  String note = '',
  String? categoryId,
  required DateTime occurredAt,
}) =>
    Transaction(
      id: id,
      amount: 1000,
      type: TransactionType.expense,
      categoryId: categoryId,
      walletId: 'w1',
      toWalletId: null,
      note: note,
      occurredAt: occurredAt,
      createdAt: occurredAt,
      updatedAt: occurredAt,
    );

void main() {
  final all = [
    txn(id: '1', note: 'cà phê Highlands', categoryId: 'c-food', occurredAt: DateTime(2026, 6, 5)),
    txn(id: '2', note: 'taxi về nhà', categoryId: 'c-move', occurredAt: DateTime(2026, 6, 10)),
    txn(id: '3', note: 'cà phê Trung Nguyên', categoryId: 'c-food', occurredAt: DateTime(2026, 5, 30)),
  ];

  test('empty filter returns all', () {
    expect(filterTransactions(all, const TxnFilter()).length, 3);
    expect(const TxnFilter().isActive, isFalse);
  });

  test('text matches note case-insensitively', () {
    final r = filterTransactions(all, const TxnFilter(text: 'cà phê'));
    expect(r.map((t) => t.id), ['1', '3']);
  });

  test('category filter keeps only matching categories', () {
    final r = filterTransactions(all, const TxnFilter(categoryIds: {'c-food'}));
    expect(r.map((t) => t.id), ['1', '3']);
  });

  test('date range is inclusive', () {
    final r = filterTransactions(
        all, TxnFilter(from: DateTime(2026, 6, 1), to: DateTime(2026, 6, 30)));
    expect(r.map((t) => t.id), ['1', '2']);
  });

  test('filters combine (AND)', () {
    final r = filterTransactions(
        all, TxnFilter(text: 'cà phê', from: DateTime(2026, 6, 1), to: DateTime(2026, 6, 30)));
    expect(r.map((t) => t.id), ['1']);
  });
}
```

- [ ] **Step 2: Run, verify FAIL**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User'); Set-Location D:\Freelance\moneynote\app; flutter test test/domain/transaction_filter_test.dart
```
Expected: `TxnFilter`/`filterTransactions` not found.

- [ ] **Step 3: Implement**

`app/lib/domain/transaction_filter.dart`:
```dart
import 'package:moneynote/data/database.dart';

/// Active filter for the transactions list. All fields combine with AND.
class TxnFilter {
  final String text;
  final Set<String> categoryIds;
  final DateTime? from; // inclusive (caller passes start-of-day)
  final DateTime? to; // inclusive (caller passes end-of-day)
  const TxnFilter({
    this.text = '',
    this.categoryIds = const {},
    this.from,
    this.to,
  });

  bool get isActive =>
      text.trim().isNotEmpty ||
      categoryIds.isNotEmpty ||
      from != null ||
      to != null;

  TxnFilter copyWith({
    String? text,
    Set<String>? categoryIds,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
  }) =>
      TxnFilter(
        text: text ?? this.text,
        categoryIds: categoryIds ?? this.categoryIds,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
      );
}

/// Pure filter over a transaction list. Returns the input unchanged when the
/// filter is not active. Category filter naturally drops transfers (null category).
List<Transaction> filterTransactions(List<Transaction> txns, TxnFilter f) {
  if (!f.isActive) return txns;
  final q = f.text.trim().toLowerCase();
  return txns.where((t) {
    if (q.isNotEmpty && !t.note.toLowerCase().contains(q)) return false;
    if (f.categoryIds.isNotEmpty &&
        (t.categoryId == null || !f.categoryIds.contains(t.categoryId))) {
      return false;
    }
    if (f.from != null && t.occurredAt.isBefore(f.from!)) return false;
    if (f.to != null && t.occurredAt.isAfter(f.to!)) return false;
    return true;
  }).toList();
}
```

- [ ] **Step 4: Run, verify PASS** — `flutter test test/domain/transaction_filter_test.dart` → 5 tests PASS.

- [ ] **Step 5: Commit**

```powershell
Set-Location D:\Freelance\moneynote
git add app/lib/domain/transaction_filter.dart app/test/domain/transaction_filter_test.dart
git commit -m "feat(app): TxnFilter + filterTransactions (text/category/date, pure)"
```

---

## Task 2: Transfer validation in `addTransaction` (TDD)

**Files:** Modify `app/lib/data/repository.dart`; modify `app/test/data/repository_test.dart`.

- [ ] **Step 1: Append failing tests** inside `main()` of `app/test/data/repository_test.dart`:
```dart
  test('addTransaction rejects transfer without toWallet or with same wallet', () async {
    final a = await repo.addWallet(name: 'A', type: WalletType.cash);
    expect(
      () => repo.addTransaction(
          amount: 1000, type: TransactionType.transfer, walletId: a.id),
      throwsArgumentError,
    );
    expect(
      () => repo.addTransaction(
          amount: 1000, type: TransactionType.transfer, walletId: a.id, toWalletId: a.id),
      throwsArgumentError,
    );
  });

  test('addTransaction accepts a valid transfer', () async {
    final a = await repo.addWallet(name: 'A', type: WalletType.cash);
    final b = await repo.addWallet(name: 'B', type: WalletType.cash);
    final t = await repo.addTransaction(
        amount: 30000, type: TransactionType.transfer, walletId: a.id, toWalletId: b.id);
    expect(t.type, TransactionType.transfer);
    expect(t.toWalletId, b.id);
    expect(t.categoryId, isNull);
  });
```

- [ ] **Step 2: Run, verify FAIL** — `flutter test test/data/repository_test.dart` → the "rejects transfer" test fails (currently a transfer with no toWallet is accepted).

- [ ] **Step 3: Add validation** in `repository.dart` `addTransaction`, immediately after the existing `if (amount <= 0) { throw ArgumentError.value(...); }` block:
```dart
    if (type == TransactionType.transfer &&
        (toWalletId == null || toWalletId == walletId)) {
      throw ArgumentError.value(
          toWalletId, 'toWalletId', 'transfer cần ví đích khác ví nguồn');
    }
```

- [ ] **Step 4: Run, verify PASS** — `flutter test test/data/repository_test.dart` → all pass (8 prior + 2 new).

- [ ] **Step 5: Commit**

```powershell
git add app/lib/data/repository.dart app/test/data/repository_test.dart
git commit -m "feat(app): validate transfers in addTransaction (toWallet required, != source)"
```

---

## Task 3: "Chuyển" mode on the Add screen (+ widget test)

Extends the EXISTING `AddTransactionScreen` (which already has the P2 smart input). Add a third segment; in transfer mode hide smart-input + category, show From/To wallet dropdowns. Keep all existing income/expense behaviour and keys.

**Files:** Modify `app/lib/features/transactions/add_transaction_screen.dart`; test `app/test/widget/transfer_test.dart`.

- [ ] **Step 1: Add state field.** In `_AddTransactionScreenState`, add next to `_walletId`:
```dart
  String? _toWalletId;
```

- [ ] **Step 2: Add the "Chuyển" segment.** In `build`, change the `SegmentedButton<TransactionType>` `segments:` to include a third option:
```dart
            segments: const [
              ButtonSegment(value: TransactionType.expense, label: Text('Chi')),
              ButtonSegment(value: TransactionType.income, label: Text('Thu')),
              ButtonSegment(value: TransactionType.transfer, label: Text('Chuyển')),
            ],
```
(Leave its `onSelectionChanged` as-is — it sets `_type` and resets `_categoryId`.)

- [ ] **Step 3: Hide smart-input + category in transfer mode.** Wrap the smart-input `Row(...)` + its trailing `Divider` AND the "Danh mục" `Text` + the category `Wrap(...)` so they only render when not transferring. Concretely, guard each with `if (_type != TransactionType.transfer) ...`. Use collection-if inside the `ListView` children list, e.g.:
```dart
          if (_type != TransactionType.transfer) ...[
            // (the smart-input Row)
            // (its Divider)
          ],
          // SegmentedButton stays always-visible
          // amount field stays always-visible
          if (_type != TransactionType.transfer) ...[
            // (the 'Danh mục' Text + SizedBox + category Wrap)
          ],
```
(The amount field, date tile, note field, and Save button stay visible in all modes.)

- [ ] **Step 4: Conditional wallet area.** Replace the single wallet `DropdownButtonFormField` block with: the existing single dropdown when not transferring, OR two dropdowns when transferring:
```dart
          if (_type == TransactionType.transfer) ...[
            DropdownButtonFormField<String>(
              key: const Key('fromWallet'),
              initialValue: _walletId,
              decoration: const InputDecoration(labelText: 'Từ ví'),
              items: [
                for (final w in wallets)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _walletId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('toWallet'),
              initialValue: _toWalletId,
              decoration: const InputDecoration(labelText: 'Đến ví'),
              items: [
                for (final w in wallets)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _toWalletId = v),
            ),
          ] else
            DropdownButtonFormField<String>(
              key: const Key('walletDropdown'),
              initialValue: _walletId,
              decoration: const InputDecoration(labelText: 'Ví'),
              items: [
                for (final w in wallets)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _walletId = v),
            ),
```

- [ ] **Step 5: Handle transfer in `_save()`.** At the TOP of `_save()`, before the existing income/expense logic, branch on transfer:
```dart
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập số tiền hợp lệ')));
      return;
    }
    if (_type == TransactionType.transfer) {
      final from = _walletId;
      final to = _toWalletId;
      if (from == null || to == null || from == to) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chọn hai ví khác nhau')));
        return;
      }
      await ref.read(repositoryProvider).addTransaction(
            amount: amount,
            type: TransactionType.transfer,
            walletId: from,
            toWalletId: to,
            note: _noteCtrl.text.trim(),
            occurredAt: _date,
          );
      if (mounted) Navigator.of(context).pop();
      return;
    }
```
(The rest of `_save()` — the income/expense path with merchant-learn — stays unchanged below this block. Remove the now-duplicated early `amount` parse/guard from the old code so amount is parsed once at the top.)

- [ ] **Step 6: Write the widget test** `app/test/widget/transfer_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('transfer mode creates a transfer between two wallets',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db); // creates wallet "Tiền mặt"
    final repo = AppRepository(db);
    final bank = await repo.addWallet(name: 'Vietcombank', type: WalletType.bank);
    addTearDown(db.close);

    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: AddTransactionScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    // switch to Chuyển
    await tester.tap(find.text('Chuyển'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('amountField')), '30000');
    // pick To wallet = Vietcombank (From defaults to first wallet)
    await tester.tap(find.byKey(const Key('toWallet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vietcombank').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pump(const Duration(milliseconds: 300));

    final txns = await tester.runAsync(() => repo.watchAllTransactions().first);
    expect(txns, hasLength(1));
    expect(txns!.single.type, TransactionType.transfer);
    expect(txns.single.amount, 30000);
    expect(txns.single.toWalletId, bank.id);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
```

- [ ] **Step 7: Run + verify.** `flutter test test/widget/transfer_test.dart` → PASS (adjust pump timing/viewport per the existing `add_transaction_test.dart` playbook if needed). Then run `flutter test test/widget/add_transaction_test.dart` + `test/widget/smart_input_test.dart` — both still PASS (income/expense path + keys unchanged). `flutter analyze` clean.

- [ ] **Step 8: Commit**

```powershell
git add app/lib/features/transactions/add_transaction_screen.dart app/test/widget/transfer_test.dart
git commit -m "feat(app): transfer mode on Add screen (Chuyển segment + from/to wallets)"
```

---

## Task 4: Search + filter on the transactions list (+ widget test)

**Files:** Modify `app/lib/state/providers.dart`; modify `app/lib/features/transactions/transactions_list_screen.dart`; test `app/test/widget/search_filter_test.dart`.

- [ ] **Step 1: Add the provider** to `lib/state/providers.dart`:
```dart
import 'package:moneynote/domain/transaction_filter.dart';

final txnFilterProvider =
    StateProvider<TxnFilter>((ref) => const TxnFilter());
```

- [ ] **Step 2: Rewrite `transactions_list_screen.dart`** to add a search bar + filter sheet and apply the filter. Full file:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/transaction_filter.dart';
import 'package:moneynote/state/providers.dart';

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catName = {for (final c in categories) c.id: c.name};
    final filter = ref.watch(txnFilterProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('searchField'),
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo ghi chú…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => ref.read(txnFilterProvider.notifier).state =
                      filter.copyWith(text: v),
                ),
              ),
              IconButton(
                key: const Key('filterButton'),
                icon: Icon(filter.isActive
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined),
                onPressed: () => _openFilterSheet(context, ref, categories),
              ),
            ],
          ),
        ),
        Expanded(
          child: txnsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi: $e')),
            data: (all) {
              final txns = filterTransactions(all, filter);
              if (txns.isEmpty) {
                return Center(
                    child: Text(filter.isActive
                        ? 'Không có giao dịch khớp'
                        : 'Chưa có giao dịch nào'));
              }
              return ListView(
                children: [
                  for (final t in txns)
                    Dismissible(
                      key: Key('txn_${t.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        final repo = ref.read(repositoryProvider);
                        repo.softDeleteTransaction(t.id);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: const Text('Đã xoá giao dịch'),
                            action: SnackBarAction(
                              label: 'Hoàn tác',
                              onPressed: () => repo.restoreTransaction(t.id),
                            ),
                          ));
                      },
                      child: ListTile(
                        title: Text(catName[t.categoryId] ??
                            (t.type == TransactionType.transfer
                                ? 'Chuyển ví'
                                : '—')),
                        subtitle: Text(formatDmy(t.occurredAt) +
                            (t.note.isEmpty ? '' : ' · ${t.note}')),
                        trailing: Text(
                          (t.type == TransactionType.expense ? '-' : '+') +
                              formatVnd(t.amount),
                          style: TextStyle(
                            color: t.type == TransactionType.expense
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openFilterSheet(
      BuildContext context, WidgetRef ref, List<Category> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final filter = ref.read(txnFilterProvider);
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final f = ref.read(txnFilterProvider);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Danh mục'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in categories)
                        FilterChip(
                          label: Text(c.name),
                          selected: f.categoryIds.contains(c.id),
                          onSelected: (sel) {
                            final next = {...f.categoryIds};
                            sel ? next.add(c.id) : next.remove(c.id);
                            ref.read(txnFilterProvider.notifier).state =
                                f.copyWith(categoryIds: next);
                            setSheet(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: ctx,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (range != null) {
                            ref.read(txnFilterProvider.notifier).state =
                                f.copyWith(
                              from: DateTime(range.start.year,
                                  range.start.month, range.start.day),
                              to: DateTime(range.end.year, range.end.month,
                                  range.end.day, 23, 59, 59),
                            );
                            setSheet(() {});
                          }
                        },
                        child: Text(f.from == null
                            ? 'Chọn khoảng ngày'
                            : '${f.from!.day}/${f.from!.month} – ${f.to!.day}/${f.to!.month}'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          ref.read(txnFilterProvider.notifier).state =
                              const TxnFilter();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Xoá lọc'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Xong'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
```
> Note: the screen now returns a `Column` (not the bare `.when`) because it hosts the search bar above the list. It is still a body inside `HomeShell`'s Scaffold — `ScaffoldMessenger`/`showModalBottomSheet` resolve against that.

- [ ] **Step 3: Write the widget test** `app/test/widget/search_filter_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/transactions/transactions_list_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('search filters the transaction list by note', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    final repo = AppRepository(db);
    final w = (await repo.watchWallets().first).first;
    await repo.addTransaction(amount: 40000, type: TransactionType.expense, walletId: w.id, note: 'cà phê');
    await repo.addTransaction(amount: 25000, type: TransactionType.expense, walletId: w.id, note: 'taxi');
    addTearDown(db.close);

    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: TransactionsListScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('cà phê', findRichText: true), findsWidgets);
    expect(find.textContaining('taxi'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('searchField')), 'cà phê');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('taxi'), findsNothing);
    expect(find.textContaining('cà phê'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
```
> If a matcher is brittle (the subtitle concatenates date · note), assert on `find.textContaining('taxi')` disappearing after the search — that's the key behaviour. Adjust to what reliably proves "taxi" is filtered out and a coffee row remains.

- [ ] **Step 4: Run + verify.** `flutter test test/widget/search_filter_test.dart` → PASS. `flutter analyze` clean.

- [ ] **Step 5: Commit**

```powershell
git add app/lib/state/providers.dart app/lib/features/transactions/transactions_list_screen.dart app/test/widget/search_filter_test.dart
git commit -m "feat(app): search + filter (text/category/date) on transactions list"
```

---

## Task 5: Full suite + emulator e2e

**Files:** none (verification).

- [ ] **Step 1: Full suites**

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
Set-Location D:\Freelance\moneynote\app
flutter analyze
flutter test
```
Expected: analyze clean; all tests pass (Phase 1+2 tests + filter 5 + repo transfer 2 + transfer widget 1 + search widget 1).

- [ ] **Step 2: Run on Pixel_6 and smoke-test by hand**

3a has NO backend/network — no server or wifi-disable needed. Build + run:
```powershell
flutter emulators --launch Pixel_6   # if not running; cold-boot + software GPU per project notes if it sticks
cd D:\Freelance\moneynote\app ; flutter run
```
Verify:
1. Add → segment **Chuyển** → "Từ ví" Tiền mặt, add a 2nd wallet first if needed → "Đến ví" → amount → Lưu. Transfer appears in the list as "Chuyển ví"; both wallet balances change correctly (Ví tab).
2. Giao dịch tab → type in the search box → list narrows to matching notes. Filter icon → pick a category / date range → list narrows. "Xoá lọc" resets.

- [ ] **Step 3: Commit any fixes; Phase 3a complete.**

---

## Self-Review (completed)

**Spec coverage (`2026-06-11-phase3a-transfer-search-design.md`):**
- §3 transfer UI (Chuyển segment, from/to wallets, hide smart-input+category, transfer save) → Task 3. ✓
- §4 transfer validation in addTransaction → Task 2. ✓
- §5 search/filter (TxnFilter, filterTransactions, txnFilterProvider, search bar + filter sheet) → Task 1 (pure) + Task 4 (UI/provider). ✓
- §6 files → Tasks 1–4 touch exactly those files. ✓
- §7 testing (unit filter + transfer validation; widget transfer + search) → Tasks 1,2,3,4 + Task 5 e2e. ✓

**Placeholder scan:** No TBD/TODO. The `final _ = ref;` capture line in Task 4 is flagged inline with "prefer deleting it" — the engineer removes it if the analyzer complains (it shouldn't be needed since `ref` is used in the sheet builder via `ref.read`). Note: confirm `_openFilterSheet` actually uses `ref` (it does, in the FilterChip/date callbacks) and drop the stray line.

**Type consistency:** `TxnFilter` fields (text/categoryIds/from/to) + `copyWith` consistent across Task 1, 4. `filterTransactions` signature consistent. `txnFilterProvider` (StateProvider<TxnFilter>) consistent. Add-screen keys: existing `amountField`/`saveButton`/`walletDropdown` preserved; new `fromWallet`/`toWallet` added; transfer uses `addTransaction(type: transfer, toWalletId:)` matching Task 2's validated signature. List keys `searchField`/`filterButton` consistent with the test.

**Known risk flagged:** widget tests in this app need the established viewport + teardown playbook (see `add_transaction_test.dart`); Task 3/4 tests include it. The `_openFilterSheet` stray `ref` line should be removed during implementation.
