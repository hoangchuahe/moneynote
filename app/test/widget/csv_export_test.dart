import 'dart:io';

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

class ThrowingCsvExporter implements CsvExporter {
  @override
  Future<String> save(String filename, String csv) async {
    throw const FileSystemException('disk full');
  }
}

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

  testWidgets('export shows an error SnackBar when saving fails',
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
      occurredAt: DateTime(2026, 6, 10),
    );
    addTearDown(db.close);
    bigView(tester);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        csvExporterProvider.overrideWithValue(ThrowingCsvExporter()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xuất CSV'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Tất cả'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('Lỗi khi lưu file:'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('export sorts rows ascending by date regardless of input order',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    final repo = AppRepository(db);
    final food = (await db.select(db.categories).get())
        .firstWhere((c) => c.name == 'Ăn uống');
    final w = (await db.select(db.wallets).get()).first;
    // Insert the newer one first so the provider's desc order is NOT already
    // ascending — the CSV order therefore proves the controller's sort.
    await repo.addTransaction(
      amount: 20000,
      type: TransactionType.expense,
      categoryId: food.id,
      walletId: w.id,
      occurredAt: DateTime(2026, 6, 20),
    );
    await repo.addTransaction(
      amount: 10000,
      type: TransactionType.expense,
      categoryId: food.id,
      walletId: w.id,
      occurredAt: DateTime(2026, 6, 5),
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

    final csv = fake.csv!;
    expect(csv, contains('2026-06-05'));
    expect(csv, contains('2026-06-20'));
    expect(csv.indexOf('2026-06-05'), lessThan(csv.indexOf('2026-06-20')));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
