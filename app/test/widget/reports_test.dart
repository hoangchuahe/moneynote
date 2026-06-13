import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/domain/reports.dart';
import 'package:moneynote/features/reports/reports_screen.dart';
import 'package:moneynote/features/reports/widgets/expense_pie_card.dart';
import 'package:moneynote/features/reports/widgets/monthly_flow_card.dart';
import 'package:moneynote/features/home/home_shell.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

Widget host(Widget child) => MaterialApp(
      theme: buildTheme(AppThemeStyle.classic, Brightness.light),
      home: Scaffold(body: child),
    );

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(setupSqliteForTests);

  group('ExpensePieCard', () {
    testWidgets('renders legend with names, amounts and percents',
        (tester) async {
      bigView(tester);
      await tester.pumpWidget(host(const ExpensePieCard(slices: [
        CategorySlice(
            label: 'Ăn uống', color: Color(0xFFEF5350), total: 600000),
        CategorySlice(label: 'Đi lại', color: Color(0xFF42A5F5), total: 400000),
      ])));
      await tester.pump();

      expect(find.text('Chi theo danh mục'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('600.000 ₫'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('1.000.000 ₫'), findsOneWidget); // tổng cạnh tiêu đề
    });

    testWidgets('shows empty state when no slices', (tester) async {
      bigView(tester);
      await tester.pumpWidget(host(const ExpensePieCard(slices: [])));
      await tester.pump();
      expect(find.text('Chưa có chi tiêu tháng này'), findsOneWidget);
    });
  });

  group('MonthlyFlowCard', () {
    testWidgets('renders Thu/Chi legend and month labels', (tester) async {
      bigView(tester);
      final flows = [
        for (var m = 1; m <= 6; m++)
          MonthlyFlow(DateTime(2026, m, 1), 1000000 * m, 500000 * m),
      ];
      await tester.pumpWidget(host(MonthlyFlowCard(flows: flows)));
      await tester.pump();

      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Chi'), findsOneWidget);
      expect(find.text('T1'), findsOneWidget);
      expect(find.text('T6'), findsOneWidget);
    });

    testWidgets('shows empty state when all months are zero', (tester) async {
      bigView(tester);
      final flows = [
        for (var m = 1; m <= 6; m++) MonthlyFlow(DateTime(2026, m, 1), 0, 0),
      ];
      await tester.pumpWidget(host(MonthlyFlowCard(flows: flows)));
      await tester.pump();
      expect(find.text('Chưa có thu chi nào'), findsOneWidget);
    });
  });

  group('ReportsScreen', () {
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

    testWidgets('shows the expense category for the selected month',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      final repo = AppRepository(db);
      final cats = await db.select(db.categories).get();
      final food = cats.firstWhere((c) => c.name == 'Ăn uống');
      final w = (await db.select(db.wallets).get()).first;
      await repo.addTransaction(
        amount: 250000,
        type: TransactionType.expense,
        categoryId: food.id,
        walletId: w.id,
        occurredAt: DateTime(2026, 6, 10),
      );
      addTearDown(db.close);
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Báo cáo'), findsOneWidget);
      expect(find.text('Tháng 6/2026'), findsOneWidget);
      expect(find.text('Ăn uống'), findsWidgets);
      expect(find.text('250.000 ₫'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('prev-month button moves the selected month', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      addTearDown(db.close);
      bigView(tester);

      await tester.pumpWidget(app(db, DateTime(2026, 6, 1)));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('reportsPrevMonth')));
      await tester.pump();
      expect(find.text('Tháng 5/2026'), findsOneWidget);

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

      expect(find.text('Báo cáo'), findsOneWidget); // app bar của ReportsScreen

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
