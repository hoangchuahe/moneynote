import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/home/home_shell.dart';
import 'package:moneynote/features/home/widgets/floating_pill_nav.dart';
import 'package:moneynote/features/settings/settings_screen.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(440, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<AppDatabase> setupDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    return db;
  }

  Future<void> pumpShell(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: buildTheme(AppThemeStyle.classic, Brightness.light),
        home: const HomeShell(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('drops Material chrome, shows the floating pill', (tester) async {
    final db = await setupDb();
    addTearDown(db.close);
    bigView(tester);
    await pumpShell(tester, db);

    expect(find.text('Tổng quan'), findsWidgets); // header built (gate)
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(FloatingPillNav), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('tapping a pill tab switches the page header', (tester) async {
    final db = await setupDb();
    addTearDown(db.close);
    bigView(tester);
    await pumpShell(tester, db);

    await tester.tap(find.byKey(const Key('navTab_2')));
    await tester.pump();
    expect(find.text('Ví'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('IndexedStack retains the Transactions search text across tabs',
      (tester) async {
    final db = await setupDb();
    addTearDown(db.close);
    bigView(tester);
    await pumpShell(tester, db);

    await tester.tap(find.byKey(const Key('navTab_1')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('searchField')), 'phở');
    await tester.pump();
    await tester.tap(find.byKey(const Key('navTab_2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('navTab_1')));
    await tester.pump();
    expect(find.text('phở'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('center + always opens Add-transaction, even from the Ví tab',
      (tester) async {
    final db = await setupDb();
    addTearDown(db.close);
    bigView(tester);
    await pumpShell(tester, db);

    await tester.tap(find.byKey(const Key('navTab_2'))); // Ví
    await tester.pump();
    await tester.tap(find.byKey(const Key('navAdd')));
    await tester.pumpAndSettle();
    expect(find.byType(AddTransactionScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Ví header + opens the add-wallet dialog', (tester) async {
    final db = await setupDb();
    addTearDown(db.close);
    bigView(tester);
    await pumpShell(tester, db);

    await tester.tap(find.byKey(const Key('navTab_2')));
    await tester.pump();
    await tester.tap(find.byTooltip('Thêm ví'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm ví'), findsOneWidget); // AlertDialog title

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('settings gear is present on every tab and opens Settings',
      (tester) async {
    final db = await setupDb();
    addTearDown(db.close);
    bigView(tester);
    await pumpShell(tester, db);

    await tester.tap(find.byKey(const Key('navTab_1'))); // Giao dịch
    await tester.pump();
    expect(find.byKey(const Key('openSettings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('openSettings')));
    await tester.pump(); // start the push transition
    await tester.pump(const Duration(milliseconds: 400)); // finish it
    // SettingsScreen watches prefs (SharedPreferences) which stays loading in
    // this DB-only test, so it shows a spinner — pumpAndSettle would never
    // settle. Asserting presence is enough to prove navigation.
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
