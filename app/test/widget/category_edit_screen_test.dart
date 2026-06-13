import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/categories/category_edit_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('add: name + icon + colour + type are saved; preview updates',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: CategoryEditScreen()),
    ));

    await tester.enterText(find.byKey(const Key('categoryName')), 'Cà phê');
    await tester.tap(find.byKey(const Key('icon_local_cafe')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('swatch_${0xFF13A4B8}')));
    await tester.pump();

    final preview = tester.widget<CategoryIconBox>(
        find.byKey(const Key('categoryPreview')));
    expect(preview.iconName, 'local_cafe');
    expect(preview.color, 0xFF13A4B8);

    await tester.tap(find.byKey(const Key('saveCategory')));
    await tester.pump(const Duration(milliseconds: 300));

    final cats = await tester.runAsync(() => repo.watchCategories().first);
    final added = cats!.firstWhere((c) => c.name == 'Cà phê');
    expect(added.icon, 'local_cafe');
    expect(added.color, 0xFF13A4B8);
    expect(added.type, CategoryType.expense); // default Chi, untouched
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('edit: pre-fills and updates in place (no duplicate)',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    late Category existing;
    await tester.runAsync(() async {
      existing = await repo.addCategory(
          name: 'Cũ',
          type: CategoryType.expense,
          icon: 'category',
          color: 0xFF9E9E9E);
    });
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: CategoryEditScreen(existing: existing)),
    ));
    expect(find.text('Cũ'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('categoryName')), 'Mới');
    await tester.tap(find.byKey(const Key('icon_flight')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveCategory')));
    await tester.pump(const Duration(milliseconds: 300));

    final cats = await tester.runAsync(() => repo.watchCategories().first);
    expect(cats!.where((c) => c.name == 'Cũ'), isEmpty);
    final u = cats.firstWhere((c) => c.id == existing.id);
    expect(u.name, 'Mới');
    expect(u.icon, 'flight');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('empty name does not save and keeps the screen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    bigView(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: CategoryEditScreen()),
    ));
    final before =
        (await tester.runAsync(() => repo.watchCategories().first))!.length;
    await tester.tap(find.byKey(const Key('saveCategory')));
    await tester.pump(const Duration(milliseconds: 300));
    final after =
        (await tester.runAsync(() => repo.watchCategories().first))!.length;
    expect(after, before);
    expect(find.byType(CategoryEditScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
