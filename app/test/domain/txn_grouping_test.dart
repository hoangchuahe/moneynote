import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/txn_grouping.dart';

Transaction _txn(String id, DateTime at) => Transaction(
      id: id,
      amount: 1000,
      type: TransactionType.expense,
      categoryId: null,
      walletId: 'w1',
      toWalletId: null,
      note: '',
      occurredAt: at,
      createdAt: at,
      updatedAt: at,
    );

void main() {
  test('nhóm theo ngày với nhãn Hôm nay / Hôm qua / d/M / d/M/yyyy', () {
    final today = DateTime(2026, 6, 12);
    final groups = groupByDay([
      _txn('1', DateTime(2026, 6, 12, 9)),
      _txn('2', DateTime(2026, 6, 12, 7)),
      _txn('3', DateTime(2026, 6, 11)),
      _txn('4', DateTime(2026, 5, 30)),
      _txn('5', DateTime(2025, 12, 31)),
    ], today);
    expect(groups.map((g) => g.label),
        ['Hôm nay', 'Hôm qua', '30/5', '31/12/2025']);
    expect(groups.first.txns, hasLength(2));
  });

  test('danh sách rỗng trả về rỗng', () {
    expect(groupByDay(const [], DateTime(2026, 6, 12)), isEmpty);
  });
}
