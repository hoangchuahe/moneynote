import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/money.dart';

void main() {
  group('groupThousands', () {
    test('groups with dots', () {
      expect(groupThousands(0), '0');
      expect(groupThousands(50000), '50.000');
      expect(groupThousands(1500000), '1.500.000');
      expect(groupThousands(-2000), '-2.000');
    });
  });

  group('formatVnd', () {
    test('appends đồng symbol', () {
      expect(formatVnd(50000), '50.000 ₫');
    });
  });

  group('formatDmy', () {
    test('zero-pads day and month', () {
      expect(formatDmy(DateTime(2026, 6, 1)), '01/06/2026');
      expect(formatDmy(DateTime(2026, 11, 23)), '23/11/2026');
    });
  });
}
