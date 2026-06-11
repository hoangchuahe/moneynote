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

  testWidgets('budgets screen shows an over-budget category in red',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    final repo = AppRepository(db);
    // one-shot reads — NEVER read a Drift stream's .first in the test body (hangs FakeAsync)
    final cats = await db.select(db.categories).get();
    final food = cats.firstWhere((c) => c.name == 'Ăn uống');
    final w = (await db.select(db.wallets).get()).first;
    await repo.upsertBudget(food.id, 100000);
    await repo.addTransaction(
        amount: 150000,
        type: TransactionType.expense,
        categoryId: food.id,
        walletId: w.id);
    addTearDown(db.close);

    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: BudgetsScreen()),
    ));
    // let the budget/txn/category StreamProviders emit, then render
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.textContaining('⚠ vượt'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
