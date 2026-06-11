import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

enum TransactionType { income, expense, transfer }

enum CategoryType { income, expense }

enum WalletType { cash, bank, ewallet }

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get type => intEnum<WalletType>()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('VND'))();
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

@DriftDatabase(tables: [Wallets, Categories, Transactions, MerchantMemories])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _ensureMerchantIndex();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(merchantMemories);
          if (from < 3) await _ensureMerchantIndex();
        },
      );

  Future<void> _ensureMerchantIndex() => customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_merchant_memories_merchant '
      'ON merchant_memories (merchant)');
}

/// App (device) connection — file in the documents dir.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'moneynote.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
