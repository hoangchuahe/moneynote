/// Number of days in [month] (1..12) of [year]. daysInMonth(2024, 2) == 29.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Builds year-month-day, normalizing month overflow/underflow into the year,
/// then CLAMPS the day to the month end (clampedDate(2026, 2, 31) -> 2026-02-28).
DateTime clampedDate(int year, int month, int day) {
  final norm = DateTime(year, month, 1); // DateTime normalizes out-of-range month
  final dim = daysInMonth(norm.year, norm.month);
  return DateTime(norm.year, norm.month, day <= dim ? day : dim);
}
