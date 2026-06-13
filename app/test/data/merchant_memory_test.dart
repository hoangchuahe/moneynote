import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  late AppDatabase db;
  late AppRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AppRepository(db);
  });
  tearDown(() => db.close());

  test('lookupMerchant returns null when nothing learned', () async {
    expect(await repo.lookupMerchant('highlands'), isNull);
  });

  test('upsert then lookup returns the learned category', () async {
    final c = await repo.addCategory(name: 'Cà phê', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c.id);
    final got = await repo.lookupMerchant('highlands');
    expect(got, isNotNull);
    expect(got!.id, c.id);
  });

  test('upsert twice updates, no duplicate', () async {
    final c1 = await repo.addCategory(name: 'Cà phê', type: CategoryType.expense);
    final c2 = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c1.id);
    await repo.upsertMerchant('highlands', c2.id);
    final got = await repo.lookupMerchant('highlands');
    expect(got!.id, c2.id);
  });

  test('merchant column is unique at the DB level', () async {
    final c = await repo.addCategory(name: 'Cà phê', type: CategoryType.expense);
    final now = DateTime(2026, 6, 11);
    await db.into(db.merchantMemories).insert(MerchantMemoriesCompanion.insert(
        id: 'm1', merchant: 'highlands', categoryId: c.id, createdAt: now, updatedAt: now));
    // a second row with the SAME merchant must violate the unique index
    expect(
      () => db.into(db.merchantMemories).insert(MerchantMemoriesCompanion.insert(
          id: 'm2', merchant: 'highlands', categoryId: c.id, createdAt: now, updatedAt: now)),
      throwsA(anything),
    );
  });

  test('softDeleteCategory soft-deletes the merchant memory pointing to it',
      () async {
    final c = await repo.addCategory(name: 'Cà phê', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c.id);

    await repo.softDeleteCategory(c.id);

    final mem = await (db.select(db.merchantMemories)
          ..where((t) => t.merchant.equals('highlands')))
        .getSingle();
    expect(mem.deletedAt, isNotNull);
  });

  test('softDeleteCategory soft-deletes ALL merchant memories for that category',
      () async {
    final c = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c.id);
    await repo.upsertMerchant('phúc long', c.id);

    await repo.softDeleteCategory(c.id);

    final rows = await (db.select(db.merchantMemories)
          ..where((t) => t.categoryId.equals(c.id)))
        .get();
    expect(rows, hasLength(2));
    expect(rows.every((m) => m.deletedAt != null), isTrue);
  });

  test('re-learning a merchant after its category was deleted still works',
      () async {
    final c1 = await repo.addCategory(name: 'Cà phê', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c1.id);
    await repo.softDeleteCategory(c1.id);

    final c2 = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    await repo.upsertMerchant('highlands', c2.id);

    final got = await repo.lookupMerchant('highlands');
    expect(got, isNotNull);
    expect(got!.id, c2.id);
  });
}
