import 'package:moneynote/data/database.dart';

enum ExportScope {
  thisMonth,

  /// Current month plus the two preceding months (3 months total, current included).
  last3Months,
  thisYear,
  all,
}

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

const _headers = ['Ngày', 'Loại', 'Số tiền', 'Danh mục', 'Ví', 'Ví đích', 'Ghi chú'];

String _typeLabel(TransactionType t) => switch (t) {
      TransactionType.income => 'Thu',
      TransactionType.expense => 'Chi',
      TransactionType.transfer => 'Chuyển khoản',
    };

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// RFC4180: wrap in "..." if the field contains a comma, double-quote, or
/// line break; double any inner double-quotes.
String _csvField(String s) =>
    (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r'))
        ? '"${s.replaceAll('"', '""')}"'
        : s;

/// Builds the CSV text (header + one line per transaction, CRLF-terminated).
/// [txns] must already be filtered + sorted by the caller.
/// [categoryNames]/[walletNames] map id -> display name (from the providers,
/// soft-deleted rows already excluded). A missing category id (null or a
/// soft-deleted category) renders "Chưa phân loại"; a missing wallet id
/// renders "(không rõ)". Transfers have no category column value.
String buildTransactionsCsv(
  List<Transaction> txns, {
  required Map<String, String> categoryNames,
  required Map<String, String> walletNames,
}) {
  final buf = StringBuffer()
    ..write(_headers.map(_csvField).join(','))
    ..write('\r\n');
  for (final t in txns) {
    final isTransfer = t.type == TransactionType.transfer;
    final category =
        isTransfer ? '' : (categoryNames[t.categoryId] ?? 'Chưa phân loại');
    final row = [
      _isoDate(t.occurredAt),
      _typeLabel(t.type),
      t.amount.toString(),
      category,
      walletNames[t.walletId] ?? '(không rõ)',
      t.toWalletId == null ? '' : (walletNames[t.toWalletId] ?? '(không rõ)'),
      t.note,
    ];
    buf
      ..write(row.map(_csvField).join(','))
      ..write('\r\n');
  }
  return buf.toString();
}

/// File name: moneynote-<scope>-<yyyyMMdd>.csv. [now] is passed in for tests.
String exportFilename(ExportScope scope, DateTime now) {
  final slug = switch (scope) {
    ExportScope.thisMonth => 'thismonth',
    ExportScope.last3Months => '3months',
    ExportScope.thisYear => 'thisyear',
    ExportScope.all => 'all',
  };
  final stamp = _isoDate(now).replaceAll('-', '');
  return 'moneynote-$slug-$stamp.csv';
}
