import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/csv_export.dart';

Transaction tx({
  required int amount,
  required TransactionType type,
  String? categoryId,
  String walletId = 'w1',
  String? toWalletId,
  String note = '',
  required DateTime when,
}) =>
    Transaction(
      id: '$amount-$when-${type.name}',
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      toWalletId: toWalletId,
      note: note,
      occurredAt: when,
      createdAt: when,
      updatedAt: when,
    );

void main() {
  group('exportRange', () {
    final anchor = DateTime(2026, 6, 13);

    test('thisMonth = [first of month, first of next month)', () {
      final r = exportRange(ExportScope.thisMonth, anchor);
      expect(r.start, DateTime(2026, 6, 1));
      expect(r.end, DateTime(2026, 7, 1));
    });

    test('last3Months spans 3 months ending this month', () {
      final r = exportRange(ExportScope.last3Months, anchor);
      expect(r.start, DateTime(2026, 4, 1));
      expect(r.end, DateTime(2026, 7, 1));
    });

    test('last3Months crosses the year boundary', () {
      final r = exportRange(ExportScope.last3Months, DateTime(2026, 1, 15));
      expect(r.start, DateTime(2025, 11, 1));
      expect(r.end, DateTime(2026, 2, 1));
    });

    test('thisYear = whole calendar year', () {
      final r = exportRange(ExportScope.thisYear, anchor);
      expect(r.start, DateTime(2026, 1, 1));
      expect(r.end, DateTime(2027, 1, 1));
    });

    test('all = unbounded', () {
      final r = exportRange(ExportScope.all, anchor);
      expect(r.start, isNull);
      expect(r.end, isNull);
    });
  });

  group('filterByRange', () {
    final txns = [
      tx(amount: 1, type: TransactionType.expense, when: DateTime(2026, 5, 31)),
      tx(amount: 2, type: TransactionType.expense, when: DateTime(2026, 6, 1)),
      tx(amount: 3, type: TransactionType.expense, when: DateTime(2026, 6, 30)),
      tx(amount: 4, type: TransactionType.expense, when: DateTime(2026, 7, 1)),
    ];

    test('start inclusive, end exclusive', () {
      final r = filterByRange(txns, DateTime(2026, 6, 1), DateTime(2026, 7, 1));
      expect(r.map((t) => t.amount).toList(), [2, 3]);
    });

    test('null bounds do not constrain', () {
      expect(filterByRange(txns, null, null).length, 4);
      expect(filterByRange(txns, null, DateTime(2026, 6, 1)).map((t) => t.amount).toList(), [1]);
      expect(filterByRange(txns, DateTime(2026, 7, 1), null).map((t) => t.amount).toList(), [4]);
    });
  });
}
