# Recurring Transactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add recurring transactions (a `RecurringRule` per the spec) that auto-create the latest-due transaction on app launch, with a Settings-reachable screen to manage rules. No notifications, no new dependency.

**Architecture:** Anchor-based pure date logic (`domain/recurring.dart`) computes the most-recent occurrence ≤ today from `startDate`+`cycle`; `repository.materializeDueRecurrings(today)` creates one transaction per due rule atomically and advances `lastRunAt`; the launch path (`main.dart` `_seedProvider`) calls it best-effort; a `RecurringScreen` + `RecurringEditScreen` manage rules. `UI → providers → domain → data`.

**Tech Stack:** Dart 3, Flutter, Riverpod 2, Drift (SQLite), no new packages.

**Spec:** `docs/superpowers/specs/2026-06-13-recurring-design.md`

**Conventions (CLAUDE.md):** run `flutter`/`dart` from `app/`. Money is `int` đồng VND > 0. **After editing `lib/data/database.dart` you MUST regen Drift** (`dart run build_runner build --delete-conflicting-outputs`) before code/tests referencing `db.recurrings`/`RecurringsCompanion`/`Recurring` will compile. TDD: failing test → see it fail → minimal impl → see it pass → `flutter analyze` clean → commit test+impl together. If `flutter test` hangs printing nothing, kill orphans: `taskkill //F //IM flutter_tester.exe` then `taskkill //F //IM dart.exe`.

---

### Task 1: Schema — `Recurrings` table + migration + Drift regen

**Files:**
- Modify: `app/lib/data/database.dart`
- Regen: `app/lib/data/database.g.dart`
- Test: `app/test/data/recurring_repository_test.dart`

