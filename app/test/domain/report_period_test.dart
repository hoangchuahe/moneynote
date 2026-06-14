import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/domain/report_period.dart';

void main() {
  group('ReportPeriod.month', () {
    final p = ReportPeriod.month(DateTime(2026, 6, 15));
    test('bounds + labels', () {
      expect(p.start, DateTime(2026, 6, 1));
      expect(p.end, DateTime(2026, 7, 1));
      expect(p.label, 'Tháng 6/2026');
      expect(p.shortLabel, 'T6');
      expect(p.noun, 'tháng');
    });
    test('contains is start-inclusive, end-exclusive', () {
      expect(p.contains(DateTime(2026, 6, 1)), isTrue);
      expect(p.contains(DateTime(2026, 6, 30, 23)), isTrue);
      expect(p.contains(DateTime(2026, 7, 1)), isFalse);
      expect(p.contains(DateTime(2026, 5, 31)), isFalse);
    });
    test('prev/next step by one month', () {
      expect(p.prev.start, DateTime(2026, 5, 1));
      expect(p.next.start, DateTime(2026, 7, 1));
    });
  });

  group('ReportPeriod.quarter', () {
    final q2 = ReportPeriod.quarter(DateTime(2026, 6, 15)); // Q2 = Apr–Jun
    test('bounds + labels', () {
      expect(q2.start, DateTime(2026, 4, 1));
      expect(q2.end, DateTime(2026, 7, 1));
      expect(q2.label, 'Quý 2/2026');
      expect(q2.shortLabel, 'Q2');
      expect(q2.noun, 'quý');
    });
    test('prev/next cross the year boundary', () {
      expect(q2.prev.start, DateTime(2026, 1, 1)); // Q1
      expect(q2.prev.prev.start, DateTime(2025, 10, 1)); // Q4 2025
      expect(q2.next.start, DateTime(2026, 7, 1)); // Q3
    });
  });

  group('ReportPeriod.year', () {
    final y = ReportPeriod.year(DateTime(2026, 6, 15));
    test('bounds + labels', () {
      expect(y.start, DateTime(2026, 1, 1));
      expect(y.end, DateTime(2027, 1, 1));
      expect(y.label, 'Năm 2026');
      expect(y.shortLabel, '2026');
      expect(y.noun, 'năm');
    });
    test('prev/next step by a year', () {
      expect(y.prev.start, DateTime(2025, 1, 1));
      expect(y.next.start, DateTime(2027, 1, 1));
    });
  });

  group('anchor independence + equality', () {
    test('two anchors in the same quarter are equal', () {
      expect(ReportPeriod.quarter(DateTime(2026, 4, 1)),
          ReportPeriod.quarter(DateTime(2026, 6, 30)));
    });
    test('same start but different granularity is not equal', () {
      expect(
          ReportPeriod.month(DateTime(2026, 1, 1)) ==
              ReportPeriod.year(DateTime(2026, 1, 1)),
          isFalse);
    });
  });
}
