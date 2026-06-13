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

  group('buildTransactionsCsv', () {
    const cats = {'food': 'Ăn uống', 'salary': 'Lương'};
    const wallets = {'w1': 'Tiền mặt', 'w2': 'Vietcombank'};

    test('header row is the fixed column order, CRLF-terminated', () {
      final csv = buildTransactionsCsv([], categoryNames: cats, walletNames: wallets);
      expect(csv, 'Ngày,Loại,Số tiền,Danh mục,Ví,Ví đích,Ghi chú\r\n');
    });

    test('expense row: ISO date (no time), label, raw amount, names', () {
      final csv = buildTransactionsCsv([
        tx(amount: 50000, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', note: 'Phở', when: DateTime(2026, 6, 10, 9, 30)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('2026-06-10,Chi,50000,Ăn uống,Tiền mặt,,Phở\r\n'));
    });

    test('income label', () {
      final csv = buildTransactionsCsv([
        tx(amount: 9000000, type: TransactionType.income, categoryId: 'salary', walletId: 'w2', when: DateTime(2026, 6, 1)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('2026-06-01,Thu,9000000,Lương,Vietcombank,,\r\n'));
    });

    test('transfer: blank category, dest wallet filled', () {
      final csv = buildTransactionsCsv([
        tx(amount: 200000, type: TransactionType.transfer, categoryId: null, walletId: 'w1', toWalletId: 'w2', when: DateTime(2026, 6, 5)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('2026-06-05,Chuyển khoản,200000,,Tiền mặt,Vietcombank,\r\n'));
    });

    test('null/unknown category -> Chưa phân loại; unknown wallet -> (không rõ)', () {
      final csv = buildTransactionsCsv([
        tx(amount: 1000, type: TransactionType.expense, categoryId: null, walletId: 'wX', when: DateTime(2026, 6, 2)),
        tx(amount: 2000, type: TransactionType.expense, categoryId: 'gone', walletId: 'w1', when: DateTime(2026, 6, 3)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('2026-06-02,Chi,1000,Chưa phân loại,(không rõ),,\r\n'));
      expect(csv, contains('2026-06-03,Chi,2000,Chưa phân loại,Tiền mặt,,\r\n'));
    });

    test('RFC4180 quoting for note with comma, quote, newline', () {
      final csv = buildTransactionsCsv([
        tx(amount: 1, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', note: 'cà phê, bánh', when: DateTime(2026, 6, 4)),
        tx(amount: 2, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', note: 'nói "ngon"', when: DateTime(2026, 6, 5)),
        tx(amount: 3, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', note: 'dòng1\ndòng2', when: DateTime(2026, 6, 6)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('"cà phê, bánh"'));
      expect(csv, contains('"nói ""ngon"""'));
      expect(csv, contains('"dòng1\ndòng2"'));
    });

    test('rows preserve input order; header is line 0', () {
      final csv = buildTransactionsCsv([
        tx(amount: 111, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', when: DateTime(2026, 6, 7)),
        tx(amount: 222, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', when: DateTime(2026, 6, 8)),
      ], categoryNames: cats, walletNames: wallets);
      final lines = csv.split('\r\n');
      expect(lines[0], 'Ngày,Loại,Số tiền,Danh mục,Ví,Ví đích,Ghi chú');
      expect(lines[1], startsWith('2026-06-07,Chi,111'));
      expect(lines[2], startsWith('2026-06-08,Chi,222'));
    });
  });

  group('exportFilename', () {
    test('slug + yyyyMMdd stamp', () {
      expect(exportFilename(ExportScope.all, DateTime(2026, 6, 13)), 'moneynote-all-20260613.csv');
      expect(exportFilename(ExportScope.thisMonth, DateTime(2026, 12, 9)), 'moneynote-thismonth-20261209.csv');
      expect(exportFilename(ExportScope.last3Months, DateTime(2026, 1, 1)), 'moneynote-3months-20260101.csv');
      expect(exportFilename(ExportScope.thisYear, DateTime(2026, 6, 13)), 'moneynote-thisyear-20260613.csv');
    });
  });
}
