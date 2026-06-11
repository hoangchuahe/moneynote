import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:moneynote/data/database.dart';

const _uuid = Uuid();

class _CatSeed {
  final String name;
  final CategoryType type;
  final int color;
  final String icon;
  const _CatSeed(this.name, this.type, this.color, this.icon);
}

const _defaultCategories = <_CatSeed>[
  _CatSeed('Ăn uống', CategoryType.expense, 0xFFEF5350, 'restaurant'),
  _CatSeed('Đi lại', CategoryType.expense, 0xFF42A5F5, 'directions_bus'),
  _CatSeed('Hoá đơn', CategoryType.expense, 0xFFFFCA28, 'receipt_long'),
  _CatSeed('Mua sắm', CategoryType.expense, 0xFFAB47BC, 'shopping_bag'),
  _CatSeed('Giải trí', CategoryType.expense, 0xFF26C6DA, 'sports_esports'),
  _CatSeed('Sức khoẻ', CategoryType.expense, 0xFF66BB6A, 'health_and_safety'),
  _CatSeed('Giáo dục', CategoryType.expense, 0xFF8D6E63, 'school'),
  _CatSeed('Khác (chi)', CategoryType.expense, 0xFF9E9E9E, 'category'),
  _CatSeed('Lương', CategoryType.income, 0xFF66BB6A, 'payments'),
  _CatSeed('Thưởng', CategoryType.income, 0xFFFFA726, 'card_giftcard'),
  _CatSeed('Khác (thu)', CategoryType.income, 0xFF9E9E9E, 'category'),
];

/// Creates the starter wallet + default categories if the db has no wallets.
Future<void> seedIfEmpty(AppDatabase db) async {
  final existing = await db.select(db.wallets).get();
  if (existing.isNotEmpty) return;

  final now = DateTime.now();
  await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: _uuid.v4(),
        name: 'Tiền mặt',
        type: WalletType.cash,
        createdAt: now,
        updatedAt: now,
      ));

  for (final c in _defaultCategories) {
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: _uuid.v4(),
          name: c.name,
          type: c.type,
          color: Value(c.color),
          icon: Value(c.icon),
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));
  }
}
