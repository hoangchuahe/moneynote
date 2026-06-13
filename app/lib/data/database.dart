import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

enum TransactionType { income, expense, transfer }

enum CategoryType { income, expense }

enum WalletType { cash, bank, ewallet }

enum RecurringCycle { daily, weekly, monthly, yearly }

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get type => intEnum<WalletType>()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('VND'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF0B7A4F))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF9E9E9E))();
  IntColumn get type => intEnum<CategoryType>()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  IntColumn get amount => integer()(); // đồng VND, always > 0
  IntColumn get type => intEnum<TransactionType>()();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get toWalletId =>
      text().nullable().references(Wallets, #id)(); // transfer destination
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MerchantMemories extends Table {
  TextColumn get id => text()();
  TextColumn get merchant => text()(); // normalized lowercase
  TextColumn get categoryId => text().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)(); // null = overall budget
  IntColumn get amount => integer()(); // monthly limit, đồng
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Recurrings extends Table {
  TextColumn get id => text()();
  IntColumn get amount => integer()(); // đồng VND, always > 0
  IntColumn get type => intEnum<TransactionType>()(); // income | expense (no transfer)
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get cycle => intEnum<RecurringCycle>()();
  DateTimeColumn get startDate => dateTime()(); // anchor / first occurrence (date-only)
  DateTimeColumn get lastRunAt => dateTime().nullable()(); // occurredAt of last auto-created txn
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Wallets, Categories, Transactions, MerchantMemories, Budgets, Recurrings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _ensureMerchantIndex();
          await _ensureTransactionIndexes();
          await _ensureRecurringIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(merchantMemories);
          if (from < 3) await _ensureMerchantIndex();
          if (from < 4) await m.createTable(budgets);
          if (from < 5) await _ensureTransactionIndexes();
          if (from < 6) {
            await m.createTable(recurrings);
            await _ensureRecurringIndexes();
          }
          if (from < 7) await m.addColumn(wallets, wallets.color);
        },
      );

  Future<void> _ensureMerchantIndex() => customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_merchant_memories_merchant '
      'ON merchant_memories (merchant)');

  /// Partial index over live rows, ordered like watchRecurrings (createdAt DESC)
  /// and matching the `deletedAt IS NULL` filter materialize/watch use. A plain
  /// index on deleted_at would not serve `IS NULL` scans in SQLite.
  Future<void> _ensureRecurringIndexes() => customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recurrings_active '
      'ON recurrings (created_at) WHERE deleted_at IS NULL');

  /// List/dashboard queries order by occurred_at and filter by wallet.
  Future<void> _ensureTransactionIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS '
        'idx_transactions_occurred_at ON transactions (occurred_at)');
    await customStatement('CREATE INDEX IF NOT EXISTS '
        'idx_transactions_wallet_id ON transactions (wallet_id)');
  }
}

/// App (device) connection — file in the documents dir.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'moneynote.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
