import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';

void main() {
  test('Recurrings table round-trips a row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 6, 13);
    await db.into(db.recurrings).insert(RecurringsCompanion.insert(
          id: 'r1',
          amount: 50000,
          type: TransactionType.expense,
          walletId: 'w1',
          cycle: RecurringCycle.monthly,
          startDate: DateTime(2026, 6, 5),
          createdAt: now,
          updatedAt: now,
          note: const Value('Netflix'),
        ));
    final row = await (db.select(db.recurrings)..where((t) => t.id.equals('r1'))).getSingle();
    expect(row.amount, 50000);
    expect(row.type, TransactionType.expense);
    expect(row.cycle, RecurringCycle.monthly);
    expect(row.startDate, DateTime(2026, 6, 5));
    expect(row.lastRunAt, isNull);
    expect(row.deletedAt, isNull);
  });
}
