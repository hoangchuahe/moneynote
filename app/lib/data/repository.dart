import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:moneynote/data/database.dart';

const _uuid = Uuid();

class AppRepository {
  final AppDatabase db;
  AppRepository(this.db);

  // ---- reads (reactive, exclude soft-deleted) ----

  Stream<List<Wallet>> watchWallets() => (db.select(db.wallets)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  Stream<List<Category>> watchCategories() => (db.select(db.categories)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  Stream<List<Transaction>> watchAllTransactions() =>
      (db.select(db.transactions)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.occurredAt),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .watch();

  // ---- writes ----

  Future<Wallet> addWallet({
    required String name,
    required WalletType type,
    int initialBalance = 0,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: id,
          name: name,
          type: type,
          initialBalance: Value(initialBalance),
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.wallets)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<Category> addCategory({
    required String name,
    required CategoryType type,
    int color = 0xFF9E9E9E,
    String icon = 'category',
    bool isDefault = false,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: id,
          name: name,
          type: type,
          color: Value(color),
          icon: Value(icon),
          isDefault: Value(isDefault),
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.categories)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<Transaction> addTransaction({
    required int amount,
    required TransactionType type,
    String? categoryId,
    required String walletId,
    String? toWalletId,
    String note = '',
    DateTime? occurredAt,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'phải > 0 (đồng VND)');
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          amount: amount,
          type: type,
          categoryId: Value(categoryId),
          walletId: walletId,
          toWalletId: Value(toWalletId),
          note: Value(note),
          occurredAt: occurredAt ?? now,
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.transactions)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> softDeleteTransaction(String id) async {
    final now = DateTime.now();
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> softDeleteWallet(String id) async {
    final now = DateTime.now();
    await (db.update(db.wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> softDeleteCategory(String id) async {
    final now = DateTime.now();
    await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
