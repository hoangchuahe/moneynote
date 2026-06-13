import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';

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
    expect(row.note, 'Netflix');
    expect(row.startDate, DateTime(2026, 6, 5));
    expect(row.lastRunAt, isNull);
    expect(row.deletedAt, isNull);
  });

  group('recurring CRUD', () {
    Future<(AppDatabase, AppRepository)> setup() async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      return (db, AppRepository(db));
    }

    test('addRecurring persists and watchRecurrings returns it', () async {
      final (db, repo) = await setup();
      addTearDown(db.close);
      final w = (await db.select(db.wallets).get()).first;
      final r = await repo.addRecurring(
        amount: 50000, type: TransactionType.expense, walletId: w.id,
        cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5), note: 'Netflix',
      );
      expect(r.amount, 50000);
      expect(r.startDate, DateTime(2026, 6, 5));
      final list = await (db.select(db.recurrings)..where((t) => t.deletedAt.isNull())).get();
      expect(list.length, 1);
    });

    test('addRecurring rejects amount <= 0 and transfer type', () async {
      final (db, repo) = await setup();
      addTearDown(db.close);
      final w = (await db.select(db.wallets).get()).first;
      expect(
        () => repo.addRecurring(amount: 0, type: TransactionType.expense, walletId: w.id,
            cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5)),
        throwsArgumentError,
      );
      expect(
        () => repo.addRecurring(amount: 1000, type: TransactionType.transfer, walletId: w.id,
            cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5)),
        throwsArgumentError,
      );
    });

    test('updateRecurring resets lastRunAt when cycle or startDate changes', () async {
      final (db, repo) = await setup();
      addTearDown(db.close);
      final w = (await db.select(db.wallets).get()).first;
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: w.id, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5));
      await (db.update(db.recurrings)..where((t) => t.id.equals(r.id)))
          .write(RecurringsCompanion(lastRunAt: Value(DateTime(2026, 6, 5))));

      await repo.updateRecurring(r.id, amount: 60000, type: TransactionType.expense,
          walletId: w.id, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5));
      var row = await (db.select(db.recurrings)..where((t) => t.id.equals(r.id))).getSingle();
      expect(row.lastRunAt, DateTime(2026, 6, 5));

      await repo.updateRecurring(r.id, amount: 60000, type: TransactionType.expense,
          walletId: w.id, cycle: RecurringCycle.weekly, startDate: DateTime(2026, 6, 5));
      row = await (db.select(db.recurrings)..where((t) => t.id.equals(r.id))).getSingle();
      expect(row.lastRunAt, isNull);
    });

    test('softDeleteWallet cascades to recurring rules on that wallet', () async {
      final (db, repo) = await setup();
      addTearDown(db.close);
      final w = (await db.select(db.wallets).get()).first;
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: w.id, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5));
      await repo.softDeleteWallet(w.id);
      final row = await (db.select(db.recurrings)..where((t) => t.id.equals(r.id))).getSingle();
      expect(row.deletedAt, isNotNull);
    });
  });
}
