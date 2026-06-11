import 'package:moneynote/data/database.dart';

class DayGroup {
  final String label;
  final List<Transaction> txns;
  const DayGroup(this.label, this.txns);
}

/// Nhóm giao dịch (đã sort mới trước) theo ngày, nhãn thân thiện theo [today].
List<DayGroup> groupByDay(List<Transaction> txns, DateTime today) {
  final groups = <DayGroup>[];
  DateTime? currentDay;
  for (final t in txns) {
    final d = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
    if (currentDay == null || d != currentDay) {
      currentDay = d;
      groups.add(DayGroup(_label(d, today), []));
    }
    groups.last.txns.add(t);
  }
  return groups;
}

String _label(DateTime d, DateTime today) {
  final t = DateTime(today.year, today.month, today.day);
  if (d == t) return 'Hôm nay';
  if (d == t.subtract(const Duration(days: 1))) return 'Hôm qua';
  if (d.year == t.year) return '${d.day}/${d.month}';
  return '${d.day}/${d.month}/${d.year}';
}
