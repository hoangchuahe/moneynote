import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';

void main() {
  test('buildTheme cấp MoneyColors cho cả 4 tổ hợp style x brightness', () {
    for (final s in AppThemeStyle.values) {
      for (final b in [Brightness.light, Brightness.dark]) {
        final t = buildTheme(s, b);
        expect(t.brightness, b);
        final money = t.extension<MoneyColors>();
        expect(money, isNotNull, reason: '$s/$b thiếu MoneyColors');
        expect(money!.expense, isNot(money.income));
      }
    }
  });

  test('primary đúng spec: classic emerald, warm terracotta', () {
    expect(buildTheme(AppThemeStyle.classic, Brightness.light).colorScheme.primary,
        const Color(0xFF0B7A4F));
    expect(buildTheme(AppThemeStyle.warm, Brightness.light).colorScheme.primary,
        const Color(0xFFD96C3B));
    expect(buildTheme(AppThemeStyle.classic, Brightness.dark).colorScheme.primary,
        const Color(0xFF5BC894));
    expect(buildTheme(AppThemeStyle.warm, Brightness.dark).colorScheme.primary,
        const Color(0xFFE0936A));
  });

  test('buildLightTheme/buildDarkTheme cũ vẫn dùng được (classic)', () {
    expect(buildLightTheme().colorScheme.primary, const Color(0xFF0B7A4F));
    expect(buildDarkTheme().brightness, Brightness.dark);
  });
}
