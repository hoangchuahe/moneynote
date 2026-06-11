import 'package:flutter/material.dart';

const _icons = <String, IconData>{
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'receipt_long': Icons.receipt_long,
  'shopping_bag': Icons.shopping_bag,
  'sports_esports': Icons.sports_esports,
  'health_and_safety': Icons.health_and_safety,
  'school': Icons.school,
  'payments': Icons.payments,
  'card_giftcard': Icons.card_giftcard,
  'category': Icons.category,
};

/// Map chuỗi icon lưu trong DB sang IconData; chuỗi lạ fallback Icons.category.
IconData categoryIcon(String name) => _icons[name] ?? Icons.category;

/// Nền ô icon: màu danh mục với alpha 14% (36/255), dùng được cả light/dark.
Color categoryTint(int argb) => Color(argb).withAlpha(36);

/// Ô icon danh mục 36px bo 12 dùng chung mọi danh sách.
class CategoryIconBox extends StatelessWidget {
  final String iconName;
  final int color;
  final double size;
  const CategoryIconBox({
    super.key,
    required this.iconName,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: categoryTint(color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(categoryIcon(iconName), size: size * 0.5, color: Color(color)),
      );
}
