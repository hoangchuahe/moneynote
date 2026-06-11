import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('can insert and read a wallet', () async {
    final now = DateTime(2026, 6, 11);
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'w1',
          name: 'Tiền mặt',
          type: WalletType.cash,
          createdAt: now,
          updatedAt: now,
        ));

    final wallets = await db.select(db.wallets).get();
    expect(wallets, hasLength(1));
    expect(wallets.single.name, 'Tiền mặt');
    expect(wallets.single.type, WalletType.cash);
    expect(wallets.single.currencyCode, 'VND');
  });
}
