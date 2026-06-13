import 'package:moneynote/data/database.dart';

/// Tổng expense của một danh mục trong một tháng. categoryId null = chưa phân loại.
class CategorySpend {
  final String? categoryId;
  final int total; // đồng VND
  const CategorySpend(this.categoryId, this.total);
}

/// Expense theo danh mục trong tháng chứa [month], sắp xếp giảm dần theo total.
/// Loại income + transfer; soft-deleted đã loại sẵn bởi provider.
/// Expense categoryId null gom vào một bucket (categoryId == null).
List<CategorySpend> expenseByCategory(List<Transaction> txns, DateTime month) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final byCat = <String?, int>{};
  for (final t in txns) {
    if (t.type != TransactionType.expense) continue;
    if (t.occurredAt.isBefore(start) || !t.occurredAt.isBefore(end)) continue;
    byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
  }
  final list = byCat.entries.map((e) => CategorySpend(e.key, e.value)).toList();
  list.sort((a, b) => b.total.compareTo(a.total));
  return list;
}