- [ ] **Step 1: Write the failing test** — create `app/test/data/recurring_repository_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';

void main() {
  test('Recurrings table round-trips a row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 6, 13);
    await db.into(db.recurrings).insert(RecurringsCompanion.insert(
          id: 'r1',
          amount: 50000,
          type: TransactionType.expense,
          walletId: 'w1',
          cycle: RecurringCycle.monthly,
          startDate: DateTime(2026, 6, 5),
          createdAt: now,
          updatedAt: now,
          note: const Value('Netflix'),
        ));
    final row = await (db.select(db.recurrings)..where((t) => t.id.equals('r1'))).getSingle();
    expect(row.amount, 50000);
    expect(row.type, TransactionType.expense);
    expect(row.cycle, RecurringCycle.monthly);
    expect(row.startDate, DateTime(2026, 6, 5));
    expect(row.lastRunAt, isNull);
    expect(row.deletedAt, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `app/`): `flutter test test/data/recurring_repository_test.dart`
Expected: compile FAIL — `db.recurrings`, `RecurringsCompanion`, `RecurringCycle` don't exist.

- [ ] **Step 3: Edit the schema** — in `app/lib/data/database.dart`:

After the existing `enum WalletType { ... }` line add:
```dart
enum RecurringCycle { daily, weekly, monthly, yearly }
```

After the `Budgets` table class (before the `@DriftDatabase` annotation) add:
```dart
class Recurrings extends Table {
  TextColumn get id => text()();
  IntColumn get amount => integer()(); // đồng VND, always > 0
  IntColumn get type => intEnum<TransactionType>()(); // income | expense (no transfer)
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get cycle => intEnum<RecurringCycle>()();
  DateTimeColumn get startDate => dateTime()(); // anchor / first occurrence (date-only)
  DateTimeColumn get lastRunAt => dateTime().nullable()(); // occurredAt of last auto-created txn
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Change the `@DriftDatabase(tables: [...])` line to include `Recurrings`:
```dart
@DriftDatabase(tables: [Wallets, Categories, Transactions, MerchantMemories, Budgets, Recurrings])
```

Bump `schemaVersion` from `5` to `6`:
```dart
  @override
  int get schemaVersion => 6;
```

In `MigrationStrategy`, add the index helper call to `onCreate` and a `from < 6` branch to `onUpgrade`:
```dart
        onCreate: (m) async {
          await m.createAll();
          await _ensureMerchantIndex();
          await _ensureTransactionIndexes();
          await _ensureRecurringIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(merchantMemories);
          if (from < 3) await _ensureMerchantIndex();
          if (from < 4) await m.createTable(budgets);
          if (from < 5) await _ensureTransactionIndexes();
          if (from < 6) {
            await m.createTable(recurrings);
            await _ensureRecurringIndexes();
          }
        },
```

Add the helper next to `_ensureTransactionIndexes`:
```dart
  Future<void> _ensureRecurringIndexes() => customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recurrings_deleted_at '
      'ON recurrings (deleted_at)');
```

- [ ] **Step 4: Regen Drift**

Run (from `app/`): `dart run build_runner build --delete-conflicting-outputs`
Expected: succeeds; `lib/data/database.g.dart` now has `Recurring`, `RecurringsCompanion`, `db.recurrings`.

- [ ] **Step 5: Run test to verify it passes**

Run (from `app/`): `flutter test test/data/recurring_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze + commit**

```bash
flutter analyze
git add lib/data/database.dart lib/data/database.g.dart test/data/recurring_repository_test.dart
git commit -m "feat(recurring): Recurrings table + migration v6 (#8)"
```
Expected: analyze 0 issues. (`database.g.dart` is gitignored by `*.g.dart`; `git add` of it will be a no-op or refused — that's fine, it is regenerated on each machine. Do NOT force-add it.)

---

### Task 2: Domain — `daysInMonth` + `clampedDate`

**Files:**
- Create: `app/lib/domain/recurring.dart`
- Test: `app/test/domain/recurring_test.dart`

- [ ] **Step 1: Write the failing test** — create `app/test/domain/recurring_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/domain/recurring.dart';

void main() {
  group('daysInMonth', () {
    test('common months', () {
      expect(daysInMonth(2026, 1), 31);
      expect(daysInMonth(2026, 4), 30);
    });
    test('February leap vs non-leap', () {
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2025, 2), 28);
    });
  });

  group('clampedDate', () {
    test('clamps an overlong day to month end', () {
      expect(clampedDate(2026, 2, 31), DateTime(2026, 2, 28));
      expect(clampedDate(2024, 2, 31), DateTime(2024, 2, 29));
      expect(clampedDate(2026, 4, 31), DateTime(2026, 4, 30));
    });
    test('keeps a valid day', () {
      expect(clampedDate(2026, 6, 5), DateTime(2026, 6, 5));
    });
    test('normalizes month overflow into the next year', () {
      expect(clampedDate(2026, 13, 10), DateTime(2027, 1, 10));
    });
    test('normalizes month underflow into the previous year', () {
      expect(clampedDate(2026, 0, 10), DateTime(2025, 12, 10));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `app/`): `flutter test test/domain/recurring_test.dart`
Expected: compile FAIL — `recurring.dart` / `daysInMonth` / `clampedDate` undefined.

- [ ] **Step 3: Write minimal implementation** — create `app/lib/domain/recurring.dart`:

```dart
import 'package:moneynote/data/database.dart';

/// Number of days in [month] (1..12) of [year]. daysInMonth(2024, 2) == 29.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Builds year-month-day, normalizing month overflow/underflow into the year,
/// then CLAMPS the day to the month end (clampedDate(2026, 2, 31) -> 2026-02-28).
DateTime clampedDate(int year, int month, int day) {
  final norm = DateTime(year, month, 1); // DateTime normalizes out-of-range month
  final dim = daysInMonth(norm.year, norm.month);
  return DateTime(norm.year, norm.month, day <= dim ? day : dim);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `app/`): `flutter test test/domain/recurring_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/domain/recurring.dart test/domain/recurring_test.dart
git commit -m "feat(recurring): daysInMonth + clampedDate date helpers (#8)"
```

---

### Task 3: Domain — `mostRecentOccurrence` + `nextOccurrenceAfter`

**Files:**
- Modify: `app/lib/domain/recurring.dart` (append)
- Test: `app/test/domain/recurring_test.dart` (append groups inside existing `main()`)

- [ ] **Step 1: Write the failing test** — append these groups inside `main()` in `app/test/domain/recurring_test.dart`:

```dart
  group('mostRecentOccurrence', () {
    test('daily returns today when started in the past', () {
      expect(mostRecentOccurrence(DateTime(2026, 6, 1), RecurringCycle.daily, DateTime(2026, 6, 13)),
          DateTime(2026, 6, 13));
    });
    test('daily/weekly start == today returns today/start', () {
      expect(mostRecentOccurrence(DateTime(2026, 6, 13), RecurringCycle.daily, DateTime(2026, 6, 13)),
          DateTime(2026, 6, 13));
      expect(mostRecentOccurrence(DateTime(2026, 6, 13), RecurringCycle.weekly, DateTime(2026, 6, 13)),
          DateTime(2026, 6, 13));
    });
    test('weekly steps in exact 7-calendar-day multiples', () {
      final start = DateTime(2026, 6, 1); // a Monday
      expect(mostRecentOccurrence(start, RecurringCycle.weekly, DateTime(2026, 6, 7)), DateTime(2026, 6, 1));
      expect(mostRecentOccurrence(start, RecurringCycle.weekly, DateTime(2026, 6, 8)), DateTime(2026, 6, 8));
      expect(mostRecentOccurrence(start, RecurringCycle.weekly, DateTime(2026, 6, 21)), DateTime(2026, 6, 15));
    });
    test('monthly anchored on the 31st clamps and tracks most-recent', () {
      final s = DateTime(2026, 1, 31);
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 2, 15)), DateTime(2026, 1, 31));
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 2, 28)), DateTime(2026, 2, 28));
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 3, 1)), DateTime(2026, 2, 28));
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 3, 31)), DateTime(2026, 3, 31));
      expect(mostRecentOccurrence(s, RecurringCycle.monthly, DateTime(2026, 4, 30)), DateTime(2026, 4, 30));
    });
    test('yearly leap-day anchor clamps to Feb 28 in non-leap years', () {
      final s = DateTime(2024, 2, 29);
      expect(mostRecentOccurrence(s, RecurringCycle.yearly, DateTime(2025, 2, 28)), DateTime(2025, 2, 28));
      expect(mostRecentOccurrence(s, RecurringCycle.yearly, DateTime(2025, 3, 1)), DateTime(2025, 2, 28));
      expect(mostRecentOccurrence(s, RecurringCycle.yearly, DateTime(2028, 3, 1)), DateTime(2028, 2, 29));
    });
    test('returns null when start is after today', () {
      expect(mostRecentOccurrence(DateTime(2026, 7, 1), RecurringCycle.daily, DateTime(2026, 6, 13)), isNull);
      expect(mostRecentOccurrence(DateTime(2026, 7, 1), RecurringCycle.monthly, DateTime(2026, 6, 13)), isNull);
    });
    test('monthly occurrence sequence (day 31) strictly increases by full date', () {
      final s = DateTime(2026, 1, 31);
      final seq = [
        for (final t in [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 30)])
          mostRecentOccurrence(s, RecurringCycle.monthly, t)!
      ];
      for (var i = 1; i < seq.length; i++) {
        expect(seq[i].isAfter(seq[i - 1]), isTrue);
      }
    });
  });

  group('nextOccurrenceAfter', () {
    test('daily is tomorrow', () {
      expect(nextOccurrenceAfter(DateTime(2026, 6, 1), RecurringCycle.daily, DateTime(2026, 6, 13)),
          DateTime(2026, 6, 14));
    });
    test('weekly is the next 7-day boundary', () {
      final s = DateTime(2026, 6, 1);
      expect(nextOccurrenceAfter(s, RecurringCycle.weekly, DateTime(2026, 6, 7)), DateTime(2026, 6, 8));
      expect(nextOccurrenceAfter(s, RecurringCycle.weekly, DateTime(2026, 6, 8)), DateTime(2026, 6, 15));
    });
    test('monthly clamp: start Jan 31, today Feb 28 -> Mar 31', () {
      expect(nextOccurrenceAfter(DateTime(2026, 1, 31), RecurringCycle.monthly, DateTime(2026, 2, 28)),
          DateTime(2026, 3, 31));
    });
    test('yearly Feb-29 anchor: today 2025-02-28 -> 2026-02-28', () {
      expect(nextOccurrenceAfter(DateTime(2024, 2, 29), RecurringCycle.yearly, DateTime(2025, 2, 28)),
          DateTime(2026, 2, 28));
    });
    test('not yet started returns the start date', () {
      expect(nextOccurrenceAfter(DateTime(2026, 7, 1), RecurringCycle.monthly, DateTime(2026, 6, 13)),
          DateTime(2026, 7, 1));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `app/`): `flutter test test/domain/recurring_test.dart`
Expected: FAIL — `mostRecentOccurrence` / `nextOccurrenceAfter` undefined.

- [ ] **Step 3: Write minimal implementation** — append to `app/lib/domain/recurring.dart`:

```dart
/// Calendar-day gap between two date-only DateTimes, DST-safe (computed in UTC
/// so a spring-forward day cannot truncate a 7-day gap to 6).
int _calendarDaysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

/// [d] (date-only) plus [days] calendar days, returned as a local date-only.
DateTime _addCalendarDays(DateTime d, int days) {
  final u = DateTime.utc(d.year, d.month, d.day).add(Duration(days: days));
  return DateTime(u.year, u.month, u.day);
}

/// Most recent occurrence <= [today] from [start] by [cycle] (date-only).
/// null if start (date) is after today.
DateTime? mostRecentOccurrence(DateTime start, RecurringCycle cycle, DateTime today) {
  final s = DateTime(start.year, start.month, start.day);
  final t = DateTime(today.year, today.month, today.day);
  if (s.isAfter(t)) return null;
  switch (cycle) {
    case RecurringCycle.daily:
      return t;
    case RecurringCycle.weekly:
      final k = _calendarDaysBetween(s, t) ~/ 7;
      return _addCalendarDays(s, 7 * k);
    case RecurringCycle.monthly:
      var diff = (t.year - s.year) * 12 + (t.month - s.month);
      var occ = clampedDate(s.year, s.month + diff, s.day);
      if (occ.isAfter(t)) occ = clampedDate(s.year, s.month + (--diff), s.day);
      return occ;
    case RecurringCycle.yearly:
      var diff = t.year - s.year;
      var occ = clampedDate(s.year + diff, s.month, s.day);
      if (occ.isAfter(t)) occ = clampedDate(s.year + (--diff), s.month, s.day);
      return occ;
  }
}

/// Next occurrence strictly after [today] (for the "Kỳ tới" display).
DateTime nextOccurrenceAfter(DateTime start, RecurringCycle cycle, DateTime today) {
  final s = DateTime(start.year, start.month, start.day);
  final t = DateTime(today.year, today.month, today.day);
  if (s.isAfter(t)) return s;
  switch (cycle) {
    case RecurringCycle.daily:
      return _addCalendarDays(t, 1);
    case RecurringCycle.weekly:
      final k = _calendarDaysBetween(s, t) ~/ 7;
      return _addCalendarDays(s, 7 * (k + 1));
    case RecurringCycle.monthly:
      var diff = (t.year - s.year) * 12 + (t.month - s.month);
      var occ = clampedDate(s.year, s.month + diff, s.day);
      while (!occ.isAfter(t)) occ = clampedDate(s.year, s.month + (++diff), s.day);
      return occ;
    case RecurringCycle.yearly:
      var diff = t.year - s.year;
      var occ = clampedDate(s.year + diff, s.month, s.day);
      while (!occ.isAfter(t)) occ = clampedDate(s.year + (++diff), s.month, s.day);
      return occ;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `app/`): `flutter test test/domain/recurring_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/domain/recurring.dart test/domain/recurring_test.dart
git commit -m "feat(recurring): occurrence date computation (#8)"
```

---

### Task 4: Repository — CRUD + validation + cascade + provider

**Files:**
- Modify: `app/lib/data/repository.dart`
- Modify: `app/lib/state/providers.dart`
- Test: `app/test/data/recurring_repository_test.dart` (append inside existing `main()`)

- [ ] **Step 1: Write the failing test** — append inside `main()` in `app/test/data/recurring_repository_test.dart` (the imports `package:moneynote/data/repository.dart`, `package:moneynote/data/seed.dart` will be needed — add them to the top of the file):

```dart
  group('recurring CRUD', () {
    Future<(AppDatabase, AppRepository)> setup() async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      return (db, AppRepository(db));
    }

    test('addRecurring persists and watchRecurrings returns it', () async {
      final (db, repo) = await setup();
      addTearDown(db.close);
      final w = (await db.select(db.wallets).get()).first;
      final r = await repo.addRecurring(
        amount: 50000, type: TransactionType.expense, walletId: w.id,
        cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5), note: 'Netflix',
      );
      expect(r.amount, 50000);
      expect(r.startDate, DateTime(2026, 6, 5));
      final list = await (db.select(db.recurrings)..where((t) => t.deletedAt.isNull())).get();
      expect(list.length, 1);
    });

    test('addRecurring rejects amount <= 0 and transfer type', () async {
      final (db, repo) = await setup();
      addTearDown(db.close);
      final w = (await db.select(db.wallets).get()).first;
      expect(
        () => repo.addRecurring(amount: 0, type: TransactionType.expense, walletId: w.id,
            cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5)),
        throwsArgumentError,
      );
      expect(
        () => repo.addRecurring(amount: 1000, type: TransactionType.transfer, walletId: w.id,
            cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5)),
        throwsArgumentError,
      );
    });

    test('updateRecurring resets lastRunAt when cycle or startDate changes', () async {
      final (db, repo) = await setup();
      addTearDown(db.close);
      final w = (await db.select(db.wallets).get()).first;
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: w.id, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5));
      await (db.update(db.recurrings)..where((t) => t.id.equals(r.id)))
          .write(RecurringsCompanion(lastRunAt: Value(DateTime(2026, 6, 5))));

      // amount-only change keeps lastRunAt
      await repo.updateRecurring(r.id, amount: 60000, type: TransactionType.expense,
          walletId: w.id, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5));
      var row = await (db.select(db.recurrings)..where((t) => t.id.equals(r.id))).getSingle();
      expect(row.lastRunAt, DateTime(2026, 6, 5));

      // cycle change resets lastRunAt
      await repo.updateRecurring(r.id, amount: 60000, type: TransactionType.expense,
          walletId: w.id, cycle: RecurringCycle.weekly, startDate: DateTime(2026, 6, 5));
      row = await (db.select(db.recurrings)..where((t) => t.id.equals(r.id))).getSingle();
      expect(row.lastRunAt, isNull);
    });

    test('softDeleteWallet cascades to recurring rules on that wallet', () async {
      final (db, repo) = await setup();
      addTearDown(db.close);
      final w = (await db.select(db.wallets).get()).first;
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: w.id, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5));
      await repo.softDeleteWallet(w.id);
      final row = await (db.select(db.recurrings)..where((t) => t.id.equals(r.id))).getSingle();
      expect(row.deletedAt, isNotNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `app/`): `flutter test test/data/recurring_repository_test.dart`
