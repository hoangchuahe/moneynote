import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/dashboard/dashboard_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('dashboard navigates between months with ‹ ›', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        selectedMonthProvider.overrideWith((ref) => DateTime(2026, 3, 1)),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Tháng 3/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('prevMonth')));
    await tester.pump();
    expect(find.text('Tháng 2/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nextMonth')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('nextMonth')));
    await tester.pump();
    expect(find.text('Tháng 4/2026'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('January wraps to December of the previous year', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        selectedMonthProvider.overrideWith((ref) => DateTime(2026, 1, 1)),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const Key('prevMonth')));
    await tester.pump();
    expect(find.text('Tháng 12/2025'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('hero hiện Còn lại tháng này và nhóm ngày ở Gần đây',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    await tester.runAsync(() async {
      final w = (await repo.watchWallets().first).single;
      // Thu lớn hơn chi để hero "Còn lại" dương — dấu trừ duy nhất có thể
      // xuất hiện là ở dòng giao dịch, đúng thứ test này canh.
      await repo.addTransaction(
          amount: 120000, type: TransactionType.income, walletId: w.id);
      await repo.addTransaction(
          amount: 50000, type: TransactionType.expense, walletId: w.id);
    });

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Còn lại tháng này'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    // Scoped: chi/transfer trên TransactionTile không được có dấu trừ.
    // (không dùng findsNothing toàn màn hình để tránh dương tính giả từ
    // chuỗi khác như ngày "12-6", v.v.)
    expect(
      find.descendant(
        of: find.byType(TransactionTile),
        matching: find.textContaining('-'),
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Gần đây only shows transactions in the selected month',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);

    await tester.runAsync(() async {
      final w = (await repo.watchWallets().first).single;
      // One txn in the selected month (March 2026)
      await repo.addTransaction(
        amount: 80000,
        type: TransactionType.income,
        walletId: w.id,
        note: 'thu thang ba',
        occurredAt: DateTime(2026, 3, 15),
      );
      // One txn in a different month (April 2026) — must NOT appear
      await repo.addTransaction(
        amount: 30000,
        type: TransactionType.expense,
        walletId: w.id,
        note: 'chi thang tu',
        occurredAt: DateTime(2026, 4, 10),
      );
    });

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        selectedMonthProvider.overrideWith((ref) => DateTime(2026, 3, 1)),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('thu thang ba'), findsOneWidget);
    expect(find.text('chi thang tu'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
