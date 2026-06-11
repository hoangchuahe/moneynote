import 'package:moneynote/data/database.dart';

/// Active filter for the transactions list. All fields combine with AND.
class TxnFilter {
  final String text;
  final Set<String> categoryIds;
  final DateTime? from; // inclusive (caller passes start-of-day)
  final DateTime? to; // inclusive (caller passes end-of-day)
  const TxnFilter({
    this.text = '',
    this.categoryIds = const {},
    this.from,
    this.to,
  });

  bool get isActive =>
      text.trim().isNotEmpty ||
      categoryIds.isNotEmpty ||
      from != null ||
      to != null;

  TxnFilter copyWith({
    String? text,
    Set<String>? categoryIds,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
  }) =>
      TxnFilter(
        text: text ?? this.text,
        categoryIds: categoryIds ?? this.categoryIds,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
      );
}

/// Pure filter over a transaction list. Returns the input unchanged when the
/// filter is not active. Category filter naturally drops transfers (null category).
/// When [categoryNameById] is provided, free text also matches category names.
List<Transaction> filterTransactions(
  List<Transaction> txns,
  TxnFilter f, {
  Map<String, String> categoryNameById = const {},
}) {
  if (!f.isActive) return txns;
  final q = f.text.trim().toLowerCase();
  return txns.where((t) {
    if (q.isNotEmpty &&
        !t.note.toLowerCase().contains(q) &&
        !(categoryNameById[t.categoryId]?.toLowerCase().contains(q) ??
            false)) {
      return false;
    }
    if (f.categoryIds.isNotEmpty &&
        (t.categoryId == null || !f.categoryIds.contains(t.categoryId))) {
      return false;
    }
    if (f.from != null && t.occurredAt.isBefore(f.from!)) return false;
    if (f.to != null && t.occurredAt.isAfter(f.to!)) return false;
    return true;
  }).toList();
}
