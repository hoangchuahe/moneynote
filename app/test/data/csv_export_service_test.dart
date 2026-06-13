import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/csv_export_service.dart';

void main() {
  group('csvBytesWithBom', () {
    test('prefixes UTF-8 BOM then the UTF-8 bytes', () {
      final bytes = csvBytesWithBom('Aá');
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(bytes.sublist(3), utf8.encode('Aá'));
    });

    test('empty string still carries the BOM', () {
      expect(csvBytesWithBom(''), [0xEF, 0xBB, 0xBF]);
    });
  });
}
