import 'package:flutter/material.dart';
import 'package:moneynote/core/prefs.dart' show AppThemeStyle;

/// Màu ngữ nghĩa tiền tệ, tách khỏi ColorScheme. Screens lấy qua
/// Theme.of(context).extension<MoneyColors>()!
class MoneyColors extends ThemeExtension<MoneyColors> {
  final Color income;
  final Color expense;
  final Color transfer;
  final Color warn; // cảnh báo sớm + lời nhắn AI
  final Color warnContainer;
  final Color onWarnContainer;
  const MoneyColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warn,
    required this.warnContainer,
    required this.onWarnContainer,
  });

  @override
  MoneyColors copyWith({
    Color? income, Color? expense, Color? transfer,
    Color? warn, Color? warnContainer, Color? onWarnContainer,
  }) =>
      MoneyColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        transfer: transfer ?? this.transfer,
        warn: warn ?? this.warn,
        warnContainer: warnContainer ?? this.warnContainer,
        onWarnContainer: onWarnContainer ?? this.onWarnContainer,
      );

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    return MoneyColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnContainer: Color.lerp(warnContainer, other.warnContainer, t)!,
      onWarnContainer: Color.lerp(onWarnContainer, other.onWarnContainer, t)!,
    );
  }
}

class _Tokens {
  final Color bg, surface, primary, onPrimary, primaryContainer,
      onPrimaryContainer, warn, warnContainer, onWarnContainer,
      expense, income, transfer, ink, inkMuted, divider;
  const _Tokens({
    required this.bg, required this.surface, required this.primary,
    required this.onPrimary, required this.primaryContainer,
    required this.onPrimaryContainer, required this.warn,
    required this.warnContainer, required this.onWarnContainer,
    required this.expense, required this.income, required this.transfer,
    required this.ink, required this.inkMuted, required this.divider,
  });
}

const _classicLight = _Tokens(
  bg: Color(0xFFF6F7F5), surface: Color(0xFFFFFFFF),
  primary: Color(0xFF0B7A4F), onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFDFF0E8), onPrimaryContainer: Color(0xFF064D32),
  warn: Color(0xFFD97A4A), warnContainer: Color(0xFFF8E8DC),
  onWarnContainer: Color(0xFF7A3A1B),
  expense: Color(0xFFC04848), income: Color(0xFF0B7A4F),
  transfer: Color(0xFF5E6963),
  ink: Color(0xFF15201A), inkMuted: Color(0xFF5E6963),
  divider: Color(0xFFE7EBE8),
);

const _classicDark = _Tokens(
  bg: Color(0xFF111513), surface: Color(0xFF1A201C),
  primary: Color(0xFF5BC894), onPrimary: Color(0xFF06281A),
  primaryContainer: Color(0xFF1F3B2E), onPrimaryContainer: Color(0xFFBFE8D4),
  warn: Color(0xFFE0936A), warnContainer: Color(0xFF3D2A1E),
  onWarnContainer: Color(0xFFF0CDB5),
  expense: Color(0xFFE07A6E), income: Color(0xFF5BC894),
  transfer: Color(0xFF9BA59E),
  ink: Color(0xFFE7EDE9), inkMuted: Color(0xFF9BA59E),
  divider: Color(0xFF262D28),
);

const _warmLight = _Tokens(
  bg: Color(0xFFFAF3E7), surface: Color(0xFFFFFCF5),
  primary: Color(0xFFD96C3B), onPrimary: Color(0xFFFFF8EC),
  primaryContainer: Color(0xFFF6E3CB), onPrimaryContainer: Color(0xFF7A3A1B),
  warn: Color(0xFFB98345), warnContainer: Color(0xFFF2E2C8),
  onWarnContainer: Color(0xFF5C3D14),
  expense: Color(0xFFB3422F), income: Color(0xFF4F6E3C),
  transfer: Color(0xFF8A7A63),
  ink: Color(0xFF42382B), inkMuted: Color(0xFF8A7A63),
  divider: Color(0xFFF0E6D4),
);

const _warmDark = _Tokens(
  bg: Color(0xFF181411), surface: Color(0xFF221C16),
  primary: Color(0xFFE0936A), onPrimary: Color(0xFF2A1A10),
  primaryContainer: Color(0xFF3D2A1E), onPrimaryContainer: Color(0xFFF0CDB5),
  warn: Color(0xFFC99A5B), warnContainer: Color(0xFF38301F),
  onWarnContainer: Color(0xFFEAD9B8),
  expense: Color(0xFFE08573), income: Color(0xFF9DBE7F),
  transfer: Color(0xFFA89878),
  ink: Color(0xFFEFE6D8), inkMuted: Color(0xFFB3A48C),
  divider: Color(0xFF322A20),
);

ThemeData buildTheme(AppThemeStyle style, Brightness brightness) {
  final t = switch ((style, brightness)) {
    (AppThemeStyle.classic, Brightness.light) => _classicLight,
    (AppThemeStyle.classic, Brightness.dark) => _classicDark,
    (AppThemeStyle.warm, Brightness.light) => _warmLight,
    (AppThemeStyle.warm, Brightness.dark) => _warmDark,
  };
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.primary,
    onPrimary: t.onPrimary,
    primaryContainer: t.primaryContainer,
    onPrimaryContainer: t.onPrimaryContainer,
    secondary: t.warn,
    onSecondary: t.onPrimary,
    secondaryContainer: t.warnContainer,
    onSecondaryContainer: t.onWarnContainer,
    error: t.expense,
    onError: brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF2A0E0B),
    surface: t.surface,
    onSurface: t.ink,
    onSurfaceVariant: t.inkMuted,
    outline: t.divider,
    outlineVariant: t.divider,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    fontFamily: 'BeVietnamPro',
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: t.divider, thickness: 0.6),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      indicatorColor: t.primaryContainer,
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: t.inkMuted)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.divider, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.divider, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.primary, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: t.divider, width: 0.8),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: t.surface,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    extensions: [
      MoneyColors(
        income: t.income, expense: t.expense, transfer: t.transfer,
        warn: t.warn, warnContainer: t.warnContainer,
        onWarnContainer: t.onWarnContainer,
      ),
    ],
  );
}

ThemeData buildLightTheme() => buildTheme(AppThemeStyle.classic, Brightness.light);
ThemeData buildDarkTheme() => buildTheme(AppThemeStyle.classic, Brightness.dark);
