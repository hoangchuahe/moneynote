import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/recurring.dart';

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
    int color = 0xFF0B7A4F,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: id,
          name: name,
          type: type,
          initialBalance: Value(initialBalance),
          color: Value(color),
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

  /// Edits an existing category in place (partial companion). Touches only the
  /// edited fields + updatedAt; createdAt / isDefault / deletedAt survive.
  Future<void> updateCategory({
    required String id,
    required String name,
    required CategoryType type,
    required String icon,
    required int color,
  }) async {
    await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        type: Value(type),
        icon: Value(icon),
        color: Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  void _validateTransaction(
      int amount, TransactionType type, String walletId, String? toWalletId) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'phải > 0 (đồng VND)');
    }
    if (type == TransactionType.transfer &&
        (toWalletId == null || toWalletId == walletId)) {
      throw ArgumentError.value(
          toWalletId, 'toWalletId', 'transfer cần ví đích khác ví nguồn');
    }
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
    _validateTransaction(amount, type, walletId, toWalletId);
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

  /// Edits an existing transaction in place (same validation as add).
  Future<void> updateTransaction(
    String id, {
    required int amount,
    required TransactionType type,
    String? categoryId,
    required String walletId,
    String? toWalletId,
    String note = '',
    required DateTime occurredAt,
  }) async {
    _validateTransaction(amount, type, walletId, toWalletId);
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        amount: Value(amount),
        type: Value(type),
        categoryId: Value(categoryId),
        walletId: Value(walletId),
        toWalletId: Value(toWalletId),
        note: Value(note),
        occurredAt: Value(occurredAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDeleteTransaction(String id) async {
    final now = DateTime.now();
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> restoreTransaction(String id) async {
    final now = DateTime.now();
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: const Value(null), updatedAt: Value(now)),
    );
  }

  Future<void> updateWallet({
    required String id,
    required String name,
    required WalletType type,
    required int color,
  }) async {
    await (db.update(db.wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(
        name: Value(name),
        type: Value(type),
        color: Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDeleteWallet(String id) async {
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.wallets)..where((t) => t.id.equals(id))).write(
        WalletsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (db.update(db.transactions)
            ..where((t) => t.walletId.equals(id) | t.toWalletId.equals(id)))
          .write(
        TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (db.update(db.recurrings)..where((t) => t.walletId.equals(id))).write(
        RecurringsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  Future<void> softDeleteCategory(String id) async {
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (db.update(db.merchantMemories)
            ..where((t) => t.categoryId.equals(id)))
          .write(
        MerchantMemoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  /// Returns the learned Category for a normalized merchant, or null.
  Future<Category?> lookupMerchant(String merchant) async {
    final key = merchant.trim().toLowerCase();
    final mem = await (db.select(db.merchantMemories)
          ..where((t) => t.merchant.equals(key) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (mem == null) return null;
    return (db.select(db.categories)
          ..where((t) => t.id.equals(mem.categoryId) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Stream<List<Budget>> watchBudgets() => (db.select(db.budgets)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  /// Sets the monthly budget for [categoryId] (null = overall). Updates the
  /// existing row for that category (un-deleting if needed), or inserts a new one.
  Future<void> upsertBudget(String? categoryId, int amount) async {
    final now = DateTime.now();
    final existing = await (db.select(db.budgets)
          ..where((t) => categoryId == null
              ? t.categoryId.isNull()
              : t.categoryId.equals(categoryId)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
            id: _uuid.v4(),
            categoryId: Value(categoryId),
            amount: amount,
            createdAt: now,
            updatedAt: now,
          ));
    } else {
      await (db.update(db.budgets)..where((t) => t.id.equals(existing.id)))
          .write(BudgetsCompanion(
        amount: Value(amount),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ));
    }
  }

  Future<void> deleteBudget(String id) async {
    final now = DateTime.now();
    await (db.update(db.budgets)..where((t) => t.id.equals(id))).write(
      BudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Learns/updates merchant -> category.
  Future<void> upsertMerchant(String merchant, String categoryId) async {
    final key = merchant.trim().toLowerCase();
    final now = DateTime.now();
    final existing = await (db.select(db.merchantMemories)
          ..where((t) => t.merchant.equals(key)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.merchantMemories).insert(MerchantMemoriesCompanion.insert(
            id: _uuid.v4(),
            merchant: key,
            categoryId: categoryId,
            createdAt: now,
            updatedAt: now,
          ));
    } else {
      await (db.update(db.merchantMemories)..where((t) => t.id.equals(existing.id)))
          .write(MerchantMemoriesCompanion(
        categoryId: Value(categoryId),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ));
    }
  }

  // ---- recurring rules ----

  Stream<List<Recurring>> watchRecurrings() => (db.select(db.recurrings)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  void _validateRecurring(int amount, TransactionType type) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'phải > 0 (đồng VND)');
    }
    if (type == TransactionType.transfer) {
      throw ArgumentError.value(
          type, 'type', 'không được là transfer trong định kỳ v1');
    }
  }

  Future<Recurring> addRecurring({
    required int amount,
    required TransactionType type,
    String? categoryId,
    required String walletId,
    String note = '',
    required RecurringCycle cycle,
    required DateTime startDate,
  }) async {
    _validateRecurring(amount, type);
    final now = DateTime.now();
    final id = _uuid.v4();
    final sd = DateTime(startDate.year, startDate.month, startDate.day);
    await db.into(db.recurrings).insert(RecurringsCompanion.insert(
          id: id,
          amount: amount,
          type: type,
          categoryId: Value(categoryId),
          walletId: walletId,
          note: Value(note),
          cycle: cycle,
          startDate: sd,
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.recurrings)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateRecurring(
    String id, {
    required int amount,
    required TransactionType type,
    String? categoryId,
    required String walletId,
    String note = '',
    required RecurringCycle cycle,
    required DateTime startDate,
  }) async {
    _validateRecurring(amount, type);
    final sd = DateTime(startDate.year, startDate.month, startDate.day);
    final existing =
        await (db.select(db.recurrings)..where((t) => t.id.equals(id))).getSingle();
    final anchorChanged = existing.cycle != cycle || existing.startDate != sd;
    await (db.update(db.recurrings)..where((t) => t.id.equals(id))).write(
      RecurringsCompanion(
        amount: Value(amount),
        type: Value(type),
        categoryId: Value(categoryId),
        walletId: Value(walletId),
        note: Value(note),
        cycle: Value(cycle),
        startDate: Value(sd),
        lastRunAt: anchorChanged ? const Value(null) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDeleteRecurring(String id) async {
    final now = DateTime.now();
    await (db.update(db.recurrings)..where((t) => t.id.equals(id))).write(
      RecurringsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Creates the latest-due transaction for each live rule. Idempotent.
  /// Returns the number created. [today] is injected for determinism/tests.
  Future<int> materializeDueRecurrings(DateTime today) async {
    final rules = await (db.select(db.recurrings)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final now = DateTime.now();
    var created = 0;
    for (final r in rules) {
      final occ = mostRecentOccurrence(r.startDate, r.cycle, today);
      if (occ == null) continue;
      final lastRun = r.lastRunAt == null
          ? null
          : DateTime(r.lastRunAt!.year, r.lastRunAt!.month, r.lastRunAt!.day);
      if (lastRun != null && !occ.isAfter(lastRun)) continue;
      await db.transaction(() async {
        await addTransaction(
          amount: r.amount,
          type: r.type,
          categoryId: r.categoryId,
          walletId: r.walletId,
          note: r.note,
          occurredAt: occ,
        );
        await (db.update(db.recurrings)..where((t) => t.id.equals(r.id))).write(
          RecurringsCompanion(
              lastRunAt: Value(occ), updatedAt: Value(now)),
        );
      });
      created++;
    }
    return created;
  }
}
