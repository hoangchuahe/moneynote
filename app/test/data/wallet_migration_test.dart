import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  test('addColumn backfills existing wallets with the default emerald color',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('ALTER TABLE wallets DROP COLUMN color');
    await db.customStatement(
      "INSERT INTO wallets (id, name, type, initial_balance, currency_code, "
      "created_at, updated_at) VALUES ('w1', 'Ví cũ', 0, 0, 'VND', 0, 0)",
    );
    await db.createMigrator().addColumn(db.wallets, db.wallets.color);
    final w =
        await (db.select(db.wallets)..where((t) => t.id.equals('w1'))).getSingle();
    expect(w.color, 0xFF0B7A4F);
  });
}
