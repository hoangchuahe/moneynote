import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/data/ai_client.dart';
import 'package:moneynote/data/csv_export_service.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/domain/transaction_filter.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openConnection());
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<AppRepository>(
  (ref) => AppRepository(ref.watch(databaseProvider)),
);

final csvExporterProvider = Provider<CsvExporter>((ref) => DiskCsvExporter());

final walletsProvider = StreamProvider<List<Wallet>>(
  (ref) => ref.watch(repositoryProvider).watchWallets(),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(repositoryProvider).watchCategories(),
);

final transactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(repositoryProvider).watchAllTransactions(),
);

final budgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(repositoryProvider).watchBudgets(),
);

final recurringsProvider = StreamProvider<List<Recurring>>(
  (ref) => ref.watch(repositoryProvider).watchRecurrings(),
);

/// The month shown on the dashboard (first of month). Defaults to current month.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final prefsProvider = FutureProvider<AppPrefs>((ref) => AppPrefs.load());

final aiClientProvider = Provider<AiClient?>((ref) {
  final prefs = ref.watch(prefsProvider).valueOrNull;
  if (prefs == null) return null;
  return AiClient(Dio(), baseUrl: prefs.baseUrl, deviceToken: prefs.deviceToken);
});

final txnFilterProvider =
    StateProvider<TxnFilter>((ref) => const TxnFilter());
