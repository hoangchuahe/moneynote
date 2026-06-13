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

    test('softDeleteRecurring marks the rule deleted and drops it from watch', () async {
      final (db, repo) = await setup();
      addTearDown(db.close);
      final w = (await db.select(db.wallets).get()).first;
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: w.id, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5));
      await repo.softDeleteRecurring(r.id);
      final row = await (db.select(db.recurrings)..where((t) => t.id.equals(r.id))).getSingle();
      expect(row.deletedAt, isNotNull);
      final live = await (db.select(db.recurrings)..where((t) => t.deletedAt.isNull())).get();
      expect(live, isEmpty);
    });
  });

  group('materializeDueRecurrings', () {
    Future<(AppDatabase, AppRepository, String)> setup() async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      final repo = AppRepository(db);
      final w = (await db.select(db.wallets).get()).first;
      return (db, repo, w.id);
    }

    test('creates one txn at the most-recent occurrence and sets lastRunAt', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      final today = DateTime(2026, 6, 13);
      final created = await repo.materializeDueRecurrings(today);
      expect(created, 1);
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.length, 1);
      expect(txns.single.amount, 50000);
      expect(txns.single.occurredAt, DateTime(2026, 6, 5));
      final row = await (db.select(db.recurrings)..where((t) => t.id.equals(r.id))).getSingle();
      expect(row.lastRunAt, DateTime(2026, 6, 5));
    });

    test('is idempotent within the same period', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      final today = DateTime(2026, 6, 13);
      expect(await repo.materializeDueRecurrings(today), 1);
      expect(await repo.materializeDueRecurrings(today), 0);
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.length, 1);
    });

    test('advances to a new period on a later day', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      expect(await repo.materializeDueRecurrings(DateTime(2026, 6, 13)), 1);
      expect(await repo.materializeDueRecurrings(DateTime(2026, 7, 13)), 1);
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.length, 2);
    });

    test('dormant multiple periods still creates exactly one (latest)', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      await (db.update(db.recurrings)..where((t) => t.id.equals(r.id)))
          .write(RecurringsCompanion(lastRunAt: Value(DateTime(2026, 3, 5))));
      final today = DateTime(2026, 6, 13);
      expect(await repo.materializeDueRecurrings(today), 1);
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.length, 1);
      expect(txns.single.occurredAt, DateTime(2026, 6, 5));
    });

    test('future startDate creates nothing', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 12, 5));
      expect(await repo.materializeDueRecurrings(DateTime(2026, 6, 13)), 0);
    });

    test('skips soft-deleted rules', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      await repo.softDeleteRecurring(r.id);
      expect(await repo.materializeDueRecurrings(DateTime(2026, 6, 13)), 0);
    });

    test('materializes only the due rules among several', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5)); // due
      await repo.addRecurring(amount: 99000, type: TransactionType.income,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 12, 5)); // future
      expect(await repo.materializeDueRecurrings(DateTime(2026, 6, 13)), 1);
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.length, 1);
      expect(txns.single.amount, 50000);
    });

    test('weekly cycle materializes at the right occurrence', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      await repo.addRecurring(amount: 30000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.weekly, startDate: DateTime(2026, 6, 6));
      expect(await repo.materializeDueRecurrings(DateTime(2026, 6, 13)), 1);
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.single.occurredAt, DateTime(2026, 6, 13)); // 06-06 + 7 days
    });
  });
}
