import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/recurring.dart';

void main() {
  group('daysInMonth', () {
    test('common months', () {
      expect(daysInMonth(2026, 1), 31);
      expect(daysInMonth(2026, 4), 30);
    });
    test('February leap vs non-leap', () {
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2025, 2), 28);
    });
  });

  group('clampedDate', () {
    test('clamps an overlong day to month end', () {
      expect(clampedDate(2026, 2, 31), DateTime(2026, 2, 28));
      expect(clampedDate(2024, 2, 31), DateTime(2024, 2, 29));
      expect(clampedDate(2026, 4, 31), DateTime(2026, 4, 30));
    });
    test('keeps a valid day', () {
      expect(clampedDate(2026, 6, 5), DateTime(2026, 6, 5));
    });
    test('normalizes month overflow into the next year', () {
      expect(clampedDate(2026, 13, 10), DateTime(2027, 1, 10));
    });
    test('normalizes month underflow into the previous year', () {
      expect(clampedDate(2026, 0, 10), DateTime(2025, 12, 10));
    });
  });

  group('mostRecentOccurrence', () {
    test('daily returns today when started in the past', () {
      expect(mostRecentOccurrence(DateTime(2026, 6, 1), RecurringCycle.daily, DateTime(2026, 6, 13)),
          DateTime(2026, 6, 13));
    });
    test('daily/weekly start == today returns today/start', () {
      expect(mostRecentOccurrence(DateTime(2026, 6, 13), RecurringCycle.daily, DateTime(2026, 6, 13)),
          DateTime(2026, 6, 13));
      expect(mostRecentOccurrence(DateTime(2026, 6, 13), RecurringCycle.weekly, DateTime(2026, 6, 13)),
          DateTime(2026, 6, 13));
    });
    test('weekly steps in exact 7-calendar-day multiples', () {
      final start = DateTime(2026, 6, 1);
      expect(mostRecentOccurrence(start, RecurringCycle.weekly, DateTime(2026, 6, 7)), DateTime(2026, 6, 1));
      expect(mostRecentOccurrence(start, RecurringCycle.weekly, DateTime(2026, 6, 8)), DateTime(2026, 6, 8));
      expect(mostRecentOccurrence(start, RecurringCycle.weekly, DateTime(2026, 6, 21)), DateTime(2026, 6, 15));
    });
    test('monthly anchored on the 31st clamps and tracks most-recent', () {
      final s = DateTime(2026, 1, 31);
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 2, 15)), DateTime(2026, 1, 31));
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 2, 28)), DateTime(2026, 2, 28));
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 3, 1)), DateTime(2026, 2, 28));
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 3, 31)), DateTime(2026, 3, 31));
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 4, 30)), DateTime(2026, 4, 30));
    });
    test('yearly leap-day anchor clamps to Feb 28 in non-leap years', () {
      final s = DateTime(2024, 2, 29);
      expect(mostRecentOccurrence(s, RecurringCycle.yearly, DateTime(2025, 2, 28)), DateTime(2025, 2, 28));
      expect(mostRecentOccurrence(s, RecurringCycle.yearly, DateTime(2025, 3, 1)), DateTime(2025, 2, 28));
      expect(mostRecentOccurrence(s, RecurringCycle.yearly, DateTime(2028, 3, 1)), DateTime(2028, 2, 29));
    });
    test('returns null when start is after today', () {
      expect(mostRecentOccurrence(DateTime(2026, 7, 1), RecurringCycle.daily, DateTime(2026, 6, 13)), isNull);
      expect(mostRecentOccurrence(DateTime(2026, 7, 1), RecurringCycle.monthly, DateTime(2026, 6, 13)), isNull);
    });
    test('monthly occurrence sequence (day 31) strictly increases by full date', () {
      final s = DateTime(2026, 1, 31);
      final seq = [
        for (final t in [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 30)])
          mostRecentOccurrence(s, RecurringCycle.monthly, t)!
      ];
      for (var i = 1; i < seq.length; i++) {
        expect(seq[i].isAfter(seq[i - 1]), isTrue);
      }
    });
  });

  group('nextOccurrenceAfter', () {
    test('daily is tomorrow', () {
      expect(nextOccurrenceAfter(DateTime(2026, 6, 1), RecurringCycle.daily, DateTime(2026, 6, 13)),
          DateTime(2026, 6, 14));
    });
    test('weekly is the next 7-day boundary', () {
      final s = DateTime(2026, 6, 1);
      expect(nextOccurrenceAfter(s, RecurringCycle.weekly, DateTime(2026, 6, 7)), DateTime(2026, 6, 8));
      expect(nextOccurrenceAfter(s, RecurringCycle.weekly, DateTime(2026, 6, 8)), DateTime(2026, 6, 15));
    });
    test('monthly clamp: start Jan 31, today Feb 28 -> Mar 31', () {
      expect(nextOccurrenceAfter(DateTime(2026, 1, 31), RecurringCycle.monthly, DateTime(2026, 2, 28)),
          DateTime(2026, 3, 31));
    });
    test('yearly Feb-29 anchor: today 2025-02-28 -> 2026-02-28', () {
      expect(nextOccurrenceAfter(DateTime(2024, 2, 29), RecurringCycle.yearly, DateTime(2025, 2, 28)),
          DateTime(2026, 2, 28));
    });
    test('not yet started returns the start date', () {
      expect(nextOccurrenceAfter(DateTime(2026, 7, 1), RecurringCycle.monthly, DateTime(2026, 6, 13)),
          DateTime(2026, 7, 1));
    });
  });
}
