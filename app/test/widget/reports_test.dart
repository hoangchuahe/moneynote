import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/inset_section.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/categories/category_detail_screen.dart';
import 'package:moneynote/features/home/home_shell.dart';
import 'package:moneynote/features/reports/reports_screen.dart';
import 'package:moneynote/features/reports/widgets/category_donut.dart';
import 'package:moneynote/features/reports/widgets/period_flow_card.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(AppDatabase db, DateTime month) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          selectedMonthProvider.overrideWith((ref) => month),
        ],
        child: MaterialApp(
          theme: buildTheme(AppThemeStyle.classic, Brightness.light),
          home: const ReportsScreen(),
        ),
      );

  // Seed handles: two expense categories + a wallet. (Seed adds no transactions.)
  Future<({String foodId, String moveId, String walletId})> handles(
      AppDatabase db) async {
    final cats = await db.select(db.categories).get();
    final food = cats.firstWhere((c) => c.name == 'Ăn uống');
    final move = cats
        .firstWhere((c) => c.type == CategoryType.expense && c.name != 'Ăn uống');
    final w = (await db.select(db.wallets).get()).first;
    return (foodId: food.id, moveId: move.id, walletId: w.id);
  }

  group('ReportsScreen', () {
    testWidgets('donut total + breakdown rows for the month', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      final repo = AppRepository(db);
      final h = await handles(db);
      await repo.addTransaction(
          amount: 600000,
          type: TransactionType.expense,
          categoryId: h.foodId,
          walletId: h.walletId,
          occurredAt: DateTime(2026, 6, 10));
      await repo.addTransaction(
          amount: 400000,
          type: TransactionType.expense,
          categoryId: h.moveId,
          walletId: h.walletId,
          occurredAt: DateTime(2026, 6, 11));
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Báo cáo'), findsOneWidget);
      expect(find.text('Tháng 6/2026'), findsOneWidget);
      expect(find.byType(CategoryDonut), findsOneWidget);
      expect(find.text('Tổng chi'), findsOneWidget);
      expect(find.text('1.000.000 ₫'), findsOneWidget); // donut centre sum
      expect(find.text('Theo danh mục'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget); // breakdown row
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('tap a category row → CategoryDetailScreen; null bucket not tappable',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      final repo = AppRepository(db);
      final h = await handles(db);
      await repo.addTransaction(
          amount: 600000,
          type: TransactionType.expense,
          categoryId: h.foodId,
          walletId: h.walletId,
          occurredAt: DateTime(2026, 6, 10));
      await repo.addTransaction(
          amount: 100000,
          type: TransactionType.expense,
          categoryId: null, // uncategorised → null bucket
          walletId: h.walletId,
          occurredAt: DateTime(2026, 6, 12));
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      final nullRow = tester.widget<InsetRow>(find.ancestor(
          of: find.text('Chưa phân loại'), matching: find.byType(InsetRow)));
      expect(nullRow.onTap, isNull);

      await tester.tap(find.text('Ăn uống'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryDetailScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Quý segment widens the window to the quarter', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      final repo = AppRepository(db);
      final h = await handles(db);
      await repo.addTransaction(
          amount: 250000,
          type: TransactionType.expense,
          categoryId: h.foodId,
          walletId: h.walletId,
          occurredAt: DateTime(2026, 6, 10)); // June
      await repo.addTransaction(
          amount: 100000,
          type: TransactionType.expense,
          categoryId: h.moveId,
          walletId: h.walletId,
          occurredAt: DateTime(2026, 5, 9)); // May — same Q2
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('250.000 ₫'), findsWidgets); // month: June only
      expect(find.text('350.000 ₫'), findsNothing);

      await tester.tap(find.text('Quý'));
      await tester.pump();
      expect(find.text('Quý 2/2026'), findsOneWidget);
      expect(find.text('350.000 ₫'), findsWidgets); // May + June

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('period nav steps by granularity; Năm steps a year',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('reportsNextPeriod')));
      await tester.pump();
      expect(find.text('Tháng 7/2026'), findsOneWidget);

      await tester.tap(find.text('Năm'));
      await tester.pump();
      expect(find.text('Năm 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reportsNextPeriod')));
      await tester.pump();
      expect(find.text('Năm 2027'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('trend stats: average + peak rows', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      final repo = AppRepository(db);
      final h = await handles(db);
      await repo.addTransaction(
          amount: 600000,
          type: TransactionType.expense,
          categoryId: h.foodId,
          walletId: h.walletId,
          occurredAt: DateTime(2026, 6, 10));
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Trung bình / tháng'), findsOneWidget);
      expect(find.text('100.000 ₫'), findsWidgets); // 600k / 6 = 100k
      expect(find.text('Tháng cao nhất'), findsOneWidget);
      expect(find.byType(PeriodFlowCard), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('empty period: donut empty state, no breakdown', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Chưa có chi tiêu kỳ này'), findsOneWidget);
      expect(find.text('Theo danh mục'), findsNothing);
      expect(find.text('Chưa có thu chi nào'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('dashboard entry to reports', () {
    testWidgets('bar_chart icon on the dashboard opens ReportsScreen',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      bigView(tester);

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildTheme(AppThemeStyle.classic, Brightness.light),
          home: const HomeShell(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('openReports')), findsOneWidget);
      await tester.tap(find.byKey(const Key('openReports')));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo'), findsOneWidget); // ReportsScreen app bar

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
