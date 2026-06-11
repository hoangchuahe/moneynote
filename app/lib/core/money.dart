/// Groups an integer with '.' every 3 digits (Vietnamese style).
String groupThousands(int n) {
  final neg = n < 0;
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return (neg ? '-' : '') + buf.toString();
}

/// Formats integer đồng as VND, e.g. 50000 -> "50.000 ₫".
String formatVnd(int dong) => '${groupThousands(dong)} ₫';

/// Parses user-typed VND input, ignoring grouping dots/spaces:
/// "1.500.000" -> 1500000. Returns 0 when no digits (caller treats as invalid).
int parseVndInput(String s) {
  var digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length > 15) digits = digits.substring(0, 15); // fits in int64
  return digits.isEmpty ? 0 : int.parse(digits);
}

/// Formats a date as dd/MM/yyyy.
String formatDmy(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}
