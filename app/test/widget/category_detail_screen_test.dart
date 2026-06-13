import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/categories/category_detail_screen.dart';
import 'package:moneynote/features/categories/category_edit_screen.dart';
import 'package:moneynote/features/transactions/transaction_detail_screen.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
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

  Future<void> pumpDetail(
      WidgetTester tester, AppDatabase db, String id) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: CategoryDetailScreen(id)),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Seeds a Chi category (pale lime → dark on-color) with one txn in it and one
  // in another category. Returns the target category id.
  Future<String> seedCat(AppDatabase db) async {
    final repo = AppRepository(db);
    final target = await repo.addCategory(
        name: 'Cà phê',
        type: CategoryType.expense,
        icon: 'local_cafe',
        color: 0xFF7CB342);
    final cats = await repo.watchCategories().first;
    final other = cats.firstWhere((c) => c.name != 'Cà phê');
    final wallets = await repo.watchWallets().first;
    final w = wallets.first;
    await repo.addTransaction(
        amount: 40000,
        type: TransactionType.expense,
        categoryId: target.id,
        walletId: w.id,
        note: 'ly nâu');
    await repo.addTransaction(
        amount: 99000,
        type: TransactionType.expense,
        categoryId: other.id,
        walletId: w.id,
        note: 'khác');
    return target.id;
  }

  testWidgets('header: name·Chi + all-time total; only this category txns',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    late String id;
    await tester.runAsync(() async {
      id = await seedCat(db);
    });
    await pumpDetail(tester, db, id);

    expect(find.text('Cà phê · Chi'), findsOneWidget);
    expect(find.text('40.000 ₫'), findsWidgets); // header total (+ tile)
    expect(find.text('ly nâu'), findsOneWidget);
    expect(find.text('khác'), findsNothing);

    // pale lime → dark adaptive header text (RGB 0,0,0, not white)
    final title = tester.widget<Text>(find.text('Cà phê · Chi'));
    expect(title.style!.color!.toARGB32() & 0x00FFFFFF, 0x000000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Sửa → edit; tile → txn detail; null guard', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);
    late String id;
    await tester.runAsync(() async {
      id = await seedCat(db);
    });

    await pumpDetail(tester, db, 'nope');
    expect(find.text('Danh mục không tồn tại'), findsOneWidget);

    await pumpDetail(tester, db, id);
    await tester.tap(find.byKey(const Key('categoryEdit')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryEditScreen), findsOneWidget);

    await pumpDetail(tester, db, id);
    await tester.tap(find.byType(TransactionTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TransactionDetailScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('delete: confirm → soft-deleted, popped, no not-found flash',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    bigView(tester);
    late String id;
    await tester.runAsync(() async {
      id = await seedCat(db);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CategoryDetailScreen(id))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryDetailScreen), findsNothing);
    expect(find.text('Danh mục không tồn tại'), findsNothing);
    final cats = await tester.runAsync(() => repo.watchCategories().first);
    expect(cats!.where((c) => c.id == id), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
