import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/categories/categories_screen.dart';
import 'package:moneynote/features/wallets/wallets_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  Future<AppDatabase> setupDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    return db;
  }

  testWidgets('ví tiền mặt hiện icon payments', (tester) async {
    final db = await setupDb();
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: WalletsScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.payments), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('danh mục Ăn uống hiện icon restaurant', (tester) async {
    final db = await setupDb();
    addTearDown(db.close);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: CategoriesScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
