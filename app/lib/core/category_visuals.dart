import 'package:flutter/material.dart';

const _icons = <String, IconData>{
  // food & shopping
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'local_grocery_store': Icons.local_grocery_store,
  'shopping_bag': Icons.shopping_bag,
  'checkroom': Icons.checkroom,
  // transport
  'directions_bus': Icons.directions_bus,
  'local_gas_station': Icons.local_gas_station,
  'flight': Icons.flight,
  // home & bills
  'home': Icons.home,
  'receipt_long': Icons.receipt_long,
  'bolt': Icons.bolt,
  'phone_android': Icons.phone_android,
  // health · learning · fun
  'health_and_safety': Icons.health_and_safety,
  'fitness_center': Icons.fitness_center,
  'school': Icons.school,
  'sports_esports': Icons.sports_esports,
  'celebration': Icons.celebration,
  // family
  'pets': Icons.pets,
  'child_care': Icons.child_care,
  'card_giftcard': Icons.card_giftcard,
  // income
  'payments': Icons.payments,
  'work': Icons.work,
  'savings': Icons.savings,
  'trending_up': Icons.trending_up,
  // fallback (always last)
  'category': Icons.category,
};

/// Map chuỗi icon lưu trong DB sang IconData; chuỗi lạ fallback Icons.category.
IconData categoryIcon(String name) => _icons[name] ?? Icons.category;

/// Ordered icon keys the category picker renders (storage is still the raw
/// string; `categoryIcon` falls back to `Icons.category` for anything off-list).
const kCategoryIconNames = <String>[
  'restaurant', 'local_cafe', 'local_grocery_store', 'shopping_bag', 'checkroom',
  'directions_bus', 'local_gas_station', 'flight',
  'home', 'receipt_long', 'bolt', 'phone_android',
  'health_and_safety', 'fitness_center', 'school', 'sports_esports', 'celebration',
  'pets', 'child_care', 'card_giftcard',
  'payments', 'work', 'savings', 'trending_up',
  'category',
];

/// Mid-tone category swatches, legible on both light & dark (distinct from the
/// all-dark wallet palette). First entry is the new-category default.
const kCategoryColors = <int>[
  0xFF13A4B8, // teal
  0xFF4CA050, // green
  0xFF7CB342, // lime
  0xFFB58A00, // gold
  0xFFE08A00, // orange
  0xFFE53935, // red
  0xFFEC407A, // pink
  0xFF8E5BD0, // purple
  0xFF5C6BC0, // indigo
  0xFF2F88E0, // blue
  0xFF8D6E63, // brown
  0xFF757575, // grey
];

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
