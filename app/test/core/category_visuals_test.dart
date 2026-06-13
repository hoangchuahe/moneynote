import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/category_visuals.dart';

void main() {
  test('map đủ 10 icon seed', () {
    expect(categoryIcon('restaurant'), Icons.restaurant);
    expect(categoryIcon('directions_bus'), Icons.directions_bus);
    expect(categoryIcon('receipt_long'), Icons.receipt_long);
    expect(categoryIcon('shopping_bag'), Icons.shopping_bag);
    expect(categoryIcon('sports_esports'), Icons.sports_esports);
    expect(categoryIcon('health_and_safety'), Icons.health_and_safety);
    expect(categoryIcon('school'), Icons.school);
    expect(categoryIcon('payments'), Icons.payments);
    expect(categoryIcon('card_giftcard'), Icons.card_giftcard);
    expect(categoryIcon('category'), Icons.category);
  });

  test('chuỗi lạ fallback Icons.category', () {
    expect(categoryIcon('khong_ton_tai'), Icons.category);
  });

  test('categoryTint giữ RGB, alpha 36', () {
    final tint = categoryTint(0xFFEF5350);
    expect((tint.a * 255.0).round(), 36);
    expect((tint.r * 255.0).round(), 0xEF);
  });

  test('new icons map to their glyphs', () {
    expect(categoryIcon('local_cafe'), Icons.local_cafe);
    expect(categoryIcon('home'), Icons.home);
    expect(categoryIcon('flight'), Icons.flight);
    expect(categoryIcon('savings'), Icons.savings);
    expect(categoryIcon('trending_up'), Icons.trending_up);
  });

  test('kCategoryIconNames is ordered, ends with the fallback, no dupes', () {
    expect(kCategoryIconNames.length, greaterThanOrEqualTo(20));
    expect(kCategoryIconNames.first, 'restaurant');
    expect(kCategoryIconNames.last, 'category');
    expect(kCategoryIconNames.toSet().length, kCategoryIconNames.length);
    for (final n in kCategoryIconNames) {
      if (n != 'category') {
        expect(categoryIcon(n), isNot(Icons.category), reason: '$n must map');
      }
    }
  });

  test('kCategoryColors are 0xFF-opaque and de-duplicated', () {
    expect(kCategoryColors.length, greaterThanOrEqualTo(10));
    expect(kCategoryColors.toSet().length, kCategoryColors.length);
    for (final c in kCategoryColors) {
      expect((c >> 24) & 0xFF, 0xFF, reason: 'swatch must be fully opaque');
    }
  });
}
