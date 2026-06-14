import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/report_period.dart';

/// Tổng expense của một danh mục trong một tháng. categoryId null = chưa phân loại.
class CategorySpend {
  final String? categoryId;
  final int total; // đồng VND
  const CategorySpend(this.categoryId, this.total);
}

/// Expense theo danh mục trong [period], sắp xếp giảm dần theo total.
/// Loại income + transfer; soft-deleted đã loại sẵn bởi provider.
/// Expense categoryId null gom vào một bucket (categoryId == null).
List<CategorySpend> expenseByCategory(
    List<Transaction> txns, ReportPeriod period) {
  final byCat = <String?, int>{};
  for (final t in txns) {
    if (t.type != TransactionType.expense) continue;
    if (!period.contains(t.occurredAt)) continue;
    byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
  }
  final list = byCat.entries.map((e) => CategorySpend(e.key, e.value)).toList();
  list.sort((a, b) => b.total.compareTo(a.total));
  return list;
}

/// Thu/chi của một kỳ báo cáo (transfer không tính, như summarize).
class PeriodFlow {
  final ReportPeriod period;
  final int income;
  final int expense;
  const PeriodFlow(this.period, this.income, this.expense);
}

/// [count] kỳ liên tiếp cùng granularity với [end], cũ → mới, kết thúc tại [end].
/// Kỳ rỗng → income = expense = 0. Granularity-agnostic (chỉ dùng period.contains
/// / period.prev), nên dùng chung cho tháng/quý/năm.
List<PeriodFlow> periodFlow(List<Transaction> txns, ReportPeriod end,
    {int count = 6}) {
  final periods = <ReportPeriod>[];
  var p = end;
  for (var i = 0; i < count; i++) {
    periods.add(p);
    p = p.prev;
  }
  final result = <PeriodFlow>[];
  for (final period in periods.reversed) {
    var inc = 0, exp = 0;
    for (final t in txns) {
      if (!period.contains(t.occurredAt)) continue;
      if (t.type == TransactionType.income) {
        inc += t.amount;
      } else if (t.type == TransactionType.expense) {
        exp += t.amount;
      } // transfer: không tính (bài học Money Lover)
    }
    result.add(PeriodFlow(period, inc, exp));
  }
  return result;
}

/// Chi trung bình mỗi kỳ (làm tròn VND); 0 khi rỗng.
int flowAvgExpense(List<PeriodFlow> flows) => flows.isEmpty
    ? 0
    : (flows.fold<int>(0, (s, f) => s + f.expense) / flows.length).round();

/// Kỳ có chi cao nhất (kỳ đầu khi hoà); null khi rỗng.
PeriodFlow? flowPeakExpense(List<PeriodFlow> flows) =>
    flows.isEmpty ? null : flows.reduce((a, b) => b.expense > a.expense ? b : a);
