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

/// Formats a date as dd/MM/yyyy.
String formatDmy(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}
