import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/seed.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('seeds one wallet and the default categories on empty db', () async {
    await seedIfEmpty(db);
    final wallets = await db.select(db.wallets).get();
    final cats = await db.select(db.categories).get();
    expect(wallets, hasLength(1));
    expect(wallets.single.name, 'Tiền mặt');
    expect(cats.length, greaterThanOrEqualTo(8));
    expect(cats.where((c) => c.type == CategoryType.income), isNotEmpty);
    expect(cats.where((c) => c.type == CategoryType.expense), isNotEmpty);
    expect(cats.every((c) => c.isDefault), isTrue);
  });

  test('is idempotent (no duplicates on second run)', () async {
    await seedIfEmpty(db);
    final firstCount = (await db.select(db.wallets).get()).length;
    await seedIfEmpty(db);
    expect((await db.select(db.wallets).get()).length, firstCount);
  });
}
