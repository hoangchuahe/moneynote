# MoneyNote Phase 1 — Core Local App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fully-offline Flutter expense app where the user can add/list/delete transactions, manage wallets & categories, and see a basic monthly dashboard — no AI, no backend.

**Architecture:** Local-first Flutter app in 4 layers — Presentation (screens) → State (Riverpod) → Domain (pure calculation functions) → Data (Drift/SQLite + Repository). The Drift database is the single source of truth; UI reads reactive streams and derives totals through pure functions. Money is stored as integer đồng (no float). Schema carries sync fields (UUID, `updatedAt`, soft-delete `deletedAt`) and the `transfer` transaction type from day one, even though transfer UI lands in Phase 3.

**Tech Stack:** Flutter (Dart 3), flutter_riverpod 2, Drift (SQLite) + build_runner, uuid. Pure-Dart helpers for VND formatting and financial calculations (no `intl` needed in P1).

**Scope notes (conscious YAGNI):**
- Transactions: create / read / soft-delete. **Edit (update) deferred** — add+delete covers corrections; keeps the core tight.
- Wallets & Categories: create / read / soft-delete. Edit deferred.
- Transfer: schema + repository + calculations support it and are **unit-tested**, but the create-transfer **UI is Phase 3** (spec §12). P1 Add screen shows only Chi/Thu.
- Reports/charts, budgets, recurring, passcode, dark-mode toggle, AI: later phases. P1 ships light+dark `ThemeData` wired to system mode ("theming ready"), no in-app toggle yet.

**Reference spec:** `docs/superpowers/specs/2026-06-11-moneynote-design.md` (§3 architecture, §5 data model, §6 ≤3s entry goal, §12 roadmap).

---

## File Structure

```
moneynote/
└── app/                                   # Flutter project (created in Task 2)
    ├── pubspec.yaml
    ├── analysis_options.yaml
    ├── sqlite3.dll                         # host-test native lib (Task 4, gitignored)
    ├── lib/
    │   ├── main.dart                       # ProviderScope + MaterialApp + HomeShell + first-run seed gate
    │   ├── core/
    │   │   ├── money.dart                  # groupThousands, formatVnd, formatDmy  (pure)
    │   │   └── theme.dart                  # light + dark ThemeData
    │   ├── data/
    │   │   ├── database.dart               # Drift tables, enums, AppDatabase, openConnection()
    │   │   ├── database.g.dart             # generated (build_runner)
    │   │   ├── repository.dart             # AppRepository: streams + writes
    │   │   └── seed.dart                   # seedIfEmpty(): default wallet + categories
    │   ├── domain/
    │   │   └── calculations.dart           # MonthSummary, balanceOf(), summarize()  (pure)
    │   ├── state/
    │   │   └── providers.dart              # Riverpod providers
    │   └── features/
    │       ├── home/home_shell.dart        # BottomNavigationBar shell (4 tabs)
    │       ├── dashboard/dashboard_screen.dart
    │       ├── transactions/
    │       │   ├── add_transaction_screen.dart
    │       │   └── transactions_list_screen.dart
    │       ├── wallets/wallets_screen.dart
    │       └── categories/categories_screen.dart
    └── test/
        ├── drift_setup.dart                # loads sqlite3.dll on Windows for host tests
        ├── core/money_test.dart
        ├── data/database_test.dart
        ├── domain/calculations_test.dart
        ├── data/repository_test.dart
        ├── data/seed_test.dart
        └── widget/add_transaction_test.dart
```

---

## Task 1: Environment setup (Flutter SDK + emulator)

Flutter and Dart are **not on PATH** on this machine. The user already has Android Studio + SDK + a `Pixel_6` emulator (from prior React-Native/Expo work) — reuse those.

**Files:** none (environment only).

- [ ] **Step 1: Install the Flutter SDK (stable)**

Download the latest stable Flutter SDK for Windows from https://docs.flutter.dev/get-started/install/windows and extract to e.g. `C:\src\flutter` (path must have **no spaces**). Then add `C:\src\flutter\bin` to the user PATH. Open a fresh PowerShell so PATH reloads.

- [ ] **Step 2: Verify Flutter & accept Android licenses**

Run:
```powershell
flutter --version
flutter doctor
flutter doctor --android-licenses   # press y to accept all
```
Expected: `flutter --version` prints a 3.x Dart version; `flutter doctor` shows green checks for "Flutter" and "Android toolchain". (Xcode/iOS check will show as unavailable on Windows — expected, handled in Phase 4.)

- [ ] **Step 3: Confirm an emulator is available**

Run:
```powershell
flutter emulators
```
Expected: the list includes `Pixel_6` (or similar). If yes, this Phase can run on it. Do **not** launch it yet — that happens in Task 14.

- [ ] **Step 4: Record the resolved versions**

Run `flutter --version` and note the Flutter + Dart versions in the PR/commit body when you first commit Task 2, so the SDK constraint in `pubspec.yaml` matches reality.

---

## Task 2: Scaffold the Flutter project

**Files:**
- Create: `app/` (via `flutter create`)
- Modify: `app/pubspec.yaml`
- Create: `app/analysis_options.yaml`
- Create: `app/lib/` folder skeleton (empty dirs created as files land in later tasks)
- Modify: `.gitignore` (repo root)

- [ ] **Step 1: Create the project**

From `D:\Freelance\moneynote`:
```powershell
flutter create --org com.moneynote --project-name moneynote --platforms=android app
```
This generates `app/` with Android support (iOS folder is added later on a Mac in Phase 4; `--platforms=android` keeps the tree lean for now).