Expected: FAIL — `repo.addRecurring` / `updateRecurring` undefined; cascade test fails.

- [ ] **Step 3: Write minimal implementation** — in `app/lib/data/repository.dart`, add these methods to `AppRepository`:

```dart
  Stream<List<Recurring>> watchRecurrings() => (db.select(db.recurrings)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  void _validateRecurring(int amount, TransactionType type) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'phải > 0 (đồng VND)');
    }
    if (type == TransactionType.transfer) {
      throw ArgumentError.value(
          type, 'type', 'không được là transfer trong định kỳ v1');
    }
  }

  Future<Recurring> addRecurring({
    required int amount,
    required TransactionType type,
    String? categoryId,
    required String walletId,
    String note = '',
    required RecurringCycle cycle,
    required DateTime startDate,
  }) async {
    _validateRecurring(amount, type);
    final now = DateTime.now();
    final id = _uuid.v4();
    final sd = DateTime(startDate.year, startDate.month, startDate.day);
    await db.into(db.recurrings).insert(RecurringsCompanion.insert(
          id: id,
          amount: amount,
          type: type,
          categoryId: Value(categoryId),
          walletId: walletId,
          note: Value(note),
          cycle: cycle,
          startDate: sd,
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.recurrings)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateRecurring(
    String id, {
    required int amount,
    required TransactionType type,
    String? categoryId,
    required String walletId,
    String note = '',
    required RecurringCycle cycle,
    required DateTime startDate,
  }) async {
    _validateRecurring(amount, type);
    final sd = DateTime(startDate.year, startDate.month, startDate.day);
    final existing =
        await (db.select(db.recurrings)..where((t) => t.id.equals(id))).getSingle();
    final anchorChanged = existing.cycle != cycle || existing.startDate != sd;
    await (db.update(db.recurrings)..where((t) => t.id.equals(id))).write(
      RecurringsCompanion(
        amount: Value(amount),
        type: Value(type),
        categoryId: Value(categoryId),
        walletId: Value(walletId),
        note: Value(note),
        cycle: Value(cycle),
        startDate: Value(sd),
        lastRunAt: anchorChanged ? const Value(null) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDeleteRecurring(String id) async {
    final now = DateTime.now();
    await (db.update(db.recurrings)..where((t) => t.id.equals(id))).write(
      RecurringsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
```

