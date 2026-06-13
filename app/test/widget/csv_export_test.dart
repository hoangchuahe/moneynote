import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/csv_export_service.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/settings/settings_screen.dart';
import 'package:moneynote/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../drift_setup.dart';

class FakeCsvExporter implements CsvExporter {
  int calls = 0;
  String? filename;
  String? csv;

  @override
  Future<String> save(String filename, String csv) async {
    calls++;
    this.filename = filename;
    this.csv = csv;
    return '/fake/$filename';
  }
}

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget app(AppDatabase db, FakeCsvExporter fake) => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        csvExporterProvider.overrideWithValue(fake),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('export "Tất cả" saves a CSV and shows the saved path',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    final repo = AppRepository(db);
    final food = (await db.select(db.categories).get())
        .firstWhere((c) => c.name == 'Ăn uống');
    final w = (await db.select(db.wallets).get()).first;
    await repo.addTransaction(
      amount: 50000,
      type: TransactionType.expense,
      categoryId: food.id,
      walletId: w.id,
      note: 'Phở',
      occurredAt: DateTime(2026, 6, 10),
    );
    addTearDown(db.close);
    bigView(tester);

    final fake = FakeCsvExporter();
    await tester.pumpWidget(app(db, fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xuất CSV'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Tất cả'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(fake.calls, 1);
    expect(fake.filename, matches(RegExp(r'^moneynote-all-\d{8}\.csv$')));
    expect(fake.csv, contains('Ăn uống'));
    expect(fake.csv, contains('50000'));
    expect(fake.csv, contains('Phở'));
    expect(find.textContaining('Đã lưu:'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('export with no transactions shows the empty message',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db); // categories + wallets, but no transactions
    addTearDown(db.close);
    bigView(tester);

    final fake = FakeCsvExporter();
    await tester.pumpWidget(app(db, fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xuất CSV'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Tất cả'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(fake.calls, 0);
    expect(find.text('Không có giao dịch để xuất'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
