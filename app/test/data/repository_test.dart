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

  test('addWallet then watchWallets emits it', () async {
    await repo.addWallet(name: 'Tiền mặt', type: WalletType.cash);
    final wallets = await repo.watchWallets().first;
    expect(wallets, hasLength(1));
    expect(wallets.single.name, 'Tiền mặt');
    expect(wallets.single.id, isNotEmpty);
  });

  test('addTransaction sets uuid + timestamps', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    final c = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    final t = await repo.addTransaction(
      amount: 50000,
      type: TransactionType.expense,
      categoryId: c.id,
      walletId: w.id,
      note: 'phở',
    );
    expect(t.id, isNotEmpty);
    expect(t.amount, 50000);
    expect(t.createdAt, isNotNull);
    expect(t.updatedAt, isNotNull);
  });

  test('soft-deleted transactions disappear from the stream', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    final t = await repo.addTransaction(
      amount: 1000,
      type: TransactionType.expense,
      walletId: w.id,
    );
    expect(await repo.watchAllTransactions().first, hasLength(1));
    await repo.softDeleteTransaction(t.id);
    expect(await repo.watchAllTransactions().first, isEmpty);
  });

  test('addTransaction rejects non-positive amount', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    expect(
      () => repo.addTransaction(
          amount: 0, type: TransactionType.expense, walletId: w.id),
      throwsArgumentError,
    );
  });
}
