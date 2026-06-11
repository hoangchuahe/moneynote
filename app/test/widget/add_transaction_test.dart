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

  testWidgets('entering amount + category + save persists a transaction',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);

    // Use a tall surface so all widgets render without scrolling.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AddTransactionScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byKey(const Key('amountField')), '50000');
    await tester.tap(find.byKey(const Key('cat_Ăn uống')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pump(const Duration(milliseconds: 200));

    final txns =
        await tester.runAsync(() => AppRepository(db).watchAllTransactions().first);
    expect(txns, isNotNull);
    expect(txns, hasLength(1));
    expect(txns!.single.amount, 50000);
    expect(txns.single.type, TransactionType.expense);

    // Replace the widget tree to trigger ProviderScope disposal now (inside the
    // test body), then flush Drift's zero-duration cleanup timers before the
    // test framework runs its !timersPending invariant check.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
