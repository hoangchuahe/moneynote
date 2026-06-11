import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/input_formatters.dart';
import 'package:moneynote/core/money.dart';

TextEditingValue _apply(TextInputFormatter f, String text) =>
    f.formatEditUpdate(TextEditingValue.empty,
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));

void main() {
  group('ThousandsInputFormatter', () {
    final f = ThousandsInputFormatter();

    test('groups digits with dots while typing', () {
      expect(_apply(f, '1500000').text, '1.500.000');
      expect(_apply(f, '50000').text, '50.000');
      expect(_apply(f, '500').text, '500');
    });

    test('strips non-digits (paste with spaces/letters)', () {
      expect(_apply(f, '1 500 000đ').text, '1.500.000');
    });

    test('empty stays empty', () {
      expect(_apply(f, '').text, '');
    });

    test('caret stays at the end after grouping', () {
      final v = _apply(f, '1500000');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('absurdly long input is capped, not crashing int.parse', () {
      final v = _apply(f, '9' * 30);
      expect(v.text, '999.999.999.999.999'); // capped at 15 digits
    });
  });

  group('parseVndInput', () {
    test('parses grouped and plain input', () {
      expect(parseVndInput('1.500.000'), 1500000);
      expect(parseVndInput('50000'), 50000);
    });
    test('returns 0 for empty/garbage', () {
      expect(parseVndInput(''), 0);
      expect(parseVndInput('abc'), 0);
    });
  });
}
