import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/budgets/budget_detail_screen.dart';
import 'package:moneynote/features/budgets/budget_edit_screen.dart';
import 'package:moneynote/features/transactions/transaction_detail_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final month = DateTime(2026, 6, 1);

  Future<void> pumpDetail(WidgetTester tester, AppDatabase db, String id) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        selectedMonthProvider.overrideWith((ref) => month),
      ],
      child: MaterialApp(home: BudgetDetailScreen(id)),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<String> seedBudget(AppDatabase db) async {
    final repo = AppRepository(db);
    final cats = await db.select(db.categories).get();
    final food = cats.firstWhere((c) => c.name == 'Ăn uống');
    final other = cats.firstWhere((c) =>
        c.type == CategoryType.expense && c.name != 'Ăn uống');
    final w = (await db.select(db.wallets).get()).first;
    await repo.upsertBudget(food.id, 1000000);
    await repo.addTransaction(
        amount: 400000, type: TransactionType.expense, categoryId: food.id,
        walletId: w.id, note: 'phở', occurredAt: DateTime(2026, 6, 10));
    await repo.addTransaction(
        amount: 300000, type: TransactionType.expense, categoryId: food.id,
        walletId: w.id, note: 'cơm', occurredAt: DateTime(2026, 6, 12));
    await repo.addTransaction(
        amount: 999000, type: TransactionType.expense, categoryId: other.id,
        walletId: w.id, note: 'khác', occurredAt: DateTime(2026, 6, 12));
    await repo.addTransaction(
        amount: 500000, type: TransactionType.expense, categoryId: food.id,
        walletId: w.id, note: 'tháng trước', occurredAt: DateTime(2026, 5, 15));
    return (await repo.watchBudgets().first).single.id;
  }

  testWidgets('header, donut %, three stats, filtered txn list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    late String id;
    await tester.runAsync(() async => id = await seedBudget(db));
    await pumpDetail(tester, db, id);

    expect(find.text('Ăn uống · Ngân sách'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('700.000 ₫'), findsOneWidget); // Đã chi
    expect(find.text('300.000 ₫'), findsWidgets); // Còn lại (+ cơm txn tile)
    expect(find.text('1.000.000 ₫'), findsOneWidget); // Hạn mức
    expect(find.text('phở'), findsOneWidget);
    expect(find.text('cơm'), findsOneWidget);
    expect(find.text('khác'), findsNothing); // foreign category
    expect(find.text('tháng trước'), findsNothing); // other month
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('over budget → Vượt stat + >100% donut', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    late String id;
    await tester.runAsync(() async {
      final repo = AppRepository(db);
      final food = (await db.select(db.categories).get())
          .firstWhere((c) => c.name == 'Ăn uống');
      final w = (await db.select(db.wallets).get()).first;
      await repo.upsertBudget(food.id, 1000000);
      await repo.addTransaction(
          amount: 1300000, type: TransactionType.expense, categoryId: food.id,
          walletId: w.id, occurredAt: DateTime(2026, 6, 10));
      id = (await repo.watchBudgets().first).single.id;
    });
    await pumpDetail(tester, db, id);

    expect(find.text('130%'), findsOneWidget);
    expect(find.text('Vượt'), findsOneWidget);
    expect(find.text('300.000 ₫'), findsOneWidget); // spent - limit
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('overall budget: Tổng header, all expense counted', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    late String id;
    await tester.runAsync(() async {
      final repo = AppRepository(db);
      final cats = await db.select(db.categories).get();
      final food = cats.firstWhere((c) => c.name == 'Ăn uống');
      final other =
          cats.firstWhere((c) => c.type == CategoryType.expense && c.name != 'Ăn uống');
      final w = (await db.select(db.wallets).get()).first;
      await repo.upsertBudget(null, 1000000); // overall
      await repo.addTransaction(
          amount: 200000, type: TransactionType.expense, categoryId: food.id,
          walletId: w.id, occurredAt: DateTime(2026, 6, 10));
      await repo.addTransaction(
          amount: 300000, type: TransactionType.expense, categoryId: other.id,
          walletId: w.id, occurredAt: DateTime(2026, 6, 11));
      id = (await repo.watchBudgets().first).single.id;
    });
    await pumpDetail(tester, db, id);
    expect(find.text('Tổng · Ngân sách'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget); // 500k / 1.000.000
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Sửa → edit; tile → txn detail; null guard', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    late String id;
    await tester.runAsync(() async => id = await seedBudget(db));

    await pumpDetail(tester, db, 'nope');
    expect(find.text('Ngân sách không tồn tại'), findsOneWidget);

    await pumpDetail(tester, db, id);
    await tester.tap(find.byKey(const Key('budgetEdit')));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetEditScreen), findsOneWidget);

    await pumpDetail(tester, db, id);
    await tester.tap(find.byType(TransactionTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TransactionDetailScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('delete: confirm → soft-deleted, popped, no flash', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    bigView(tester);
    late String id;
    await tester.runAsync(() async => id = await seedBudget(db));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        selectedMonthProvider.overrideWith((ref) => month),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BudgetDetailScreen(id))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteBudget')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();

    expect(find.byType(BudgetDetailScreen), findsNothing);
    expect(find.text('Ngân sách không tồn tại'), findsNothing);
    final budgets = await tester.runAsync(() => repo.watchBudgets().first);
    expect(budgets!.where((b) => b.id == id), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
