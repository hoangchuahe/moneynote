import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';

Transaction _txn(TransactionType type, int amount) => Transaction(
      id: 't-${type.name}', amount: amount, type: type,
      categoryId: type == TransactionType.transfer ? null : 'c1',
      walletId: 'w1', toWalletId: null, note: 'ghi chú',
      occurredAt: DateTime(2026, 6, 12), createdAt: DateTime(2026, 6, 12),
      updatedAt: DateTime(2026, 6, 12),
    );

Category get _cat => Category(
      id: 'c1', name: 'Ăn uống', icon: 'restaurant', color: 0xFFEF5350,
      type: CategoryType.expense, isDefault: true,
      createdAt: DateTime(2026, 6, 1), updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildTheme(AppThemeStyle.classic, Brightness.light),
        home: Scaffold(body: child),
      );

  testWidgets('chi: không dấu trừ; thu: có dấu cộng; chuyển: trung tính',
      (tester) async {
    await tester.pumpWidget(host(Column(children: [
      TransactionTile(txn: _txn(TransactionType.expense, 50000), category: _cat),
      TransactionTile(txn: _txn(TransactionType.income, 2000000), category: _cat),
      TransactionTile(txn: _txn(TransactionType.transfer, 300000)),
    ])));

    expect(find.text('50.000 ₫'), findsOneWidget);
    expect(find.text('+2.000.000 ₫'), findsOneWidget);
    expect(find.text('300.000 ₫'), findsOneWidget);
    expect(find.textContaining('-50'), findsNothing);
    expect(find.text('Chuyển ví'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant), findsNWidgets(2));
  });

  testWidgets('không category và không transfer: nhãn Chưa phân loại',
      (tester) async {
    await tester.pumpWidget(host(
        TransactionTile(txn: _txn(TransactionType.expense, 1000))));
    expect(find.text('Chưa phân loại'), findsOneWidget);
  });
}
