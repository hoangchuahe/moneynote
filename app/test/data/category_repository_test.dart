import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  test('updateCategory mutates in place, bumps updatedAt, no duplicate', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = AppRepository(db);

    final c = await repo.addCategory(
        name: 'Cũ', type: CategoryType.expense, icon: 'category', color: 0xFF9E9E9E);
    final before = c.updatedAt;
    // Drift stores DateTime as unix *seconds*, so a sub-second gap truncates to
    // the same value; wait > 1s (matches wallet_repository_test) so isAfter holds.
    await Future<void>.delayed(const Duration(seconds: 2));

    await repo.updateCategory(
        id: c.id,
        name: 'Ăn uống',
        type: CategoryType.income,
        icon: 'local_cafe',
        color: 0xFF13A4B8);

    final all = await repo.watchCategories().first;
    expect(all.length, 1); // no duplicate insert
    final u = all.single;
    expect(u.name, 'Ăn uống');
    expect(u.type, CategoryType.income);
    expect(u.icon, 'local_cafe');
    expect(u.color, 0xFF13A4B8);
    expect(u.updatedAt.isAfter(before), isTrue);
    expect(u.createdAt, c.createdAt); // untouched
    expect(u.deletedAt, isNull);
  });

  test('addCategory keeps defaults when icon/color omitted', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = AppRepository(db);
    final c = await repo.addCategory(name: 'X', type: CategoryType.expense);
    expect(c.icon, 'category');
    expect(c.color, 0xFF9E9E9E);
  });
}
