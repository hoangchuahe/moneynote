import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  test('addWallet stores the given color', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final w = await AppRepository(db)
        .addWallet(name: 'A', type: WalletType.bank, color: 0xFF2A6FDB);
    expect(w.color, 0xFF2A6FDB);
  });

  test('addWallet defaults to emerald when color omitted', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final w = await AppRepository(db).addWallet(name: 'A', type: WalletType.cash);
    expect(w.color, 0xFF0B7A4F);
  });

  test('updateWallet changes name/type/color, bumps updatedAt, keeps the rest',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = AppRepository(db);
    final w = await repo.addWallet(
        name: 'Old',
        type: WalletType.cash,
        initialBalance: 5000,
        color: 0xFF0B7A4F);
    await Future<void>.delayed(const Duration(seconds: 2));
    await repo.updateWallet(
        id: w.id, name: 'New', type: WalletType.bank, color: 0xFFE0457B);
    final all = await db.select(db.wallets).get();
    expect(all, hasLength(1));
    final u = all.single;
    expect(u.name, 'New');
    expect(u.type, WalletType.bank);
    expect(u.color, 0xFFE0457B);
    expect(u.initialBalance, 5000);
    expect(u.createdAt, w.createdAt);
    expect(u.updatedAt.isAfter(w.updatedAt), isTrue);
  });
}