- [ ] **Step 2: Replace `app/pubspec.yaml` dependencies**

Edit `app/pubspec.yaml` so the `environment`, `dependencies`, and `dev_dependencies` sections read exactly:

```yaml
name: moneynote
description: "MoneyNote — local-first expense tracker."
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  drift_dev: ^2.21.0
  build_runner: ^2.4.13
  sqlite3: ^2.4.0

flutter:
  uses-material-design: true
```

- [ ] **Step 3: Install packages**

Run:
```powershell
flutter pub get
```
Expected: "Got dependencies!" with no version-solve errors. If `drift`/`drift_dev` versions conflict with the installed Dart, run `flutter pub upgrade --major-versions drift drift_dev` and keep them on the same minor.

- [ ] **Step 4: Set `app/analysis_options.yaml`**

Replace its contents with:
```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"

linter:
  rules:
    prefer_const_constructors: true
```

- [ ] **Step 5: Add generated/native artifacts to `.gitignore`**

Append to the repo-root `D:\Freelance\moneynote\.gitignore` (create the file if missing):
```gitignore
# Flutter
app/.dart_tool/
app/build/
app/.flutter-plugins
app/.flutter-plugins-dependencies
# Drift generated code is committed? No — regenerate via build_runner:
app/lib/**/*.g.dart
# Host-test native sqlite (downloaded per machine)
app/sqlite3.dll
```

- [ ] **Step 6: Smoke-test the default app compiles**

Run:
```powershell
cd app ; flutter analyze
```
Expected: "No issues found!" (the default counter app plus our lint config).

- [ ] **Step 7: Commit**

```powershell
cd D:\Freelance\moneynote
git add .gitignore app
git commit -m "chore: scaffold Flutter app (android), deps, lints"
```

---

## Task 3: Money & date formatting helpers (pure, strict TDD)

Pure Dart, no Drift — perfect for test-first. VND has no sub-unit, so amounts are integer đồng grouped with `.`.

**Files:**
- Create: `app/lib/core/money.dart`
- Test: `app/test/core/money_test.dart`

- [ ] **Step 1: Write the failing test**

`app/test/core/money_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/money.dart';

void main() {
  group('groupThousands', () {
    test('groups with dots', () {
      expect(groupThousands(0), '0');
      expect(groupThousands(50000), '50.000');
      expect(groupThousands(1500000), '1.500.000');
      expect(groupThousands(-2000), '-2.000');
    });
  });

  group('formatVnd', () {
    test('appends đồng symbol', () {
      expect(formatVnd(50000), '50.000 ₫');
    });
  });

  group('formatDmy', () {
    test('zero-pads day and month', () {
      expect(formatDmy(DateTime(2026, 6, 1)), '01/06/2026');
      expect(formatDmy(DateTime(2026, 11, 23)), '23/11/2026');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/money_test.dart`
Expected: FAIL — `money.dart` / `groupThousands` not found.

- [ ] **Step 3: Write minimal implementation**

`app/lib/core/money.dart`:
```dart
/// Groups an integer with '.' every 3 digits (Vietnamese style).
String groupThousands(int n) {
  final neg = n < 0;
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return (neg ? '-' : '') + buf.toString();
}

/// Formats integer đồng as VND, e.g. 50000 -> "50.000 ₫".
String formatVnd(int dong) => '${groupThousands(dong)} ₫';

/// Formats a date as dd/MM/yyyy.
String formatDmy(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/money_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```powershell
git add app/lib/core/money.dart app/test/core/money_test.dart
git commit -m "feat: VND + date formatting helpers"
```

---

## Task 4: Drift database schema + host-test setup

Defines tables (with sync fields + transfer), enums, the `AppDatabase`, and the connection. Drift needs `build_runner` to generate `database.g.dart`, so generation is part of this task. Also wires up `sqlite3.dll` so DB tests run on the Windows host.

**Files:**
- Create: `app/lib/data/database.dart`
- Create (generated): `app/lib/data/database.g.dart`
- Create: `app/test/drift_setup.dart`
- Create: `app/sqlite3.dll` (downloaded)
- Test: `app/test/data/database_test.dart`

- [ ] **Step 1: Write `database.dart` (tables + enums + db class)**

`app/lib/data/database.dart`:
```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

enum TransactionType { income, expense, transfer }

enum CategoryType { income, expense }