In the existing `softDeleteWallet` method, inside its `db.transaction(() async { ... })` block, after the transactions-cascade write, add a recurring-rules cascade:
```dart
      await (db.update(db.recurrings)..where((t) => t.walletId.equals(id))).write(
        RecurringsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
```

In `app/lib/state/providers.dart`, after `budgetsProvider`, add:
```dart
final recurringsProvider = StreamProvider<List<Recurring>>(
  (ref) => ref.watch(repositoryProvider).watchRecurrings(),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `app/`): `flutter test test/data/recurring_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/data/repository.dart lib/state/providers.dart test/data/recurring_repository_test.dart
git commit -m "feat(recurring): repository CRUD + wallet cascade + provider (#8)"
```

---

### Task 5: Repository — `materializeDueRecurrings`

**Files:**
- Modify: `app/lib/data/repository.dart`
- Test: `app/test/data/recurring_repository_test.dart` (append inside existing `main()`)

- [ ] **Step 1: Write the failing test** — append inside `main()` in `app/test/data/recurring_repository_test.dart` (add `import 'package:moneynote/domain/recurring.dart';` to the top if not already present):

```dart
  group('materializeDueRecurrings', () {
    Future<(AppDatabase, AppRepository, String)> setup() async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedIfEmpty(db);
      final repo = AppRepository(db);
      final w = (await db.select(db.wallets).get()).first;
      return (db, repo, w.id);
    }

    test('creates one txn at the most-recent occurrence and sets lastRunAt', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      final today = DateTime(2026, 6, 13);
      final created = await repo.materializeDueRecurrings(today);
      expect(created, 1);
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.length, 1);
      expect(txns.single.amount, 50000);
      expect(txns.single.occurredAt, DateTime(2026, 6, 5)); // most-recent, not today, not first missed
      final row = await (db.select(db.recurrings)..where((t) => t.id.equals(r.id))).getSingle();
      expect(row.lastRunAt, DateTime(2026, 6, 5));
    });

    test('is idempotent within the same period', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      final today = DateTime(2026, 6, 13);
      expect(await repo.materializeDueRecurrings(today), 1);
      expect(await repo.materializeDueRecurrings(today), 0); // no duplicate
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.length, 1);
    });

    test('advances to a new period on a later day', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      expect(await repo.materializeDueRecurrings(DateTime(2026, 6, 13)), 1);
      expect(await repo.materializeDueRecurrings(DateTime(2026, 7, 13)), 1);
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.length, 2);
    });

    test('dormant multiple periods still creates exactly one (latest)', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      // pretend it last ran 3 months ago
      await (db.update(db.recurrings)..where((t) => t.id.equals(r.id)))
          .write(RecurringsCompanion(lastRunAt: Value(DateTime(2026, 3, 5))));
      final today = DateTime(2026, 6, 13);
      expect(await repo.materializeDueRecurrings(today), 1);
      final txns = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
      expect(txns.length, 1);
      expect(txns.single.occurredAt, DateTime(2026, 6, 5)); // latest, not April/May
    });

    test('future startDate creates nothing', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 12, 5));
      expect(await repo.materializeDueRecurrings(DateTime(2026, 6, 13)), 0);
    });

    test('skips soft-deleted rules', () async {
      final (db, repo, wid) = await setup();
      addTearDown(db.close);
      final r = await repo.addRecurring(amount: 50000, type: TransactionType.expense,
          walletId: wid, cycle: RecurringCycle.monthly, startDate: DateTime(2026, 1, 5));
      await repo.softDeleteRecurring(r.id);
      expect(await repo.materializeDueRecurrings(DateTime(2026, 6, 13)), 0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `app/`): `flutter test test/data/recurring_repository_test.dart`
Expected: FAIL — `repo.materializeDueRecurrings` undefined.

- [ ] **Step 3: Write minimal implementation** — add to `AppRepository` in `app/lib/data/repository.dart` (the file must import the domain occurrence helpers; add `import 'package:moneynote/domain/recurring.dart';` at the top):

```dart
  /// Creates the latest-due transaction for each live rule. Idempotent.
  /// Returns the number created. [today] is injected for determinism/tests.
  Future<int> materializeDueRecurrings(DateTime today) async {
    final rules = await (db.select(db.recurrings)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    var created = 0;
    for (final r in rules) {
      final occ = mostRecentOccurrence(r.startDate, r.cycle, today);
      if (occ == null) continue;
      final lastRun = r.lastRunAt == null
          ? null
          : DateTime(r.lastRunAt!.year, r.lastRunAt!.month, r.lastRunAt!.day);
      if (lastRun != null && !occ.isAfter(lastRun)) continue;
      await db.transaction(() async {
        await addTransaction(
          amount: r.amount,
          type: r.type,
          categoryId: r.categoryId,
          walletId: r.walletId,
          note: r.note,
          occurredAt: occ,
        );
        await (db.update(db.recurrings)..where((t) => t.id.equals(r.id))).write(
          RecurringsCompanion(
              lastRunAt: Value(occ), updatedAt: Value(DateTime.now())),
        );
      });
      created++;
    }
    return created;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `app/`): `flutter test test/data/recurring_repository_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/data/repository.dart test/data/recurring_repository_test.dart
git commit -m "feat(recurring): materializeDueRecurrings on demand (#8)"
```

---

### Task 6: Launch hook — materialize best-effort in `main.dart`

**Files:**
- Modify: `app/lib/main.dart`

(No new test: the launch path uses `DateTime.now()` and is a documented untested seam; the logic is fully covered by Task 5. This task only wires it without breaking startup.)

- [ ] **Step 1: Write minimal implementation** — in `app/lib/main.dart`, change the `_seedProvider` body to also materialize, best-effort. Add the repository import if absent (`import 'package:moneynote/data/repository.dart';`) and replace the provider:

```dart
final _seedProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  await seedIfEmpty(db);
  // Best-effort: auto-create due recurring transactions. Never block launch.
  try {
    await AppRepository(db).materializeDueRecurrings(DateTime.now());
  } catch (_) {
    // Recurring is best-effort; a failure here must not stop the app starting.
  }
});
```

- [ ] **Step 2: Verify the app analyzes and the full suite still passes**

Run (from `app/`): `flutter analyze` then `flutter test`
Expected: analyze 0 issues; all tests pass (no regression — the launch change is exercised indirectly and Task 5 covers the logic).

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(recurring): materialize due rules on app launch (#8)"
```

