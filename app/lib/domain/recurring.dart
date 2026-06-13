import 'package:moneynote/data/database.dart';

/// Number of days in [month] (1..12) of [year]. daysInMonth(2024, 2) == 29.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Builds year-month-day, normalizing month overflow/underflow into the year,
/// then CLAMPS the day to the month end (clampedDate(2026, 2, 31) -> 2026-02-28).
DateTime clampedDate(int year, int month, int day) {
  final norm = DateTime(year, month, 1); // DateTime normalizes out-of-range month
  final dim = daysInMonth(norm.year, norm.month);
  return DateTime(norm.year, norm.month, day <= dim ? day : dim);
}

/// Calendar-day gap between two date-only DateTimes, DST-safe (computed in UTC
/// so a spring-forward day cannot truncate a 7-day gap to 6).
int _calendarDaysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

/// [d] (date-only) plus [days] calendar days, returned as a local date-only.
DateTime _addCalendarDays(DateTime d, int days) {
  final u = DateTime.utc(d.year, d.month, d.day).add(Duration(days: days));
  return DateTime(u.year, u.month, u.day);
}

/// Most recent occurrence <= [today] from [start] by [cycle] (date-only).
/// null if start (date) is after today.
DateTime? mostRecentOccurrence(DateTime start, RecurringCycle cycle, DateTime today) {
  final s = DateTime(start.year, start.month, start.day);
  final t = DateTime(today.year, today.month, today.day);
  if (s.isAfter(t)) return null;
  switch (cycle) {
    case RecurringCycle.daily:
      return t;
    case RecurringCycle.weekly:
      final k = _calendarDaysBetween(s, t) ~/ 7;
      return _addCalendarDays(s, 7 * k);
    case RecurringCycle.monthly:
      var diff = (t.year - s.year) * 12 + (t.month - s.month);
      var occ = clampedDate(s.year, s.month + diff, s.day);
      if (occ.isAfter(t)) occ = clampedDate(s.year, s.month + (--diff), s.day);
      return occ;
    case RecurringCycle.yearly:
      var diff = t.year - s.year;
      var occ = clampedDate(s.year + diff, s.month, s.day);
      if (occ.isAfter(t)) occ = clampedDate(s.year + (--diff), s.month, s.day);
      return occ;
  }
}

/// Next occurrence strictly after [today] (for the "Kỳ tới" display).
DateTime nextOccurrenceAfter(DateTime start, RecurringCycle cycle, DateTime today) {
  final s = DateTime(start.year, start.month, start.day);
  final t = DateTime(today.year, today.month, today.day);
  if (s.isAfter(t)) return s;
  switch (cycle) {
    case RecurringCycle.daily:
      return _addCalendarDays(t, 1);
    case RecurringCycle.weekly:
      final k = _calendarDaysBetween(s, t) ~/ 7;
      return _addCalendarDays(s, 7 * (k + 1));
    case RecurringCycle.monthly:
      var diff = (t.year - s.year) * 12 + (t.month - s.month);
      var occ = clampedDate(s.year, s.month + diff, s.day);
      while (!occ.isAfter(t)) {
        occ = clampedDate(s.year, s.month + (++diff), s.day);
      }
      return occ;
    case RecurringCycle.yearly:
      var diff = t.year - s.year;
      var occ = clampedDate(s.year + diff, s.month, s.day);
      while (!occ.isAfter(t)) {
        occ = clampedDate(s.year + (++diff), s.month, s.day);
      }
      return occ;
  }
}
