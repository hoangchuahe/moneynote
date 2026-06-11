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

  test('updateTransaction edits fields in place and bumps updatedAt', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    final c1 = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    final c2 = await repo.addCategory(name: 'Đi lại', type: CategoryType.expense);
    final t = await repo.addTransaction(
        amount: 50000,
        type: TransactionType.expense,
        categoryId: c1.id,
        walletId: w.id,
        note: 'phở');

    await repo.updateTransaction(
      t.id,
      amount: 65000,
      type: TransactionType.expense,
      categoryId: c2.id,
      walletId: w.id,
      note: 'phở + trà đá',
      occurredAt: DateTime(2026, 6, 1),
    );

    final all = await repo.watchAllTransactions().first;
    expect(all, hasLength(1)); // edited in place, no duplicate
    final u = all.single;
    expect(u.id, t.id);
    expect(u.amount, 65000);
    expect(u.categoryId, c2.id);
    expect(u.note, 'phở + trà đá');
    expect(u.occurredAt, DateTime(2026, 6, 1));
    expect(u.createdAt, t.createdAt); // creation time preserved
    expect(u.updatedAt.isAfter(t.updatedAt) || u.updatedAt == t.updatedAt, isTrue);
  });

  test('updateTransaction validates like addTransaction', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    final t = await repo.addTransaction(
        amount: 1000, type: TransactionType.expense, walletId: w.id);
    expect(
      () => repo.updateTransaction(t.id,
          amount: 0,
          type: TransactionType.expense,
          walletId: w.id,
          occurredAt: DateTime(2026, 6, 1)),
      throwsArgumentError,
    );
    expect(
      () => repo.updateTransaction(t.id,
          amount: 1000,
          type: TransactionType.transfer,
          walletId: w.id,
          toWalletId: w.id,
          occurredAt: DateTime(2026, 6, 1)),
      throwsArgumentError,
    );
  });

  test('upsertBudget inserts then updates (one per category)', () async {
    final c = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    await repo.upsertBudget(c.id, 2000000);
    var budgets = await repo.watchBudgets().first;
    expect(budgets, hasLength(1));
    expect(budgets.single.amount, 2000000);

    await repo.upsertBudget(c.id, 2500000);
    budgets = await repo.watchBudgets().first;
    expect(budgets, hasLength(1));
    expect(budgets.single.amount, 2500000);
  });

  test('upsertBudget supports an overall (null category) budget', () async {
    await repo.upsertBudget(null, 10000000);
    final budgets = await repo.watchBudgets().first;
    expect(budgets, hasLength(1));
    expect(budgets.single.categoryId, isNull);
    expect(budgets.single.amount, 10000000);
  });

  test('deleteBudget soft-deletes', () async {
    await repo.upsertBudget(null, 10000000);
    final b = (await repo.watchBudgets().first).single;
    await repo.deleteBudget(b.id);
    expect(await repo.watchBudgets().first, isEmpty);
  });

  test('upsertBudget after deleteBudget un-deletes and updates the amount', () async {
    await repo.upsertBudget(null, 5000000);
    final b = (await repo.watchBudgets().first).single;
    await repo.deleteBudget(b.id);
    expect(await repo.watchBudgets().first, isEmpty);
    await repo.upsertBudget(null, 7000000); // re-add same (overall) budget
    final budgets = await repo.watchBudgets().first;
    expect(budgets, hasLength(1)); // un-deleted the existing row, not a duplicate
    expect(budgets.single.amount, 7000000);
  });
}