enum WalletType { cash, bank, ewallet }

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get type => intEnum<WalletType>()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('VND'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF9E9E9E))();
  IntColumn get type => intEnum<CategoryType>()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  IntColumn get amount => integer()(); // đồng VND, always > 0
  IntColumn get type => intEnum<TransactionType>()();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get toWalletId =>
      text().nullable().references(Wallets, #id)(); // transfer destination
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Wallets, Categories, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// App (device) connection — file in the documents dir.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'moneynote.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
```

- [ ] **Step 2: Generate Drift code**

Run:
```powershell
cd app ; dart run build_runner build --delete-conflicting-outputs
```
Expected: creates `lib/data/database.g.dart`; "Succeeded". Re-run this command after any change to `database.dart`.

- [ ] **Step 3: Provide `sqlite3.dll` for host tests + the loader override**

Download the official SQLite Windows DLL once into `app/`:
```powershell
cd app
Invoke-WebRequest "https://www.sqlite.org/2024/sqlite-dll-win-x64-3460100.zip" -OutFile sqlite.zip
Expand-Archive sqlite.zip -DestinationPath sqlite_tmp -Force
Copy-Item sqlite_tmp\sqlite3.dll .\sqlite3.dll
Remove-Item sqlite.zip ; Remove-Item -Recurse sqlite_tmp
```
(If that exact URL 404s, grab the current "Precompiled Binaries for Windows → 64-bit DLL" from https://www.sqlite.org/download.html and copy its `sqlite3.dll` into `app/`.)

Create `app/test/drift_setup.dart`:
```dart
import 'dart:ffi';
import 'dart:io';
import 'package:sqlite3/open.dart';

/// Call once at the top of any test that opens a Drift NativeDatabase.
/// On Windows the Dart VM has no bundled sqlite3, so point it at the DLL
/// copied into the project root (see plan Task 4).
void setupSqliteForTests() {
  if (Platform.isWindows) {
    open.overrideFor(
      OperatingSystem.windows,
      () => DynamicLibrary.open('sqlite3.dll'),
    );
  }
}
```

- [ ] **Step 4: Write the failing test**

`app/test/data/database_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('can insert and read a wallet', () async {
    final now = DateTime(2026, 6, 11);
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'w1',
          name: 'Tiền mặt',
          type: WalletType.cash,
          createdAt: now,
          updatedAt: now,
        ));

    final wallets = await db.select(db.wallets).get();
    expect(wallets, hasLength(1));
    expect(wallets.single.name, 'Tiền mặt');
    expect(wallets.single.type, WalletType.cash);
    expect(wallets.single.currencyCode, 'VND');
  });
}
```

- [ ] **Step 5: Run test to verify it fails, then passes**

Run: `flutter test test/data/database_test.dart`
Expected: it should PASS once `database.g.dart` exists (Step 2). If it FAILS with a sqlite load error, re-check Step 3 (DLL present in `app/`). This task's "red" is really the compile/generation gate — confirm the test goes green before moving on.

- [ ] **Step 6: Commit**

```powershell
cd D:\Freelance\moneynote
git add app/lib/data/database.dart app/test/drift_setup.dart app/test/data/database_test.dart
git commit -m "feat: Drift schema (wallets, categories, transactions) with sync fields + transfer"
```

---

## Task 5: Pure financial calculations (strict TDD)

Pure functions over the generated `Wallet`/`Transaction` data classes — the heart of correctness. Critically: **transfers move money between wallets but must NOT count as income or expense** in the monthly summary.

**Files:**
- Create: `app/lib/domain/calculations.dart`
- Test: `app/test/domain/calculations_test.dart`

- [ ] **Step 1: Write the failing test**

`app/test/domain/calculations_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';