---

### Task 7: UI — `RecurringEditScreen` (add/edit form)

**Files:**
- Create: `app/lib/features/recurring/recurring_edit_screen.dart`
- Test: `app/test/widget/recurring_test.dart`

- [ ] **Step 1: Write the failing test** — create `app/test/widget/recurring_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/recurring/recurring_edit_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('RecurringEditScreen adds a rule', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: RecurringEditScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('recurringAmount')), '50000');
    await tester.tap(find.byKey(const Key('recurringSave')));
    await tester.pump(const Duration(milliseconds: 300));

    final rules = await (db.select(db.recurrings)..where((t) => t.deletedAt.isNull())).get();
    expect(rules.length, 1);
    expect(rules.single.amount, 50000);
    expect(rules.single.type, TransactionType.expense);
    expect(rules.single.cycle, RecurringCycle.monthly);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `app/`): `flutter test test/widget/recurring_test.dart`
Expected: compile FAIL — `recurring_edit_screen.dart` / `RecurringEditScreen` undefined.

- [ ] **Step 3: Write minimal implementation** — create `app/lib/features/recurring/recurring_edit_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/input_formatters.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/state/providers.dart';

String cycleLabel(RecurringCycle c) => switch (c) {
      RecurringCycle.daily => 'Hàng ngày',
      RecurringCycle.weekly => 'Hàng tuần',
      RecurringCycle.monthly => 'Hàng tháng',
      RecurringCycle.yearly => 'Hàng năm',
    };

