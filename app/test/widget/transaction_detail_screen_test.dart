import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/features/transactions/transaction_detail_screen.dart';
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

  Future<void> pumpDetail(WidgetTester tester, AppDatabase db, String id) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TransactionDetailScreen(id))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('expense detail: hero + 4 fields, unsigned amount, note',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    final repo = AppRepository(db);
    late String id;
    await tester.runAsync(() async {
      final cats = await repo.watchCategories().first;
      final anUong = cats.firstWhere((c) => c.name == 'Ăn uống');
      final wallets = await repo.watchWallets().first;
      final t = await repo.addTransaction(
          amount: 50000,
          type: TransactionType.expense,
          categoryId: anUong.id,
          walletId: wallets.first.id,
          note: 'phở');
      id = t.id;
    });
    await pumpDetail(tester, db, id);

    expect(find.text('Chi tiết'), findsOneWidget);
    expect(find.text('Ăn uống'), findsWidgets);
    expect(find.text('50.000 ₫'), findsWidgets);
    expect(find.text('Danh mục'), findsOneWidget);
    expect(find.text('Ví'), findsOneWidget);
    expect(find.text('Ngày'), findsOneWidget);
    expect(find.text('Loại'), findsOneWidget);
    expect(find.text('Khoản chi'), findsOneWidget);
    expect(find.text('phở'), findsOneWidget);
    expect(find.textContaining('+50.000'), findsNothing);
    await teardown(tester);
  });

  testWidgets('income hero amount has no + sign', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    final repo = AppRepository(db);
    late String id;
    await tester.runAsync(() async {
      final cats = await repo.watchCategories().first;
      final incomeCat = cats.firstWhere((c) => c.type == CategoryType.income);
      final wallets = await repo.watchWallets().first;
      final t = await repo.addTransaction(
          amount: 1000000,
          type: TransactionType.income,
          categoryId: incomeCat.id,
          walletId: wallets.first.id);
      id = t.id;
    });
    await pumpDetail(tester, db, id);

    expect(find.text('1.000.000 ₫'), findsWidgets);
    expect(find.textContaining('+1.000.000'), findsNothing);
    expect(find.text('Khoản thu'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('note empty → no Ghi chú group', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    final repo = AppRepository(db);
    late String id;
    await tester.runAsync(() async {
      final cats = await repo.watchCategories().first;
      final anUong = cats.firstWhere((c) => c.name == 'Ăn uống');
      final wallets = await repo.watchWallets().first;
      final t = await repo.addTransaction(
          amount: 12000,
          type: TransactionType.expense,
          categoryId: anUong.id,
          walletId: wallets.first.id);
      id = t.id;
    });
    await pumpDetail(tester, db, id);

    expect(find.text('Ghi chú'), findsNothing);
    await teardown(tester);
  });

  testWidgets('transfer: no Danh mục, Từ ví + Đến ví, Chuyển ví', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    final repo = AppRepository(db);
    late String id;
    await tester.runAsync(() async {
      await repo.addWallet(
          name: 'Ngân hàng', type: WalletType.bank, initialBalance: 0);
      final wallets = await repo.watchWallets().first;
      final t = await repo.addTransaction(
          amount: 200000,
          type: TransactionType.transfer,
          walletId: wallets[0].id,
          toWalletId: wallets[1].id);
      id = t.id;
    });
    await pumpDetail(tester, db, id);

    expect(find.text('Danh mục'), findsNothing);
    expect(find.text('Từ ví'), findsOneWidget);
    expect(find.text('Đến ví'), findsOneWidget);
    expect(find.text('Chuyển ví'), findsWidgets);
    await teardown(tester);
  });

  testWidgets('transfer with a deleted destination wallet shows —',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    final repo = AppRepository(db);
    late String id;
    await tester.runAsync(() async {
      await repo.addWallet(
          name: 'Ngân hàng', type: WalletType.bank, initialBalance: 0);
      final wallets = await repo.watchWallets().first;
      final t = await repo.addTransaction(
          amount: 200000,
          type: TransactionType.transfer,
          walletId: wallets[0].id,
          toWalletId: wallets[1].id);
      id = t.id;
      await repo.softDeleteWallet(wallets[1].id);
      await repo.restoreTransaction(t.id);
    });
    await pumpDetail(tester, db, id);

    expect(find.text('Đến ví'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    await teardown(tester);
  });

  testWidgets('Sửa opens the edit screen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    final repo = AppRepository(db);
    late String id;
    await tester.runAsync(() async {
      final cats = await repo.watchCategories().first;
      final anUong = cats.firstWhere((c) => c.name == 'Ăn uống');
      final wallets = await repo.watchWallets().first;
      final t = await repo.addTransaction(
          amount: 50000,
          type: TransactionType.expense,
          categoryId: anUong.id,
          walletId: wallets.first.id);
      id = t.id;
    });
    await pumpDetail(tester, db, id);

    await tester.tap(find.byKey(const Key('editTxn')));
    await tester.pumpAndSettle();
    expect(find.byType(AddTransactionScreen), findsOneWidget);
    expect(find.text('Sửa giao dịch'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('Xoá soft-deletes, pops, shows undo snackbar clearing the pill',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    final repo = AppRepository(db);
    late String id;
    await tester.runAsync(() async {
      final cats = await repo.watchCategories().first;
      final anUong = cats.firstWhere((c) => c.name == 'Ăn uống');
      final wallets = await repo.watchWallets().first;
      final t = await repo.addTransaction(
          amount: 50000,
          type: TransactionType.expense,
          categoryId: anUong.id,
          walletId: wallets.first.id);
      id = t.id;
    });
    await pumpDetail(tester, db, id);

    await tester.tap(find.byKey(const Key('deleteTxn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('open'), findsOneWidget);
    // The pop animation can briefly render the messenger's SnackBar in both the
    // exiting and entering Scaffolds; read the first (both carry the same margin).
    final snack = tester.widgetList<SnackBar>(find.byType(SnackBar)).first;
    expect((snack.margin as EdgeInsets).bottom, greaterThanOrEqualTo(96));
    final remaining =
        await tester.runAsync(() => repo.watchAllTransactions().first);
    expect(remaining, isEmpty);
    await teardown(tester);
  });

  testWidgets('deleting never flashes the not-found error', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    final repo = AppRepository(db);
    late String id;
    await tester.runAsync(() async {
      final cats = await repo.watchCategories().first;
      final anUong = cats.firstWhere((c) => c.name == 'Ăn uống');
      final wallets = await repo.watchWallets().first;
      final t = await repo.addTransaction(
          amount: 50000,
          type: TransactionType.expense,
          categoryId: anUong.id,
          walletId: wallets.first.id);
      id = t.id;
    });
    await pumpDetail(tester, db, id);

    await tester.tap(find.byKey(const Key('deleteTxn')));
    await tester.pump();
    expect(find.text('Giao dịch không tồn tại'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    await teardown(tester);
  });
}
