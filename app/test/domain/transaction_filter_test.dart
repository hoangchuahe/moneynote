import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/transaction_filter.dart';

Transaction txn({
  required String id,
  String note = '',
  String? categoryId,
  required DateTime occurredAt,
}) =>
    Transaction(
      id: id,
      amount: 1000,
      type: TransactionType.expense,
      categoryId: categoryId,
      walletId: 'w1',
      toWalletId: null,
      note: note,
      occurredAt: occurredAt,
      createdAt: occurredAt,
      updatedAt: occurredAt,
    );

void main() {
  final all = [
    txn(id: '1', note: 'cà phê Highlands', categoryId: 'c-food', occurredAt: DateTime(2026, 6, 5)),
    txn(id: '2', note: 'taxi về nhà', categoryId: 'c-move', occurredAt: DateTime(2026, 6, 10)),
    txn(id: '3', note: 'cà phê Trung Nguyên', categoryId: 'c-food', occurredAt: DateTime(2026, 5, 30)),
  ];

  test('empty filter returns all', () {
    expect(filterTransactions(all, const TxnFilter()).length, 3);
    expect(const TxnFilter().isActive, isFalse);
  });

  test('text matches note case-insensitively', () {
    final r = filterTransactions(all, const TxnFilter(text: 'cà phê'));
    expect(r.map((t) => t.id), ['1', '3']);
  });

  test('category filter keeps only matching categories', () {
    final r = filterTransactions(all, const TxnFilter(categoryIds: {'c-food'}));
    expect(r.map((t) => t.id), ['1', '3']);
  });

  test('date range is inclusive', () {
    final r = filterTransactions(
        all, TxnFilter(from: DateTime(2026, 6, 1), to: DateTime(2026, 6, 30)));
    expect(r.map((t) => t.id), ['1', '2']);
  });

  test('filters combine (AND)', () {
    final r = filterTransactions(
        all, TxnFilter(text: 'cà phê', from: DateTime(2026, 6, 1), to: DateTime(2026, 6, 30)));
    expect(r.map((t) => t.id), ['1']);
  });

  test('text also matches the category name when a name map is provided', () {
    final r = filterTransactions(all, const TxnFilter(text: 'ăn uống'),
        categoryNameById: const {'c-food': 'Ăn uống', 'c-move': 'Đi lại'});
    expect(r.map((t) => t.id), ['1', '3']);
  });

  test('without a name map, text only matches notes (unchanged behavior)', () {
    final r = filterTransactions(all, const TxnFilter(text: 'ăn uống'));
    expect(r, isEmpty);
  });
}
