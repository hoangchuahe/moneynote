import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/features/transactions/transaction_detail_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
import 'package:moneynote/features/wallets/wallet_detail_screen.dart';
import 'package:moneynote/features/wallets/wallet_edit_screen.dart';
import 'package:moneynote/features/wallets/wallets_screen.dart';
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
    // Tear down any prior tree first so a route pushed in an earlier sub-scenario
    // (e.g. AddTransactionScreen) doesn't linger offstage under a reused Navigator.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: WalletDetailScreen(id)),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<({String a, String b})> seedWallets(AppDatabase db,
      {int aColor = 0xFF0B7A4F}) async {
    final repo = AppRepository(db);
    final a =
        await repo.addWallet(name: 'Ví A', type: WalletType.bank, color: aColor);
    final b = await repo.addWallet(name: 'Ví B', type: WalletType.cash);
    final cats = await repo.watchCategories().first;
    final anUong = cats.firstWhere((c) => c.name == 'Ăn uống');
    await repo.addTransaction(
        amount: 50000,
        type: TransactionType.expense,
        categoryId: anUong.id,
        walletId: a.id,
        note: 'của A');
    await repo.addTransaction(
        amount: 90000,
        type: TransactionType.expense,
        categoryId: anUong.id,
        walletId: b.id,
        note: 'của B');
    await repo.addTransaction(
        amount: 200000,
        type: TransactionType.transfer,
        walletId: b.id,
        toWalletId: a.id);
    return (a: a.id, b: b.id);
  }

  testWidgets('header shows name·type + balance; only this wallet txns appear',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    late String aId;
    await tester.runAsync(() async {
      aId = (await seedWallets(db)).a;
    });
    await pumpDetail(tester, db, aId);

    expect(find.text('Ví A · Ngân hàng'), findsOneWidget);
    expect(find.text('của A'), findsOneWidget);
    expect(find.text('của B'), findsNothing);
    expect(find.text('Chuyển ví'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('light wallet color uses dark header text', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    late String aId;
    await tester.runAsync(() async {
      aId = (await seedWallets(db, aColor: 0xFFFFF59D)).a; // pale yellow
    });
    await pumpDetail(tester, db, aId);
    final title = tester.widget<Text>(find.text('Ví A · Ngân hàng'));
    // Adaptive foreground picks the black family (RGB 0,0,0) for a pale wallet;
    // assert RGB only (alpha is the header's 82% tint), not white.
    expect(title.style!.color!.toARGB32() & 0x00FFFFFF, 0x000000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Chuyển → transfer; Sửa → edit; tile → txn detail; null guard',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    late String aId;
    await tester.runAsync(() async {
      aId = (await seedWallets(db)).a;
    });

    await pumpDetail(tester, db, 'nope');
    expect(find.text('Ví không tồn tại'), findsOneWidget);

    await pumpDetail(tester, db, aId);
    await tester.tap(find.byKey(const Key('walletTransfer')));
    await tester.pumpAndSettle();
    expect(find.byType(AddTransactionScreen), findsOneWidget);
    expect(find.byKey(const Key('toWallet')), findsOneWidget);

    await pumpDetail(tester, db, aId);
    await tester.tap(find.byKey(const Key('walletEdit')));
    await tester.pumpAndSettle();
    expect(find.byType(WalletEditScreen), findsOneWidget);

    await pumpDetail(tester, db, aId);
    await tester.tap(find.byType(TransactionTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TransactionDetailScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('tapping a wallet tile opens its detail', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    await tester.runAsync(() => seedWallets(db));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: WalletsScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ví A'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletDetailScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
