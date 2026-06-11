import 'package:flutter/services.dart';
import 'package:moneynote/core/money.dart';

/// Live-groups VND amounts with '.' every 3 digits while typing
/// (e.g. "1500000" -> "1.500.000"). Strips every non-digit, so it also
/// replaces FilteringTextInputFormatter.digitsOnly. Pair with [parseVndInput]
/// when reading the field back.
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > 15) digits = digits.substring(0, 15); // fits in int64
    final grouped = groupThousands(int.parse(digits));
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}
