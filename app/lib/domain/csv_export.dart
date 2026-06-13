import 'package:moneynote/data/database.dart';

enum ExportScope { thisMonth, last3Months, thisYear, all }

/// Half-open range [start, end): start INCLUDED, end EXCLUDED.
/// null bound = unbounded on that side (used by [ExportScope.all]).
/// [anchor] is passed in (no DateTime.now() inside) so it is test-deterministic.
({DateTime? start, DateTime? end}) exportRange(ExportScope scope, DateTime anchor) {
  final y = anchor.year, m = anchor.month;
  switch (scope) {
    case ExportScope.thisMonth:
      return (start: DateTime(y, m, 1), end: DateTime(y, m + 1, 1));
    case ExportScope.last3Months:
      return (start: DateTime(y, m - 2, 1), end: DateTime(y, m + 1, 1));
    case ExportScope.thisYear:
      return (start: DateTime(y, 1, 1), end: DateTime(y + 1, 1, 1));
    case ExportScope.all:
      return (start: null, end: null);
  }
}

/// Returns transactions whose occurredAt is within [start, end).
/// A null bound does not constrain that side.
List<Transaction> filterByRange(
    List<Transaction> txns, DateTime? start, DateTime? end) {
  return txns.where((t) {
    if (start != null && t.occurredAt.isBefore(start)) return false;
    if (end != null && !t.occurredAt.isBefore(end)) return false;
    return true;
  }).toList();
}