Wallet wallet(String id, {int initial = 0}) => Wallet(
      id: id,
      name: id,
      type: WalletType.cash,
      initialBalance: initial,
      currencyCode: 'VND',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Transaction txn({
  required int amount,
  required TransactionType type,
  required String walletId,
  String? toWalletId,
  DateTime? occurredAt,
}) =>
    Transaction(
      id: '$walletId-$amount-${type.name}-${occurredAt ?? ''}',
      amount: amount,
      type: type,
      categoryId: null,
      walletId: walletId,
      toWalletId: toWalletId,
      note: '',
      occurredAt: occurredAt ?? DateTime(2026, 6, 10),
      createdAt: DateTime(2026, 6, 10),
      updatedAt: DateTime(2026, 6, 10),
    );

void main() {
  group('balanceOf', () {
    test('initial balance + income - expense', () {
      final w = wallet('w1', initial: 100000);
      final txns = [
        txn(amount: 50000, type: TransactionType.income, walletId: 'w1'),
        txn(amount: 20000, type: TransactionType.expense, walletId: 'w1'),
      ];
      expect(balanceOf(w, txns), 130000);
    });

    test('transfer leaves source and enters destination', () {
      final w1 = wallet('w1', initial: 100000);
      final w2 = wallet('w2', initial: 0);
      final txns = [
        txn(
            amount: 30000,
            type: TransactionType.transfer,
            walletId: 'w1',
            toWalletId: 'w2'),
      ];
      expect(balanceOf(w1, txns), 70000);
      expect(balanceOf(w2, txns), 30000);
    });

    test('ignores transactions of other wallets', () {
      final w1 = wallet('w1', initial: 0);
      final txns = [
        txn(amount: 50000, type: TransactionType.income, walletId: 'w2'),
      ];
      expect(balanceOf(w1, txns), 0);
    });
  });

  group('summarize', () {
    test('sums income and expense, EXCLUDES transfers', () {
      final month = DateTime(2026, 6, 1);
      final txns = [
        txn(
            amount: 5000000,
            type: TransactionType.income,
            walletId: 'w1',
            occurredAt: DateTime(2026, 6, 5)),
        txn(
            amount: 200000,
            type: TransactionType.expense,
            walletId: 'w1',
            occurredAt: DateTime(2026, 6, 6)),
        txn(
            amount: 1000000,
            type: TransactionType.transfer,
            walletId: 'w1',
            toWalletId: 'w2',
            occurredAt: DateTime(2026, 6, 7)),
      ];
      final s = summarize(txns, month);
      expect(s.income, 5000000);
      expect(s.expense, 200000);
      expect(s.net, 4800000);
    });

    test('only counts the given month', () {
      final month = DateTime(2026, 6, 1);
      final txns = [
        txn(
            amount: 100000,
            type: TransactionType.expense,
            walletId: 'w1',
            occurredAt: DateTime(2026, 5, 31)),
        txn(
            amount: 200000,
            type: TransactionType.expense,
            walletId: 'w1',
            occurredAt: DateTime(2026, 7, 1)),
        txn(
            amount: 300000,
            type: TransactionType.expense,
            walletId: 'w1',
            occurredAt: DateTime(2026, 6, 15)),
      ];
      expect(summarize(txns, month).expense, 300000);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/calculations_test.dart`
Expected: FAIL — `calculations.dart` / `balanceOf` not found.

- [ ] **Step 3: Write minimal implementation**

`app/lib/domain/calculations.dart`:
```dart
import 'package:moneynote/data/database.dart';

class MonthSummary {
  final int income;
  final int expense;
  const MonthSummary({required this.income, required this.expense});
  int get net => income - expense;
}

/// Current balance of [wallet] given all (non-deleted) [txns].
int balanceOf(Wallet wallet, List<Transaction> txns) {
  var bal = wallet.initialBalance;
  for (final t in txns) {
    switch (t.type) {
      case TransactionType.income:
        if (t.walletId == wallet.id) bal += t.amount;
      case TransactionType.expense:
        if (t.walletId == wallet.id) bal -= t.amount;
      case TransactionType.transfer:
        if (t.walletId == wallet.id) bal -= t.amount;
        if (t.toWalletId == wallet.id) bal += t.amount;
    }
  }
  return bal;
}

/// Income/expense totals for the calendar month containing [month].
/// Transfers are intentionally excluded — they are not income or expense.
MonthSummary summarize(List<Transaction> txns, DateTime month) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  var income = 0;
  var expense = 0;
  for (final t in txns) {
    if (t.occurredAt.isBefore(start) || !t.occurredAt.isBefore(end)) continue;
    if (t.type == TransactionType.income) income += t.amount;
    if (t.type == TransactionType.expense) expense += t.amount;
  }
  return MonthSummary(income: income, expense: expense);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/calculations_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```powershell
git add app/lib/domain/calculations.dart app/test/domain/calculations_test.dart
git commit -m "feat: balanceOf + summarize (transfers excluded from income/expense)"
```

---

## Task 6: Repository (streams + writes, TDD)

The only door the upper layers use. Generates UUIDs + timestamps on write; all read streams exclude soft-deleted rows.

**Files:**
- Create: `app/lib/data/repository.dart`
- Test: `app/test/data/repository_test.dart`

- [ ] **Step 1: Write the failing test**

`app/test/data/repository_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  late AppDatabase db;
  late AppRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AppRepository(db);
  });
  tearDown(() => db.close());

  test('addWallet then watchWallets emits it', () async {
    await repo.addWallet(name: 'Tiền mặt', type: WalletType.cash);
    final wallets = await repo.watchWallets().first;
    expect(wallets, hasLength(1));
    expect(wallets.single.name, 'Tiền mặt');
    expect(wallets.single.id, isNotEmpty);
  });

  test('addTransaction sets uuid + timestamps', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    final c = await repo.addCategory(name: 'Ăn uống', type: CategoryType.expense);
    final t = await repo.addTransaction(
      amount: 50000,
      type: TransactionType.expense,
      categoryId: c.id,
      walletId: w.id,
      note: 'phở',
    );
    expect(t.id, isNotEmpty);
    expect(t.amount, 50000);
    expect(t.createdAt, isNotNull);
    expect(t.updatedAt, isNotNull);
  });

  test('soft-deleted transactions disappear from the stream', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    final t = await repo.addTransaction(
      amount: 1000,
      type: TransactionType.expense,
      walletId: w.id,
    );
    expect(await repo.watchAllTransactions().first, hasLength(1));
    await repo.softDeleteTransaction(t.id);
    expect(await repo.watchAllTransactions().first, isEmpty);
  });

  test('addTransaction rejects non-positive amount', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    expect(
      () => repo.addTransaction(
          amount: 0, type: TransactionType.expense, walletId: w.id),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repository_test.dart`
Expected: FAIL — `repository.dart` / `AppRepository` not found.

- [ ] **Step 3: Write minimal implementation**

`app/lib/data/repository.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:moneynote/data/database.dart';

const _uuid = Uuid();

class AppRepository {
  final AppDatabase db;
  AppRepository(this.db);

  // ---- reads (reactive, exclude soft-deleted) ----

  Stream<List<Wallet>> watchWallets() => (db.select(db.wallets)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  Stream<List<Category>> watchCategories() => (db.select(db.categories)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  Stream<List<Transaction>> watchAllTransactions() =>
      (db.select(db.transactions)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.occurredAt),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .watch();

  // ---- writes ----

  Future<Wallet> addWallet({
    required String name,
    required WalletType type,
    int initialBalance = 0,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: id,
          name: name,
          type: type,
          initialBalance: Value(initialBalance),
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.wallets)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<Category> addCategory({
    required String name,
    required CategoryType type,
    int color = 0xFF9E9E9E,
    String icon = 'category',
    bool isDefault = false,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: id,
          name: name,
          type: type,
          color: Value(color),
          icon: Value(icon),
          isDefault: Value(isDefault),
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.categories)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<Transaction> addTransaction({
    required int amount,
    required TransactionType type,
    String? categoryId,
    required String walletId,
    String? toWalletId,
    String note = '',
    DateTime? occurredAt,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'phải > 0 (đồng VND)');
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          amount: amount,
          type: type,
          categoryId: Value(categoryId),
          walletId: walletId,
          toWalletId: Value(toWalletId),
          note: Value(note),
          occurredAt: occurredAt ?? now,
          createdAt: now,
          updatedAt: now,
        ));
    return (db.select(db.transactions)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> softDeleteTransaction(String id) async {
    final now = DateTime.now();
    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> softDeleteWallet(String id) async {
    final now = DateTime.now();
    await (db.update(db.wallets)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now))
          as Insertable<Wallet>,
    );
  }
}
```

> ⚠️ Implementation note for the engineer: the `softDeleteWallet` cast above is wrong — write it with `WalletsCompanion(deletedAt: Value(now), updatedAt: Value(now))` (Step 3 only needs the transaction version to pass the test; add the wallet/category soft-delete using the correct companion when Task 13 needs it). Use `WalletsCompanion` / `CategoriesCompanion` for those tables. Delete the bad `softDeleteWallet` stub now and re-add it correctly in Task 13.

- [ ] **Step 4: Remove the bad stub, run tests**

Delete the `softDeleteWallet` method for now (it's added correctly in Task 13). Run: `flutter test test/data/repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```powershell
git add app/lib/data/repository.dart app/test/data/repository_test.dart
git commit -m "feat: AppRepository (watch streams + addWallet/Category/Transaction + soft-delete)"
```

---

## Task 7: First-run seed (TDD)

On an empty database, create one cash wallet "Tiền mặt" and the default Vietnamese categories. Idempotent.

**Files:**
- Create: `app/lib/data/seed.dart`
- Test: `app/test/data/seed_test.dart`

- [ ] **Step 1: Write the failing test**

`app/test/data/seed_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/seed.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('seeds one wallet and the default categories on empty db', () async {
    await seedIfEmpty(db);
    final wallets = await db.select(db.wallets).get();
    final cats = await db.select(db.categories).get();
    expect(wallets, hasLength(1));
    expect(wallets.single.name, 'Tiền mặt');
    expect(cats.length, greaterThanOrEqualTo(8));
    expect(cats.where((c) => c.type == CategoryType.income), isNotEmpty);
    expect(cats.where((c) => c.type == CategoryType.expense), isNotEmpty);
  });

  test('is idempotent (no duplicates on second run)', () async {
    await seedIfEmpty(db);
    final firstCount = (await db.select(db.wallets).get()).length;
    await seedIfEmpty(db);
    expect((await db.select(db.wallets).get()).length, firstCount);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/seed_test.dart`
Expected: FAIL — `seed.dart` / `seedIfEmpty` not found.

- [ ] **Step 3: Write minimal implementation**

`app/lib/data/seed.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:moneynote/data/database.dart';

const _uuid = Uuid();

class _CatSeed {
  final String name;
  final CategoryType type;
  final int color;
  final String icon;
  const _CatSeed(this.name, this.type, this.color, this.icon);
}

const _defaultCategories = <_CatSeed>[
  _CatSeed('Ăn uống', CategoryType.expense, 0xFFEF5350, 'restaurant'),
  _CatSeed('Đi lại', CategoryType.expense, 0xFF42A5F5, 'directions_bus'),
  _CatSeed('Hoá đơn', CategoryType.expense, 0xFFFFCA28, 'receipt_long'),
  _CatSeed('Mua sắm', CategoryType.expense, 0xFFAB47BC, 'shopping_bag'),
  _CatSeed('Giải trí', CategoryType.expense, 0xFF26C6DA, 'sports_esports'),
  _CatSeed('Sức khoẻ', CategoryType.expense, 0xFF66BB6A, 'health_and_safety'),
  _CatSeed('Giáo dục', CategoryType.expense, 0xFF8D6E63, 'school'),
  _CatSeed('Khác (chi)', CategoryType.expense, 0xFF9E9E9E, 'category'),
  _CatSeed('Lương', CategoryType.income, 0xFF66BB6A, 'payments'),
  _CatSeed('Thưởng', CategoryType.income, 0xFFFFA726, 'card_giftcard'),
  _CatSeed('Khác (thu)', CategoryType.income, 0xFF9E9E9E, 'category'),
];

/// Creates the starter wallet + default categories if the db has no wallets.
Future<void> seedIfEmpty(AppDatabase db) async {
  final existing = await db.select(db.wallets).get();
  if (existing.isNotEmpty) return;

  final now = DateTime.now();
  await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: _uuid.v4(),
        name: 'Tiền mặt',
        type: WalletType.cash,
        createdAt: now,
        updatedAt: now,
      ));

  for (final c in _defaultCategories) {
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: _uuid.v4(),
          name: c.name,
          type: c.type,
          color: Value(c.color),
          icon: Value(c.icon),
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/seed_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```powershell
git add app/lib/data/seed.dart app/test/data/seed_test.dart
git commit -m "feat: first-run seed (Tiền mặt wallet + default VN categories)"
```

---

## Task 8: Riverpod providers

Wire the database, repository, and reactive streams. No new behaviour — just composition — so verified by `flutter analyze` rather than a dedicated test.

**Files:**
- Create: `app/lib/state/providers.dart`

- [ ] **Step 1: Write the providers**

`app/lib/state/providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openConnection());
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<AppRepository>(
  (ref) => AppRepository(ref.watch(databaseProvider)),
);

final walletsProvider = StreamProvider<List<Wallet>>(
  (ref) => ref.watch(repositoryProvider).watchWallets(),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(repositoryProvider).watchCategories(),
);

final transactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(repositoryProvider).watchAllTransactions(),
);

/// The month shown on the dashboard (first of month). Defaults to current month.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `cd app ; flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```powershell
git add app/lib/state/providers.dart
git commit -m "feat: Riverpod providers (db, repo, wallets/categories/transactions streams)"
```

---

## Task 9: Theme (light + dark, system mode)

**Files:**
- Create: `app/lib/core/theme.dart`

- [ ] **Step 1: Write the themes**

`app/lib/core/theme.dart`:
```dart
import 'package:flutter/material.dart';

const _seed = Color(0xFF2E7D32); // money green

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      useMaterial3: true,
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
```

- [ ] **Step 2: Verify**

Run: `cd app ; flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```powershell
git add app/lib/core/theme.dart
git commit -m "feat: light + dark themes (system mode ready)"
```

---

## Task 10: Add Transaction screen (≤3s entry) + widget test

The signature UX. Defaults minimise taps: type = Chi (expense), wallet = first, date = today, amount field autofocused. Minimal flow = type amount → tap a category → Save.

**Files:**
- Create: `app/lib/features/transactions/add_transaction_screen.dart`
- Test: `app/test/widget/add_transaction_test.dart`

- [ ] **Step 1: Write the screen**

`app/lib/features/transactions/add_transaction_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/state/providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _walletId;
  DateTime _date = DateTime.now();

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
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập số tiền hợp lệ')),
      );
      return;
    }
    final wallets = ref.read(walletsProvider).valueOrNull ?? [];
    final walletId = _walletId ?? (wallets.isNotEmpty ? wallets.first.id : null);
    if (walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ví nào')),
      );
      return;
    }
    await ref.read(repositoryProvider).addTransaction(
          amount: amount,
          type: _type,
          categoryId: _categoryId,
          walletId: walletId,
          note: _noteCtrl.text.trim(),
          occurredAt: _date,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final cats = categories.where((c) => c.type == _catType).toList();
    _walletId ??= wallets.isNotEmpty ? wallets.first.id : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm giao dịch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                  value: TransactionType.expense, label: Text('Chi')),
              ButtonSegment(value: TransactionType.income, label: Text('Thu')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null; // reset since category list changes
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('amountField'),
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Số tiền (đồng)',
              suffixText: '₫',
            ),
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
                  key: Key('cat_${c.name}'),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('walletDropdown'),
            initialValue: _walletId,
            decoration: const InputDecoration(labelText: 'Ví'),
            items: [
              for (final w in wallets)
                DropdownMenuItem(value: w.id, child: Text(w.name)),
            ],
            onChanged: (v) => setState(() => _walletId = v),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ngày'),
            subtitle: Text(
                '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('saveButton'),
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write the widget test**

`app/test/widget/add_transaction_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/state/providers.dart';

import '../drift_setup.dart';

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('entering amount + category + save persists a transaction',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AddTransactionScreen()),
      ),
    );
    // let the wallet/category streams emit
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.byKey(const Key('amountField')), '50000');
    await tester.tap(find.byKey(const Key('cat_Ăn uống')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pump(const Duration(milliseconds: 200));

    final repo = AppRepository(db);
    final txns = await repo.watchAllTransactions().first;
    expect(txns, hasLength(1));
    expect(txns.single.amount, 50000);
    expect(txns.single.type, TransactionType.expense);
  });
}
```

- [ ] **Step 3: Run the widget test**

Run: `flutter test test/widget/add_transaction_test.dart`
Expected: PASS. If the category chip isn't found, increase the `pump` delay after `pumpWidget` (stream emission timing).

- [ ] **Step 4: Commit**

```powershell
git add app/lib/features/transactions/add_transaction_screen.dart app/test/widget/add_transaction_test.dart
git commit -m "feat: Add Transaction screen (<=3s entry) + widget test"
```

---

## Task 11: Dashboard screen

Month header (income / expense / net via `summarize`) + recent transactions list. Pure-derive from `transactionsProvider`.

**Files:**
- Create: `app/lib/features/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Write the screen**

`app/lib/features/dashboard/dashboard_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/state/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catName = {for (final c in categories) c.id: c.name};

    return txnsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (txns) {
        final s = summarize(txns, month);
        final recent = txns.take(15).toList();
        return ListView(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tháng ${month.month}/${month.year}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _row(context, 'Thu', s.income, Colors.green),
                    _row(context, 'Chi', s.expense, Colors.red),
                    const Divider(),
                    _row(context, 'Còn lại', s.net,
                        s.net >= 0 ? Colors.green : Colors.red),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Gần đây'),
            ),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Chưa có giao dịch nào')),
              ),
            for (final t in recent)
              ListTile(
                leading: Icon(t.type == TransactionType.income
                    ? Icons.south_west
                    : t.type == TransactionType.expense
                        ? Icons.north_east
                        : Icons.swap_horiz),
                title: Text(catName[t.categoryId] ??
                    (t.type == TransactionType.transfer ? 'Chuyển ví' : '—')),
                subtitle: Text(formatDmy(t.occurredAt) +
                    (t.note.isEmpty ? '' : ' · ${t.note}')),
                trailing: Text(
                  (t.type == TransactionType.expense ? '-' : '+') +
                      formatVnd(t.amount),
                  style: TextStyle(
                    color: t.type == TransactionType.expense
                        ? Colors.red
                        : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext c, String label, int amount, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(formatVnd(amount),
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
```

- [ ] **Step 2: Verify**

Run: `cd app ; flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```powershell
git add app/lib/features/dashboard/dashboard_screen.dart
git commit -m "feat: dashboard (month summary + recent transactions)"
```

---

## Task 12: Transactions list screen (with soft-delete)

Full list, swipe to delete (soft).

**Files:**
- Create: `app/lib/features/transactions/transactions_list_screen.dart`

- [ ] **Step 1: Write the screen**

`app/lib/features/transactions/transactions_list_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/state/providers.dart';

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catName = {for (final c in categories) c.id: c.name};

    return txnsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (txns) {
        if (txns.isEmpty) {
          return const Center(child: Text('Chưa có giao dịch nào'));
        }
        return ListView(
          children: [
            for (final t in txns)
              Dismissible(
                key: Key('txn_${t.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) =>
                    ref.read(repositoryProvider).softDeleteTransaction(t.id),
                child: ListTile(
                  title: Text(catName[t.categoryId] ??
                      (t.type == TransactionType.transfer
                          ? 'Chuyển ví'
                          : '—')),
                  subtitle: Text(formatDmy(t.occurredAt) +
                      (t.note.isEmpty ? '' : ' · ${t.note}')),
                  trailing: Text(
                    (t.type == TransactionType.expense ? '-' : '+') +
                        formatVnd(t.amount),
                    style: TextStyle(
                      color: t.type == TransactionType.expense
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `cd app ; flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```powershell
git add app/lib/features/transactions/transactions_list_screen.dart
git commit -m "feat: transactions list with swipe-to-delete (soft)"
```

---

## Task 13: Wallets & Categories screens (+ correct soft-delete)

List + add (dialog) + soft-delete for both. Also re-adds the correct `softDeleteWallet` / `softDeleteCategory` removed in Task 6.

**Files:**
- Modify: `app/lib/data/repository.dart` (add correct soft-delete methods)
- Create: `app/lib/features/wallets/wallets_screen.dart`
- Create: `app/lib/features/categories/categories_screen.dart`
- Test: `app/test/data/repository_test.dart` (extend)

- [ ] **Step 1: Write failing tests for wallet/category soft-delete**

Append to `app/test/data/repository_test.dart` (inside `main`):
```dart
  test('soft-deleted wallet disappears from stream', () async {
    final w = await repo.addWallet(name: 'W', type: WalletType.cash);
    expect(await repo.watchWallets().first, hasLength(1));
    await repo.softDeleteWallet(w.id);
    expect(await repo.watchWallets().first, isEmpty);
  });

  test('soft-deleted category disappears from stream', () async {
    final c =
        await repo.addCategory(name: 'X', type: CategoryType.expense);
    expect(await repo.watchCategories().first, hasLength(1));
    await repo.softDeleteCategory(c.id);
    expect(await repo.watchCategories().first, isEmpty);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/repository_test.dart`
Expected: FAIL — `softDeleteWallet` / `softDeleteCategory` not defined.

- [ ] **Step 3: Add the correct methods to `repository.dart`**

Add inside `AppRepository` (uses the right companions):
```dart
  Future<void> softDeleteWallet(String id) async {
    final now = DateTime.now();
    await (db.update(db.wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> softDeleteCategory(String id) async {
    final now = DateTime.now();
    await (db.update(db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/repository_test.dart`
Expected: PASS (6 tests total).

- [ ] **Step 5: Write the Wallets screen**

`app/lib/features/wallets/wallets_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/calculations.dart';
import 'package:moneynote/state/providers.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final txns = ref.watch(transactionsProvider).valueOrNull ?? [];

    return Scaffold(
      body: ListView(
        children: [
          for (final w in wallets)
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: Text(w.name),
              subtitle: Text(_typeLabel(w.type)),
              trailing: Text(formatVnd(balanceOf(w, txns)),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onLongPress: () =>
                  ref.read(repositoryProvider).softDeleteWallet(w.id),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addWalletDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _typeLabel(WalletType t) => switch (t) {
        WalletType.cash => 'Tiền mặt',
        WalletType.bank => 'Ngân hàng',
        WalletType.ewallet => 'Ví điện tử',
      };

  Future<void> _addWalletDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    var type = WalletType.cash;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Thêm ví'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên ví')),
              TextField(
                controller: balCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Số dư ban đầu'),
              ),
              DropdownButton<WalletType>(
                value: type,
                isExpanded: true,
                items: [
                  for (final t in WalletType.values)
                    DropdownMenuItem(value: t, child: Text(_typeLabel(t))),
                ],
                onChanged: (v) => setState(() => type = v ?? WalletType.cash),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                ref.read(repositoryProvider).addWallet(
                      name: name,
                      type: type,
                      initialBalance: int.tryParse(balCtrl.text.trim()) ?? 0,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Write the Categories screen**

`app/lib/features/categories/categories_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/state/providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];
    final expense = cats.where((c) => c.type == CategoryType.expense).toList();
    final income = cats.where((c) => c.type == CategoryType.income).toList();

    return Scaffold(
      body: ListView(
        children: [
          _header(context, 'Chi'),
          for (final c in expense) _tile(ref, c),
          _header(context, 'Thu'),
          for (final c in income) _tile(ref, c),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _header(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t, style: Theme.of(c).textTheme.titleSmall),
      );

  Widget _tile(WidgetRef ref, Category c) => ListTile(
        leading: CircleAvatar(backgroundColor: Color(c.color), radius: 12),
        title: Text(c.name),
        onLongPress: () =>
            ref.read(repositoryProvider).softDeleteCategory(c.id),
      );

  Future<void> _addCategoryDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var type = CategoryType.expense;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Thêm danh mục'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên danh mục')),
              DropdownButton<CategoryType>(
                value: type,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: CategoryType.expense, child: Text('Chi')),
                  DropdownMenuItem(
                      value: CategoryType.income, child: Text('Thu')),
                ],
                onChanged: (v) =>
                    setState(() => type = v ?? CategoryType.expense),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                ref
                    .read(repositoryProvider)
                    .addCategory(name: name, type: type);
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Verify & commit**

Run: `cd app ; flutter analyze`
Expected: "No issues found!"
```powershell
git add app/lib/data/repository.dart app/lib/features/wallets app/lib/features/categories app/test/data/repository_test.dart
git commit -m "feat: wallets + categories screens, correct soft-delete methods"
```

---

## Task 14: App shell + first-run seed + run on emulator

Tie it together: bottom-nav shell, gate the UI on a one-time seed, run end-to-end on `Pixel_6`.

**Files:**
- Create: `app/lib/features/home/home_shell.dart`
- Modify: `app/lib/main.dart`

- [ ] **Step 1: Write the home shell**

`app/lib/features/home/home_shell.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/features/categories/categories_screen.dart';
import 'package:moneynote/features/dashboard/dashboard_screen.dart';
import 'package:moneynote/features/transactions/add_transaction_screen.dart';
import 'package:moneynote/features/transactions/transactions_list_screen.dart';
import 'package:moneynote/features/wallets/wallets_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _titles = ['Tổng quan', 'Giao dịch', 'Ví', 'Danh mục'];
  static const _pages = [
    DashboardScreen(),
    TransactionsListScreen(),
    WalletsScreen(),
    CategoriesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: _pages[_index],
      floatingActionButton: _index <= 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.list), label: 'Giao dịch'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'Ví'),
          NavigationDestination(
              icon: Icon(Icons.category), label: 'Danh mục'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write `main.dart` (seed gate + theme)**

Replace `app/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/home/home_shell.dart';
import 'package:moneynote/state/providers.dart';

final _seedProvider = FutureProvider<void>((ref) async {
  await seedIfEmpty(ref.watch(databaseProvider));
});

void main() {
  runApp(const ProviderScope(child: MoneyNoteApp()));
}

class MoneyNoteApp extends StatelessWidget {
  const MoneyNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyNote',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(_seedProvider);
    return seed.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi khởi tạo: $e'))),
      data: (_) => const HomeShell(),
    );
  }
}
```

- [ ] **Step 3: Analyze the whole app**

Run: `cd app ; flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Run the full test suite**

Run: `cd app ; flutter test`
Expected: all tests PASS (money 3, database 1, calculations 5, repository 6, seed 2, widget 1).

- [ ] **Step 5: Launch on the emulator and smoke-test by hand**

```powershell
flutter emulators --launch Pixel_6
flutter devices            # confirm the emulator shows up
cd app ; flutter run
```
Manually verify:
1. App opens to "Tổng quan" with seeded "Tiền mặt" wallet and default categories.
2. Tap **Thêm** → enter `50000` → tap **Ăn uống** → **Lưu**. Returns to dashboard; "Chi" shows `50.000 ₫`, recent list shows the entry.
3. **Ví** tab → balance reflects `-50.000 ₫` against initial 0 → add a new wallet.
4. **Danh mục** tab → add/long-press-delete a category.
5. **Giao dịch** tab → swipe the entry left to delete; dashboard updates.
6. Kill and relaunch the app → data persists (offline, on-device).

- [ ] **Step 6: Commit**

```powershell
cd D:\Freelance\moneynote
git add app/lib/features/home/home_shell.dart app/lib/main.dart
git commit -m "feat: app shell + first-run seed gate; Phase 1 core complete"
```

---

## Self-Review (completed)

**Spec coverage (§ of `2026-06-11-moneynote-design.md`):**
- §3 local-first, DB source of truth, offline → Tasks 4–8, 14 (no network anywhere). ✓
- §5 data model with UUID/updatedAt/soft-delete + transfer + int đồng → Task 4. ✓
- §5 seed (Tiền mặt + default categories) → Task 7. ✓
- §6 ≤3s entry goal → Task 10 (defaults minimise taps). ✓
- §3 report excludes transfers → Task 5 `summarize` + test. ✓
- P1 roadmap: CRUD txn/category/wallet + basic dashboard + theming ready → Tasks 10–14. ✓
- Transfer schema/calc in P1, transfer UI deferred to P3 → honored (Tasks 4–5 cover it; no transfer UI). ✓

**Placeholder scan:** No "TBD/TODO". The one deliberate wrong-code stub (`softDeleteWallet` in Task 6) is explicitly flagged with a fix instruction and corrected in Task 13 — called out so it isn't mistaken for a real implementation.

**Type consistency:** Method names consistent across tasks — `watchWallets/watchCategories/watchAllTransactions`, `addWallet/addCategory/addTransaction`, `softDeleteTransaction/softDeleteWallet/softDeleteCategory`, `balanceOf`, `summarize`, `MonthSummary{income,expense,net}`, providers `databaseProvider/repositoryProvider/walletsProvider/categoriesProvider/transactionsProvider/selectedMonthProvider`. Drift companions (`WalletsCompanion/CategoriesCompanion/TransactionsCompanion`) used per their tables.

**Known risk flagged for executor:** Windows host Drift tests depend on `sqlite3.dll` (Task 4 Step 3). If a test fails to load sqlite, that's the cause — not a logic bug.
