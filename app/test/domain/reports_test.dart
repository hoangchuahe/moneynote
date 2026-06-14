import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/report_period.dart';
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
      final r = expenseByCategory(txns, ReportPeriod.month(DateTime(2026, 6, 1)));
      expect(r.map((e) => e.categoryId).toList(), ['move', 'food']);
      expect(r.first.total, 90000);
      expect(r[1].total, 80000);
    });

    test('expense without category goes to a null bucket', () {
      final r = expenseByCategory([etx(40000, null, DateTime(2026, 6, 5))],
          ReportPeriod.month(DateTime(2026, 6, 1)));
      expect(r.single.categoryId, isNull);
      expect(r.single.total, 40000);
    });

    test('respects month boundaries', () {
      final txns = [
        etx(11111, 'food', DateTime(2026, 5, 31)),
        etx(22222, 'food', DateTime(2026, 6, 1)),
        etx(33333, 'food', DateTime(2026, 7, 1)),
      ];
      expect(
          expenseByCategory(txns, ReportPeriod.month(DateTime(2026, 6, 1)))
              .single
              .total,
          22222);
    });

    test('a quarter window spans its three months', () {
      final txns = [
        etx(1000, 'food', DateTime(2026, 3, 31)), // Q1 — out
        etx(2000, 'food', DateTime(2026, 4, 1)), // Q2 — in
        etx(4000, 'food', DateTime(2026, 5, 15)), // Q2 — in
        etx(8000, 'food', DateTime(2026, 7, 1)), // Q3 — out
      ];
      expect(
          expenseByCategory(txns, ReportPeriod.quarter(DateTime(2026, 6, 1)))
              .single
              .total,
          6000);
    });

    test('empty when no expense in period', () {
      expect(expenseByCategory([], ReportPeriod.month(DateTime(2026, 6, 1))),
          isEmpty);
    });
  });

  group('monthlyFlow', () {
    test('returns N months ending at endMonth, oldest first', () {
      final r = monthlyFlow([], DateTime(2026, 6, 1), months: 6);
      expect(r.length, 6);
      expect(r.first.month, DateTime(2026, 1, 1));
      expect(r.last.month, DateTime(2026, 6, 1));
    });

    test('income and expense per month, transfers excluded', () {
      final txns = [
        etx(5000000, 'salary', DateTime(2026, 6, 5),
            type: TransactionType.income),
        etx(200000, 'food', DateTime(2026, 6, 6)),
        etx(1000000, null, DateTime(2026, 6, 7),
            type: TransactionType.transfer),
        etx(300000, 'food', DateTime(2026, 5, 6)),
      ];
      final r = monthlyFlow(txns, DateTime(2026, 6, 1), months: 6);
      final june = r.firstWhere((f) => f.month == DateTime(2026, 6, 1));
      final may = r.firstWhere((f) => f.month == DateTime(2026, 5, 1));
      expect(june.income, 5000000);
      expect(june.expense, 200000); // transfer loại
      expect(may.expense, 300000);
    });

    test('empty months are zero and window crosses the year boundary', () {
      final r = monthlyFlow([], DateTime(2026, 1, 1), months: 3);
      expect(r.map((f) => f.month).toList(),
          [DateTime(2025, 11, 1), DateTime(2025, 12, 1), DateTime(2026, 1, 1)]);
      expect(r.every((f) => f.income == 0 && f.expense == 0), isTrue);
    });
  });

  group('periodFlow', () {
    test('returns N periods ending at end, oldest first', () {
      final r =
          periodFlow([], ReportPeriod.month(DateTime(2026, 6, 1)), count: 6);
      expect(r.length, 6);
      expect(r.first.period.start, DateTime(2026, 1, 1));
      expect(r.last.period.start, DateTime(2026, 6, 1));
    });

    test('income/expense per period, transfers excluded', () {
      final txns = [
        etx(5000000, 'salary', DateTime(2026, 6, 5),
            type: TransactionType.income),
        etx(200000, 'food', DateTime(2026, 6, 6)),
        etx(1000000, null, DateTime(2026, 6, 7), type: TransactionType.transfer),
        etx(300000, 'food', DateTime(2026, 5, 6)),
      ];
      final r =
          periodFlow(txns, ReportPeriod.month(DateTime(2026, 6, 1)), count: 6);
      final june = r.firstWhere((f) => f.period.start == DateTime(2026, 6, 1));
      final may = r.firstWhere((f) => f.period.start == DateTime(2026, 5, 1));
      expect(june.income, 5000000);
      expect(june.expense, 200000); // transfer excluded
      expect(may.expense, 300000);
    });

    test('empty periods are zero and a 3-window crosses the year boundary', () {
      final r =
          periodFlow([], ReportPeriod.month(DateTime(2026, 1, 1)), count: 3);
      expect(r.map((f) => f.period.start).toList(),
          [DateTime(2025, 11, 1), DateTime(2025, 12, 1), DateTime(2026, 1, 1)]);
      expect(r.every((f) => f.income == 0 && f.expense == 0), isTrue);
    });

    test('quarter window sums cross-month expense into one bar', () {
      final txns = [
        etx(2000, 'food', DateTime(2026, 4, 2)),
        etx(4000, 'food', DateTime(2026, 5, 9)),
      ];
      final r = periodFlow(
          txns, ReportPeriod.quarter(DateTime(2026, 6, 1)), count: 6);
      expect(r.last.period.start, DateTime(2026, 4, 1)); // Q2
      expect(r.last.expense, 6000);
    });
  });

  group('flow stats', () {
    final flows = [
      PeriodFlow(ReportPeriod.month(DateTime(2026, 4, 1)), 0, 100000),
      PeriodFlow(ReportPeriod.month(DateTime(2026, 5, 1)), 0, 300000),
      PeriodFlow(ReportPeriod.month(DateTime(2026, 6, 1)), 0, 200000),
    ];
    test('flowAvgExpense rounds the mean; empty → 0', () {
      expect(flowAvgExpense(flows), 200000); // 600000 / 3
      expect(flowAvgExpense([]), 0);
    });
    test('flowPeakExpense returns the max-expense flow; empty → null', () {
      expect(flowPeakExpense(flows)!.period.start, DateTime(2026, 5, 1));
      expect(flowPeakExpense(flows)!.expense, 300000);
      expect(flowPeakExpense([]), isNull);
    });
  });
}
