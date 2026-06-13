import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';

Wallet wallet(String id, {int initial = 0}) => Wallet(
      id: id,
      name: id,
      type: WalletType.cash,
      color: 0xFF0B7A4F,
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

  group('spentInMonth', () {
    Transaction etx(int amount, String? categoryId, DateTime when,
            {TransactionType type = TransactionType.expense}) =>
        Transaction(
          id: '$amount-$categoryId-$when-${type.name}',
          amount: amount,
          type: type,
          categoryId: categoryId,
          walletId: 'w1',
          toWalletId: null,
          note: '',
          occurredAt: when,
          createdAt: when,
          updatedAt: when,
        );

    final month = DateTime(2026, 6, 1);
    final txns = [
      etx(50000, 'food', DateTime(2026, 6, 5)),
      etx(30000, 'food', DateTime(2026, 6, 6)),
      etx(20000, 'move', DateTime(2026, 6, 7)),
      etx(99999, 'food', DateTime(2026, 5, 31)),
      etx(5000000, 'salary', DateTime(2026, 6, 8), type: TransactionType.income),
      etx(1000000, null, DateTime(2026, 6, 9), type: TransactionType.transfer),
    ];

    test('per-category sums only that category expense this month', () {
      expect(spentInMonth(txns, month, categoryId: 'food'), 80000);
      expect(spentInMonth(txns, month, categoryId: 'move'), 20000);
    });

    test('overall (null) sums all expense, excludes income + transfer', () {
      expect(spentInMonth(txns, month), 100000);
    });

    test('respects month boundaries', () {
      expect(spentInMonth(txns, DateTime(2026, 5, 1), categoryId: 'food'), 99999);
    });
  });

  group('categoryTotal', () {
    Transaction ctx(int amount, String? categoryId,
            {TransactionType type = TransactionType.expense}) =>
        Transaction(
          id: '$amount-$categoryId-${type.name}',
          amount: amount,
          type: type,
          categoryId: categoryId,
          walletId: 'w1',
          toWalletId: null,
          note: '',
          occurredAt: DateTime(2026, 6, 10),
          createdAt: DateTime(2026, 6, 10),
          updatedAt: DateTime(2026, 6, 10),
        );

    final txns = [
      ctx(50000, 'food'),
      ctx(30000, 'food'),
      ctx(20000, 'move'),
      ctx(5000000, 'salary', type: TransactionType.income),
      ctx(1000000, null, type: TransactionType.transfer),
    ];

    test('sums only the given category, all-time, type-agnostic', () {
      expect(categoryTotal('food', txns), 80000);
      expect(categoryTotal('salary', txns), 5000000);
    });

    test('excludes other categories and null-category rows', () {
      expect(categoryTotal('move', txns), 20000);
      expect(categoryTotal('nope', txns), 0);
      expect(categoryTotal('food', const []), 0);
    });
  });

  group('inMonth', () {
    final june = DateTime(2026, 6, 1);
    test('start-inclusive, next-month-exclusive', () {
      expect(inMonth(DateTime(2026, 6, 15), june), isTrue);
      expect(inMonth(DateTime(2026, 6, 1), june), isTrue); // boundary in
      expect(inMonth(DateTime(2026, 7, 1), june), isFalse); // boundary out
      expect(inMonth(DateTime(2026, 5, 31), june), isFalse);
    });
  });

  group('BudgetProgress', () {
    test('warn at the 80% boundary', () {
      const p = BudgetProgress(800000, 1000000);
      expect(p.remaining, 200000);
      expect(p.ratio, 0.8);
      expect(p.percent, 80);
      expect(p.level, BudgetLevel.warn);
    });
    test('ok below 80%', () {
      const p = BudgetProgress(500000, 1000000);
      expect(p.level, BudgetLevel.ok);
      expect(p.percent, 50);
    });
    test('over above 100% — remaining negative, percent unclamped', () {
      const p = BudgetProgress(1390000, 1000000);
      expect(p.remaining, -390000);
      expect(p.percent, 139);
      expect(p.level, BudgetLevel.over);
    });
    test('limit <= 0 guard → ratio 0, percent 0, ok', () {
      expect(const BudgetProgress(0, 0).level, BudgetLevel.ok);
      expect(const BudgetProgress(5000, 0).ratio, 0.0);
      expect(const BudgetProgress(5000, 0).percent, 0);
      // spent > limit short-circuits before the ratio guard, so a 0-limit budget
      // with any spending reads as over (mirrors BudgetTile's spent > limit).
      expect(const BudgetProgress(5000, 0).level, BudgetLevel.over);
    });
    test('spent == limit is warn, not over', () {
      expect(const BudgetProgress(1000000, 1000000).level, BudgetLevel.warn);
    });
  });
}