class RecurringEditScreen extends ConsumerStatefulWidget {
  const RecurringEditScreen({super.key, this.existing});

  final Recurring? existing;

  @override
  ConsumerState<RecurringEditScreen> createState() => _RecurringEditScreenState();
}

class _RecurringEditScreenState extends ConsumerState<RecurringEditScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  RecurringCycle _cycle = RecurringCycle.monthly;
  String? _categoryId;
  String? _walletId;
  DateTime _start = DateTime.now();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _amountCtrl.text = groupThousands(r.amount);
      _noteCtrl.text = r.note;
      _type = r.type;
      _cycle = r.cycle;
      _categoryId = r.categoryId;
      _walletId = r.walletId;
      _start = r.startDate;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  CategoryType get _catType => _type == TransactionType.income
      ? CategoryType.income
      : CategoryType.expense;

  Future<void> _save() async {
    final amount = parseVndInput(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhập số tiền hợp lệ')));
      return;
    }
    final wallets = ref.read(walletsProvider).valueOrNull ?? [];
    final walletId = _walletId ?? (wallets.isNotEmpty ? wallets.first.id : null);
    if (walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa có ví nào')));
      return;
    }
    final repo = ref.read(repositoryProvider);
    if (_isEditing) {
      await repo.updateRecurring(widget.existing!.id,
          amount: amount, type: _type, categoryId: _categoryId, walletId: walletId,
          note: _noteCtrl.text.trim(), cycle: _cycle, startDate: _start);
    } else {
      await repo.addRecurring(
          amount: amount, type: _type, categoryId: _categoryId, walletId: walletId,
          note: _noteCtrl.text.trim(), cycle: _cycle, startDate: _start);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final cats = categories.where((c) => c.type == _catType).toList();
    _walletId ??= wallets.isNotEmpty ? wallets.first.id : null;

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Sửa định kỳ' : 'Thêm định kỳ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TransactionType>(
            key: const Key('recurringType'),
            segments: const [
              ButtonSegment(value: TransactionType.expense, label: Text('Chi')),
              ButtonSegment(value: TransactionType.income, label: Text('Thu')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('recurringAmount'),
            controller: _amountCtrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(hintText: '0', suffixText: '₫'),
          ),
          const SizedBox(height: 16),
          Text('Danh mục', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cats)
                ChoiceChip(
                  key: Key('rcat_${c.name}'),
                  avatar: Icon(categoryIcon(c.icon),
                      size: 16,
                      color: _categoryId == c.id
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Color(c.color)),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Chu kỳ', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<RecurringCycle>(
            key: const Key('cycleSegment'),
            segments: [
              for (final c in RecurringCycle.values)
                ButtonSegment(value: c, label: Text(cycleLabel(c))),
            ],
            selected: {_cycle},
            onSelectionChanged: (s) => setState(() => _cycle = s.first),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                  title: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('recurringWallet'),
                      value: _walletId,
                      isExpanded: true,
                      items: [
                        for (final w in wallets)
                          DropdownMenuItem(value: w.id, child: Text(w.name)),
                      ],
                      onChanged: (v) => setState(() => _walletId = v),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('recurringDate'),
                  leading: const Icon(Icons.event, size: 20),
                  title: const Text('Bắt đầu'),
                  trailing: Text(formatDmy(_start)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _start = picked);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('recurringSave'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(_isEditing ? 'Lưu thay đổi' : 'Lưu'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `app/`): `flutter test test/widget/recurring_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/features/recurring/recurring_edit_screen.dart test/widget/recurring_test.dart
git commit -m "feat(recurring): add/edit rule form (#8)"
```

---

### Task 8: UI — `RecurringScreen` (list/empty/delete) + Settings entry

**Files:**
- Create: `app/lib/features/recurring/recurring_screen.dart`
- Modify: `app/lib/features/settings/settings_screen.dart`
- Test: `app/test/widget/recurring_test.dart` (append tests inside existing `main()`)

- [ ] **Step 1: Write the failing test** — append inside `main()` in `app/test/widget/recurring_test.dart` (add these imports at the top: `import 'package:moneynote/core/money.dart';`, `import 'package:moneynote/data/repository.dart';`, `import 'package:moneynote/features/recurring/recurring_screen.dart';`, `import 'package:moneynote/features/settings/settings_screen.dart';`, `import 'package:shared_preferences/shared_preferences.dart';`):

```dart
  testWidgets('RecurringScreen shows empty state then a seeded rule', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: RecurringScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Chưa có giao dịch định kỳ'), findsOneWidget);

    final w = (await db.select(db.wallets).get()).first;
    await AppRepository(db).addRecurring(
        amount: 50000, type: TransactionType.expense, walletId: w.id,
        cycle: RecurringCycle.monthly, startDate: DateTime(2026, 6, 5));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('50.000 ₫'), findsOneWidget);
    expect(find.textContaining('Hàng tháng'), findsOneWidget);
    expect(find.textContaining('Kỳ tới'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Settings has a recurring entry that opens RecurringScreen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    bigView(tester);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const Key('recurringRules')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('recurringRules')));
    await tester.pumpAndSettle();

    expect(find.text('Giao dịch định kỳ'), findsWidgets); // AppBar title of RecurringScreen

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `app/`): `flutter test test/widget/recurring_test.dart`
Expected: FAIL — `RecurringScreen` undefined; Settings has no `recurringRules` key.

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/features/recurring/recurring_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/features/recurring/recurring_edit_screen.dart';
import 'package:moneynote/state/providers.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringsProvider).valueOrNull ?? [];
    final cats = {
      for (final c in ref.watch(categoriesProvider).valueOrNull ?? []) c.id: c.name
    };
    final mc = moneyColorsOf(context);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Giao dịch định kỳ')),
      floatingActionButton: FloatingActionButton(
        key: const Key('addRecurring'),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecurringEditScreen())),
        child: const Icon(Icons.add),
      ),
      body: rules.isEmpty
          ? const Center(child: Text('Chưa có giao dịch định kỳ'))
          : ListView(
              children: [
                for (final r in rules)
                  Dismissible(
                    key: Key('dismiss_${r.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: mc.expense,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async => await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            content: const Text('Xoá định kỳ này?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Huỷ')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Xoá')),
                            ],
                          ),
                        ) ??
                        false,
                    onDismissed: (_) =>
                        ref.read(repositoryProvider).softDeleteRecurring(r.id),
                    child: ListTile(
                      leading: Icon(Icons.repeat,
                          color: r.type == TransactionType.income
                              ? mc.income
                              : mc.expense),
                      title: Text(formatVnd(r.amount)),
                      subtitle: Text(
                          '${cats[r.categoryId] ?? 'Chưa phân loại'} · '
                          '${cycleLabel(r.cycle)} · '
                          'Kỳ tới: ${formatDmy(nextOccurrenceAfter(r.startDate, r.cycle, now))}'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RecurringEditScreen(existing: r))),
                    ),
                  ),
              ],
            ),
    );
  }
}
```

Note: `nextOccurrenceAfter` is in `domain/recurring.dart`; add `import 'package:moneynote/domain/recurring.dart';` to `recurring_screen.dart` (the line above shows it used; ensure the import is present alongside the others).

In `app/lib/features/settings/settings_screen.dart`, add the import:
```dart
import 'package:moneynote/features/recurring/recurring_screen.dart';
```
and, inside the `ListView`'s `children`, immediately before the final `const SizedBox(height: 24),`, insert:
```dart
              const Divider(),
              const _SectionHeader('Tự động'),
              ListTile(
                key: const Key('recurringRules'),
                leading: const Icon(Icons.repeat),
                title: const Text('Giao dịch định kỳ'),
                subtitle: const Text('Quy tắc tự tạo giao dịch khi tới hạn'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RecurringScreen())),
              ),
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `app/`): `flutter test test/widget/recurring_test.dart`
Expected: PASS (all 3 widget tests).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/features/recurring/recurring_screen.dart lib/features/settings/settings_screen.dart test/widget/recurring_test.dart
git commit -m "feat(recurring): rules list + Settings entry + delete (#8)"
```

---

### Task 9: Full-suite verification + wrap-up

**Files:** none (verification only)

- [ ] **Step 1: Run the whole suite + analyzer**

Run (from `app/`):
```bash
flutter analyze
flutter test
```
Expected: analyze 0 issues; all tests pass (prior suite + ~30 new recurring tests), no regressions. If `flutter test` hangs printing nothing, kill orphans (`taskkill //F //IM flutter_tester.exe`, `taskkill //F //IM dart.exe`) and re-run.

- [ ] **Step 2: Manual smoke check (optional)**

Run the app (`flutter run -d windows` or Pixel_6). Cài đặt → Tự động → **Giao dịch định kỳ** → **+** → tạo một rule (vd Chi 50.000, Hàng tháng, bắt đầu hôm qua). Reload app → confirm a transaction appears in the list and the rule's "Kỳ tới" advanced.

- [ ] **Step 3: Hand off to finishing-a-development-branch**

The integration (push + PR for #8) is handled by the `superpowers:finishing-a-development-branch` skill after all tasks pass. After merge: open the follow-up issue "Bill reminders (flutter_local_notifications)" (8b) and proceed to #9.

---

## Self-Review

**1. Spec coverage:**
- §2/§3 schema (Recurrings, RecurringCycle, schemaVersion 6, migration, index) → Task 1. ✓
- §4 daysInMonth/clampedDate → Task 2; mostRecentOccurrence/nextOccurrenceAfter + UTC DST-safe helpers → Task 3. ✓
- §5 materializeDueRecurrings (atomic, idempotent, latest-only, best-effort launch) → Task 5 (logic) + Task 6 (launch hook). ✓
- §6 repo CRUD + transfer-reject + lastRunAt-reset-on-anchor-change + wallet cascade + recurringsProvider → Task 4. ✓
- §7 Settings entry ("Tự động" section) + RecurringScreen (list/empty/FAB/Dismissible delete/Kỳ tới) + RecurringEditScreen (SegmentedButton cycle/type, core formatters only, no add-transaction imports) → Tasks 7–8. ✓
- §9 tests: domain edge cases (leap, clamp, weekly, start>today, strictly-increasing) → Tasks 2–3; integration (latest-only, occurredAt==occ, lastRunAt==occ, idempotent, multi-period, future, soft-deleted, cascade, transfer-reject, edit-reset) → Tasks 4–5; widget (Settings→screen, empty, add, list/Kỳ tới, delete) → Tasks 7–8. ✓
- §10 follow-up issue + #9 → Task 9 Step 3. ✓

**2. Placeholder scan:** No TBD/TODO; every code step shows full code; every run step has command + expected result. ✓

**3. Type consistency:** `RecurringCycle` (Task 1) reused in Tasks 2–8. `mostRecentOccurrence(DateTime,RecurringCycle,DateTime)→DateTime?` / `nextOccurrenceAfter(...)→DateTime` (Task 3) consumed identically in Tasks 5 & 8. `addRecurring`/`updateRecurring`/`softDeleteRecurring`/`materializeDueRecurrings`/`watchRecurrings` signatures (Task 4–5) match their calls in Tasks 6–8 and the tests. `Recurring`/`RecurringsCompanion` (Drift-generated, Task 1) used consistently. `cycleLabel` defined in `recurring_edit_screen.dart` (Task 7), imported by `recurring_screen.dart` (Task 8). `recurringsProvider` (Task 4) consumed in Task 8. `moneyColorsOf(context).income/.expense` and `formatVnd`/`formatDmy`/`groupThousands`/`parseVndInput`/`ThousandsInputFormatter`/`categoryIcon` are all confirmed-existing helpers. ✓

**Coverage cap noted:** the `main.dart` launch wiring (Task 6) uses `DateTime.now()` and has no automated test (documented seam); its logic is fully covered by Task 5's injected-`today` tests.
