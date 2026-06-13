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

  testWidgets('tapping a transaction opens edit pre-filled; saving edits in place',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);

    // Drift stream reads must run outside the FakeAsync test zone.
    late final Category anUong, diLai;
    await tester.runAsync(() async {
      final cats = await repo.watchCategories().first;
      anUong = cats.firstWhere((c) => c.name == 'Ăn uống');
      diLai = cats.firstWhere((c) => c.name == 'Đi lại');
      final wallets = await repo.watchWallets().first;
      await repo.addTransaction(
        amount: 50000,
        type: TransactionType.expense,
        categoryId: anUong.id,
        walletId: wallets.single.id,
        note: 'phở',
      );
    });

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: TransactionsListScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    // Tap the row -> read-only detail, then "Sửa" -> edit screen pre-filled.
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết'), findsOneWidget);
    await tester.tap(find.byKey(const Key('editTxn')));
    await tester.pumpAndSettle();
    expect(find.text('Sửa giao dịch'), findsOneWidget);
    expect(find.text('50.000'), findsOneWidget); // amount pre-filled (grouped)
    expect(find.text('phở'), findsOneWidget); // note pre-filled

    // Change amount + category, save.
    await tester.enterText(find.byKey(const Key('amountField')), '65000');
    await tester.tap(find.byKey(const Key('cat_Đi lại')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pump(const Duration(milliseconds: 200));

    final txns = await tester.runAsync(() => repo.watchAllTransactions().first);
    expect(txns, hasLength(1)); // edited in place — no duplicate
    expect(txns!.single.amount, 65000);
    expect(txns.single.categoryId, diLai.id);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
