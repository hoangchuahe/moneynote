import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/wallets/wallet_edit_screen.dart';
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

  testWidgets('add mode saves name/type/color; balance field present',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: WalletEditScreen()),
    ));
    expect(find.byKey(const Key('walletBalance')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('walletName')), 'Tiền lẻ');
    await tester.tap(find.byKey(const Key('swatch_${0xFFE0457B}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveWallet')));
    await tester.pump(const Duration(milliseconds: 300));

    final wallets = await tester.runAsync(() => repo.watchWallets().first);
    final added = wallets!.firstWhere((w) => w.name == 'Tiền lẻ');
    expect(added.color, 0xFFE0457B);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('edit mode pre-fills, updates in place, no balance field',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    late Wallet existing;
    await tester.runAsync(() async {
      existing = await repo.addWallet(
          name: 'Cũ', type: WalletType.cash, color: 0xFF0B7A4F);
    });
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: WalletEditScreen(existing: existing)),
    ));
    expect(find.byKey(const Key('walletBalance')), findsNothing);
    expect(find.text('Cũ'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('walletName')), 'Mới');
    await tester.tap(find.byKey(const Key('swatch_${0xFF2A6FDB}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveWallet')));
    await tester.pump(const Duration(milliseconds: 300));

    final wallets = await tester.runAsync(() => repo.watchWallets().first);
    expect(wallets!.where((w) => w.name == 'Cũ'), isEmpty);
    final u = wallets.firstWhere((w) => w.id == existing.id);
    expect(u.name, 'Mới');
    expect(u.color, 0xFF2A6FDB);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('empty name does not save and keeps the screen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: WalletEditScreen()),
    ));
    final before = (await tester.runAsync(() => repo.watchWallets().first))!.length;
    await tester.tap(find.byKey(const Key('saveWallet')));
    await tester.pump(const Duration(milliseconds: 300));
    final after = (await tester.runAsync(() => repo.watchWallets().first))!.length;
    expect(after, before);
    expect(find.byType(WalletEditScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
