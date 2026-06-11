import 'package:moneynote/data/database.dart';

class MonthSummary {
  final int income;
  final int expense;
  const MonthSummary({required this.income, required this.expense});
  int get net => income - expense;
}

/// Current balance of [wallet] given all (non-deleted) [txns].
/// Caller must pass only non-deleted transactions.
int balanceOf(Wallet wallet, List<Transaction> txns) {
  var bal = wallet.initialBalance;
  for (final t in txns) {
    switch (t.type) {
      case TransactionType.income:
        if (t.walletId == wallet.id) bal += t.amount;
      case TransactionType.expense:
        if (t.walletId == wallet.id) bal -= t.amount;
      case TransactionType.transfer:
        if (t.walletId == wallet.id) bal -= t.amount;
        if (t.toWalletId == wallet.id) bal += t.amount;
    }
  }
  return bal;
}

/// Total EXPENSE in the calendar month of [month]. categoryId null = all expense
/// (for an overall budget); non-null = that category's expense. Income/transfer excluded.
int spentInMonth(List<Transaction> txns, DateTime month, {String? categoryId}) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  var sum = 0;
  for (final t in txns) {
    if (t.occurredAt.isBefore(start) || !t.occurredAt.isBefore(end)) continue;
    if (t.type != TransactionType.expense) continue;
    if (categoryId != null && t.categoryId != categoryId) continue;
    sum += t.amount;
  }
  return sum;
}

/// Income/expense totals for the calendar month containing [month].
/// Transfers are intentionally excluded — they are not income or expense.
MonthSummary summarize(List<Transaction> txns, DateTime month) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  var income = 0;
  var expense = 0;
  for (final t in txns) {
    if (t.occurredAt.isBefore(start) || !t.occurredAt.isBefore(end)) continue;
    if (t.type == TransactionType.income) income += t.amount;
    if (t.type == TransactionType.expense) expense += t.amount;
  }
  return MonthSummary(income: income, expense: expense);
}
