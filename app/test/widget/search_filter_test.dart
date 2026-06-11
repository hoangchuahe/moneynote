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
    final w = (await db.select(db.wallets).get()).first; // one-shot (no stream .first in FakeAsync)
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
    // Let the Drift stream deliver the seeded transactions, then render.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.textContaining('taxi'), findsOneWidget);
    expect(find.textContaining('cà phê'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('searchField')), 'cà phê');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('taxi'), findsNothing);
    // 'cà phê' still shows in the LIST — scope past the search field, which now
    // also holds the typed 'cà phê' text (a bare textContaining would match both).
    expect(
      find.descendant(
          of: find.byType(ListView), matching: find.textContaining('cà phê')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
