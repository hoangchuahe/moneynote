import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';

Wallet wallet(String id, {int initial = 0}) => Wallet(
      id: id,
      name: id,
      type: WalletType.cash,
      initialBalance: initial,
      currencyCode: 'VND',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Transaction txn({
  required int amount,
  required TransactionType type,
  required String walletId,
  String? toWalletId,
  DateTime? occurredAt,
}) =>
    Transaction(
      id: '$walletId-$amount-${type.name}-${occurredAt ?? ''}',
      amount: amount,
      type: type,
      categoryId: null,
      walletId: walletId,
      toWalletId: toWalletId,
      note: '',
      occurredAt: occurredAt ?? DateTime(2026, 6, 10),
      createdAt: DateTime(2026, 6, 10),
      updatedAt: DateTime(2026, 6, 10),
    );

void main() {
  group('balanceOf', () {
    test('initial balance + income - expense', () {
      final w = wallet('w1', initial: 100000);
      final txns = [
        txn(amount: 50000, type: TransactionType.income, walletId: 'w1'),
        txn(amount: 20000, type: TransactionType.expense, walletId: 'w1'),
      ];
      expect(balanceOf(w, txns), 130000);
    });

    test('transfer leaves source and enters destination', () {
      final w1 = wallet('w1', initial: 100000);
      final w2 = wallet('w2', initial: 0);
      final txns = [
        txn(
            amount: 30000,
            type: TransactionType.transfer,
            walletId: 'w1',
            toWalletId: 'w2'),
      ];
      expect(balanceOf(w1, txns), 70000);
      expect(balanceOf(w2, txns), 30000);
    });

    test('ignores transactions of other wallets', () {
      final w1 = wallet('w1', initial: 0);
      final txns = [
        txn(amount: 50000, type: TransactionType.income, walletId: 'w2'),
      ];
      expect(balanceOf(w1, txns), 0);
    });
  });

  group('summarize', () {
    test('sums income and expense, EXCLUDES transfers', () {
      final month = DateTime(2026, 6, 1);
      final txns = [
        txn(
            amount: 5000000,
            type: TransactionType.income,
            walletId: 'w1',
            occurredAt: DateTime(2026, 6, 5)),
        txn(
            amount: 200000,
            type: TransactionType.expense,
            walletId: 'w1',
            occurredAt: DateTime(2026, 6, 6)),
        txn(
            amount: 1000000,
            type: TransactionType.transfer,
            walletId: 'w1',
            toWalletId: 'w2',
            occurredAt: DateTime(2026, 6, 7)),
      ];
      final s = summarize(txns, month);
      expect(s.income, 5000000);
      expect(s.expense, 200000);
      expect(s.net, 4800000);
    });

    test('only counts the given month', () {
      final month = DateTime(2026, 6, 1);
      final txns = [
        txn(
            amount: 100000,
            type: TransactionType.expense,
            walletId: 'w1',
            occurredAt: DateTime(2026, 5, 31)),
        txn(
            amount: 200000,
            type: TransactionType.expense,
            walletId: 'w1',
            occurredAt: DateTime(2026, 7, 1)),
        txn(
            amount: 300000,
            type: TransactionType.expense,
            walletId: 'w1',
            occurredAt: DateTime(2026, 6, 15)),
      ];
      expect(summarize(txns, month).expense, 300000);
    });
  });
}
