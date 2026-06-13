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
  var sum = 0;
  for (final t in txns) {
    if (!inMonth(t.occurredAt, month)) continue;
    if (t.type != TransactionType.expense) continue;
    if (categoryId != null && t.categoryId != categoryId) continue;
    sum += t.amount;
  }
  return sum;
}

/// Income/expense totals for the calendar month containing [month].
/// Transfers are intentionally excluded — they are not income or expense.
MonthSummary summarize(List<Transaction> txns, DateTime month) {
  var income = 0;
  var expense = 0;
  for (final t in txns) {
    if (!inMonth(t.occurredAt, month)) continue;
    if (t.type == TransactionType.income) income += t.amount;
    if (t.type == TransactionType.expense) expense += t.amount;
  }
  return MonthSummary(income: income, expense: expense);
}

/// All-time total of [categoryId]'s transactions in [txns]. Caller passes only
/// non-deleted txns (e.g. from transactionsProvider). A category is single-typed,
/// so a plain amount sum is its Chi-or-Thu total; sign/colour come from the
/// category's type at the call site, not from here.
int categoryTotal(String categoryId, List<Transaction> txns) {
  var sum = 0;
  for (final t in txns) {
    if (t.categoryId == categoryId) sum += t.amount;
  }
  return sum;
}

/// True if [when] falls in the calendar month containing [month]
/// (start-inclusive, next-month-exclusive — the window spentInMonth uses).
bool inMonth(DateTime when, DateTime month) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  return !when.isBefore(start) && when.isBefore(end);
}

enum BudgetLevel { ok, warn, over }

/// Spent-vs-limit progress for one budget in a month. Pure; colour *values* are
/// mapped in the UI (budgetLevelColor), not here.
class BudgetProgress {
  final int spent;
  final int limit;
  const BudgetProgress(this.spent, this.limit);

  int get remaining => limit - spent;
  double get ratio => limit <= 0 ? 0.0 : spent / limit; // unclamped
  int get percent => (ratio * 100).round();
  BudgetLevel get level => spent > limit
      ? BudgetLevel.over
      : (ratio >= 0.8 ? BudgetLevel.warn : BudgetLevel.ok);
}
