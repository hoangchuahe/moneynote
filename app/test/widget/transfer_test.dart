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

    await tester.tap(find.text('Chuyển'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('amountField')), '30000');
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
