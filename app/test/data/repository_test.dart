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

  test('soft-deleted wallet disappears from stream', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    expect(await repo.watchWallets().first, hasLength(1));
    await repo.softDeleteWallet(w.id);
    expect(await repo.watchWallets().first, isEmpty);
  });

  test('soft-deleted category disappears from stream', () async {
    final c =
        await repo.addCategory(name: 'X', type: CategoryType.expense);
    expect(await repo.watchCategories().first, hasLength(1));
    await repo.softDeleteCategory(c.id);
    expect(await repo.watchCategories().first, isEmpty);
  });

  test('soft-deleting a wallet also soft-deletes its transactions', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    await repo.addTransaction(
        amount: 1000, type: TransactionType.expense, walletId: w.id);
    expect(await repo.watchAllTransactions().first, hasLength(1));
    await repo.softDeleteWallet(w.id);
    expect(await repo.watchWallets().first, isEmpty);
    expect(await repo.watchAllTransactions().first, isEmpty);
  });

  test('restoreTransaction brings a soft-deleted transaction back', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    final t = await repo.addTransaction(
        amount: 1000, type: TransactionType.expense, walletId: w.id);
    await repo.softDeleteTransaction(t.id);
    expect(await repo.watchAllTransactions().first, isEmpty);
    await repo.restoreTransaction(t.id);
    expect(await repo.watchAllTransactions().first, hasLength(1));
  });

  test('addTransaction rejects transfer without toWallet or with same wallet', () async {
    final a = await repo.addWallet(name: 'A', type: WalletType.cash);
    expect(
      () => repo.addTransaction(
          amount: 1000, type: TransactionType.transfer, walletId: a.id),
      throwsArgumentError,
    );
    expect(
      () => repo.addTransaction(
          amount: 1000, type: TransactionType.transfer, walletId: a.id, toWalletId: a.id),
      throwsArgumentError,
    );
  });

  test('addTransaction accepts a valid transfer', () async {
    final a = await repo.addWallet(name: 'A', type: WalletType.cash);
    final b = await repo.addWallet(name: 'B', type: WalletType.cash);
    final t = await repo.addTransaction(
        amount: 30000, type: TransactionType.transfer, walletId: a.id, toWalletId: b.id);
    expect(t.type, TransactionType.transfer);
    expect(t.toWalletId, b.id);
    expect(t.categoryId, isNull);
  });
}
