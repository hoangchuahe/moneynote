import 'package:flutter_test/flutter_test.dart';
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
}
