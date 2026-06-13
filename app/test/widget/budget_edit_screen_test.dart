import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/budgets/budget_edit_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('add: amount + category are saved', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    final food = (await db.select(db.categories).get())
        .firstWhere((c) => c.name == 'Ăn uống');
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: BudgetEditScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byKey(const Key('budgetAmount')), '500.000');
    await tester.tap(find.byKey(Key('budgetCat_${food.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveBudget')));
    await tester.pump(const Duration(milliseconds: 300));

    final budgets = await tester.runAsync(() => repo.watchBudgets().first);
    final b = budgets!.firstWhere((x) => x.categoryId == food.id);
    expect(b.amount, 500000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('add-mode excludes already-budgeted categories', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    final food = (await db.select(db.categories).get())
        .firstWhere((c) => c.name == 'Ăn uống');
    await repo.upsertBudget(food.id, 100000);
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: BudgetEditScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(Key('budgetCat_${food.id}')), findsNothing);
    expect(find.byKey(const Key('budgetCat_overall')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('edit: pre-fills, category locked, updates in place', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    final food = (await db.select(db.categories).get())
        .firstWhere((c) => c.name == 'Ăn uống');
    await repo.upsertBudget(food.id, 1000000);
    final existing =
        (await tester.runAsync(() => repo.watchBudgets().first))!.single;
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: BudgetEditScreen(existing: existing)),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1.000.000'), findsOneWidget); // pre-filled amount
    await tester.enterText(find.byKey(const Key('budgetAmount')), '1.200.000');
    await tester.tap(find.byKey(const Key('saveBudget')));
    await tester.pump(const Duration(milliseconds: 300));

    final budgets = await tester.runAsync(() => repo.watchBudgets().first);
    expect(budgets!.length, 1); // no duplicate
    expect(budgets.single.amount, 1200000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('amount <= 0 shows snackbar and does not save', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: BudgetEditScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final before = (await tester.runAsync(() => repo.watchBudgets().first))!.length;
    await tester.tap(find.byKey(const Key('saveBudget')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nhập hạn mức'), findsOneWidget);
    final after = (await tester.runAsync(() => repo.watchBudgets().first))!.length;
    expect(after, before);
    expect(find.byType(BudgetEditScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('empty options: note shown, Save disabled', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    final cats = await db.select(db.categories).get();
    await repo.upsertBudget(null, 1); // overall
    for (final c in cats.where((c) => c.type == CategoryType.expense)) {
      await repo.upsertBudget(c.id, 1);
    }
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: BudgetEditScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Đã đặt ngân sách cho mọi danh mục'), findsOneWidget);
    final save = tester.widget<TextButton>(find.byKey(const Key('saveBudget')));
    expect(save.onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
