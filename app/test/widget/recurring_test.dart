import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/recurring/recurring_edit_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('RecurringEditScreen adds a rule', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: RecurringEditScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('recurringAmount')), '50000');
    await tester.tap(find.byKey(const Key('recurringSave')));
    await tester.pump(const Duration(milliseconds: 300));

    final rules = await (db.select(db.recurrings)..where((t) => t.deletedAt.isNull())).get();
    expect(rules.length, 1);
    expect(rules.single.amount, 50000);
    expect(rules.single.type, TransactionType.expense);
    expect(rules.single.cycle, RecurringCycle.monthly);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
