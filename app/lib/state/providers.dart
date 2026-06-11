import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openConnection());
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<AppRepository>(
  (ref) => AppRepository(ref.watch(databaseProvider)),
);

final walletsProvider = StreamProvider<List<Wallet>>(
  (ref) => ref.watch(repositoryProvider).watchWallets(),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(repositoryProvider).watchCategories(),
);

final transactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(repositoryProvider).watchAllTransactions(),
);

/// The month shown on the dashboard (first of month). Defaults to current month.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});
