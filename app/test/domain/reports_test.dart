import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/reports.dart';

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

void main() {
  group('expenseByCategory', () {
    test('groups expense by category, sorted desc, excludes income+transfer', () {
      final txns = [
        etx(50000, 'food', DateTime(2026, 6, 5)),
        etx(30000, 'food', DateTime(2026, 6, 6)),
        etx(90000, 'move', DateTime(2026, 6, 7)),
        etx(5000000, 'salary', DateTime(2026, 6, 8), type: TransactionType.income),
        etx(1000000, null, DateTime(2026, 6, 9), type: TransactionType.transfer),
      ];
      final r = expenseByCategory(txns, DateTime(2026, 6, 1));
      expect(r.map((e) => e.categoryId).toList(), ['move', 'food']);
      expect(r.first.total, 90000);
      expect(r[1].total, 80000);
    });

    test('expense without category goes to a null bucket', () {
      final r = expenseByCategory(
          [etx(40000, null, DateTime(2026, 6, 5))], DateTime(2026, 6, 1));
      expect(r.single.categoryId, isNull);
      expect(r.single.total, 40000);
    });

    test('respects month boundaries', () {
      final txns = [
        etx(11111, 'food', DateTime(2026, 5, 31)),
        etx(22222, 'food', DateTime(2026, 6, 1)),
        etx(33333, 'food', DateTime(2026, 7, 1)),
      ];
      expect(expenseByCategory(txns, DateTime(2026, 6, 1)).single.total, 22222);
    });

    test('empty when no expense in month', () {
      expect(expenseByCategory([], DateTime(2026, 6, 1)), isEmpty);
    });
  });
}
