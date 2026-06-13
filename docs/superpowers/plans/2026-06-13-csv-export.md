# CSV Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a free "Xuất CSV" action in Settings that writes the user's transactions to a UTF-8-BOM CSV file (4 quick presets) and shows the saved path.

**Architecture:** Pure domain (`domain/csv_export.dart`: range computation, filtering, CSV string building, filename) + an injectable `CsvExporter` service (`data/csv_export_service.dart`) that writes bytes to disk. UI in `settings_screen.dart` reads the existing transaction/category/wallet providers, builds the CSV in-memory, and delegates the write to the provider-overridable exporter. No new dependencies.

**Tech Stack:** Dart 3, Flutter, Riverpod 2, Drift (only for the existing read providers), `path`/`path_provider` (already present).

**Spec:** `docs/superpowers/specs/2026-06-13-csv-export-design.md`

**Conventions (from CLAUDE.md):** run all `flutter` commands from `app/`. Money is `int` đồng VND, no minus sign. TDD: write the failing test, watch it fail, minimal impl, watch it pass, `flutter analyze` clean, commit test+impl together. If `flutter test` hangs printing nothing, kill orphans: `taskkill //F //IM flutter_tester.exe` then `taskkill //F //IM dart.exe`.

---

### Task 1: Domain — export scope range + filter

**Files:**
- Create: `app/lib/domain/csv_export.dart`
- Test: `app/test/domain/csv_export_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/domain/csv_export_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/csv_export.dart';

Transaction tx({
  required int amount,
  required TransactionType type,
  String? categoryId,
  String walletId = 'w1',
  String? toWalletId,
  String note = '',
  required DateTime when,
}) =>
    Transaction(
      id: '$amount-$when-${type.name}',
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      toWalletId: toWalletId,
      note: note,
      occurredAt: when,
      createdAt: when,
      updatedAt: when,
    );

void main() {
  group('exportRange', () {
    final anchor = DateTime(2026, 6, 13);

    test('thisMonth = [first of month, first of next month)', () {
      final r = exportRange(ExportScope.thisMonth, anchor);
      expect(r.start, DateTime(2026, 6, 1));
      expect(r.end, DateTime(2026, 7, 1));
    });

    test('last3Months spans 3 months ending this month', () {
      final r = exportRange(ExportScope.last3Months, anchor);
      expect(r.start, DateTime(2026, 4, 1));
      expect(r.end, DateTime(2026, 7, 1));
    });

    test('last3Months crosses the year boundary', () {
      final r = exportRange(ExportScope.last3Months, DateTime(2026, 1, 15));
      expect(r.start, DateTime(2025, 11, 1));
      expect(r.end, DateTime(2026, 2, 1));
    });

    test('thisYear = whole calendar year', () {
      final r = exportRange(ExportScope.thisYear, anchor);
      expect(r.start, DateTime(2026, 1, 1));
      expect(r.end, DateTime(2027, 1, 1));
    });

    test('all = unbounded', () {
      final r = exportRange(ExportScope.all, anchor);
      expect(r.start, isNull);
      expect(r.end, isNull);
    });
  });

  group('filterByRange', () {
    final txns = [
      tx(amount: 1, type: TransactionType.expense, when: DateTime(2026, 5, 31)),
      tx(amount: 2, type: TransactionType.expense, when: DateTime(2026, 6, 1)),
      tx(amount: 3, type: TransactionType.expense, when: DateTime(2026, 6, 30)),
      tx(amount: 4, type: TransactionType.expense, when: DateTime(2026, 7, 1)),
    ];

    test('start inclusive, end exclusive', () {
      final r = filterByRange(txns, DateTime(2026, 6, 1), DateTime(2026, 7, 1));
      expect(r.map((t) => t.amount).toList(), [2, 3]);
    });

    test('null bounds do not constrain', () {
      expect(filterByRange(txns, null, null).length, 4);
      expect(filterByRange(txns, null, DateTime(2026, 6, 1)).map((t) => t.amount).toList(), [1]);
      expect(filterByRange(txns, DateTime(2026, 7, 1), null).map((t) => t.amount).toList(), [4]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

From `app/`: `flutter test test/domain/csv_export_test.dart`
Expected: compile error / FAIL — `csv_export.dart` and `ExportScope`/`exportRange`/`filterByRange` do not exist.

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/domain/csv_export.dart`:

```dart
import 'package:moneynote/data/database.dart';

enum ExportScope { thisMonth, last3Months, thisYear, all }

/// Half-open range [start, end): start INCLUDED, end EXCLUDED.
/// null bound = unbounded on that side (used by [ExportScope.all]).
/// [anchor] is passed in (no DateTime.now() inside) so it is test-deterministic.
({DateTime? start, DateTime? end}) exportRange(ExportScope scope, DateTime anchor) {
  final y = anchor.year, m = anchor.month;
  switch (scope) {
    case ExportScope.thisMonth:
      return (start: DateTime(y, m, 1), end: DateTime(y, m + 1, 1));
    case ExportScope.last3Months:
      return (start: DateTime(y, m - 2, 1), end: DateTime(y, m + 1, 1));
    case ExportScope.thisYear:
      return (start: DateTime(y, 1, 1), end: DateTime(y + 1, 1, 1));
    case ExportScope.all:
      return (start: null, end: null);
  }
}

/// Returns transactions whose occurredAt is within [start, end).
/// A null bound does not constrain that side.
List<Transaction> filterByRange(
    List<Transaction> txns, DateTime? start, DateTime? end) {
  return txns.where((t) {
    if (start != null && t.occurredAt.isBefore(start)) return false;
    if (end != null && !t.occurredAt.isBefore(end)) return false;
    return true;
  }).toList();
}
```

- [ ] **Step 4: Run test to verify it passes**

From `app/`: `flutter test test/domain/csv_export_test.dart`
Expected: PASS (all `exportRange` + `filterByRange` tests green).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/domain/csv_export.dart test/domain/csv_export_test.dart
git commit -m "feat(export): date-range scope + filter (#6)"
```
Expected: analyze 0 issues; commit succeeds.

---

### Task 2: Domain — build CSV + filename

**Files:**
- Modify: `app/lib/domain/csv_export.dart` (append)
- Test: `app/test/domain/csv_export_test.dart` (append two groups inside the existing `main()`)

- [ ] **Step 1: Write the failing test**

Append these two groups inside `main()` in `app/test/domain/csv_export_test.dart` (after the `filterByRange` group, before the closing `}` of `main`):

```dart
  group('buildTransactionsCsv', () {
    const cats = {'food': 'Ăn uống', 'salary': 'Lương'};
    const wallets = {'w1': 'Tiền mặt', 'w2': 'Vietcombank'};

    test('header row is the fixed column order, CRLF-terminated', () {
      final csv = buildTransactionsCsv([], categoryNames: cats, walletNames: wallets);
      expect(csv, 'Ngày,Loại,Số tiền,Danh mục,Ví,Ví đích,Ghi chú\r\n');
    });

    test('expense row: ISO date (no time), label, raw amount, names', () {
      final csv = buildTransactionsCsv([
        tx(amount: 50000, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', note: 'Phở', when: DateTime(2026, 6, 10, 9, 30)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('2026-06-10,Chi,50000,Ăn uống,Tiền mặt,,Phở\r\n'));
    });

    test('income label', () {
      final csv = buildTransactionsCsv([
        tx(amount: 9000000, type: TransactionType.income, categoryId: 'salary', walletId: 'w2', when: DateTime(2026, 6, 1)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('2026-06-01,Thu,9000000,Lương,Vietcombank,,\r\n'));
    });

    test('transfer: blank category, dest wallet filled', () {
      final csv = buildTransactionsCsv([
        tx(amount: 200000, type: TransactionType.transfer, categoryId: null, walletId: 'w1', toWalletId: 'w2', when: DateTime(2026, 6, 5)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('2026-06-05,Chuyển khoản,200000,,Tiền mặt,Vietcombank,\r\n'));
    });

    test('null/unknown category -> Chưa phân loại; unknown wallet -> (không rõ)', () {
      final csv = buildTransactionsCsv([
        tx(amount: 1000, type: TransactionType.expense, categoryId: null, walletId: 'wX', when: DateTime(2026, 6, 2)),
        tx(amount: 2000, type: TransactionType.expense, categoryId: 'gone', walletId: 'w1', when: DateTime(2026, 6, 3)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('2026-06-02,Chi,1000,Chưa phân loại,(không rõ),,\r\n'));
      expect(csv, contains('2026-06-03,Chi,2000,Chưa phân loại,Tiền mặt,,\r\n'));
    });

    test('RFC4180 quoting for note with comma, quote, newline', () {
      final csv = buildTransactionsCsv([
        tx(amount: 1, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', note: 'cà phê, bánh', when: DateTime(2026, 6, 4)),
        tx(amount: 2, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', note: 'nói "ngon"', when: DateTime(2026, 6, 5)),
        tx(amount: 3, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', note: 'dòng1\ndòng2', when: DateTime(2026, 6, 6)),
      ], categoryNames: cats, walletNames: wallets);
      expect(csv, contains('"cà phê, bánh"'));
      expect(csv, contains('"nói ""ngon"""'));
      expect(csv, contains('"dòng1\ndòng2"'));
    });

    test('rows preserve input order; header is line 0', () {
      final csv = buildTransactionsCsv([
        tx(amount: 111, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', when: DateTime(2026, 6, 7)),
        tx(amount: 222, type: TransactionType.expense, categoryId: 'food', walletId: 'w1', when: DateTime(2026, 6, 8)),
      ], categoryNames: cats, walletNames: wallets);
      final lines = csv.split('\r\n');
      expect(lines[0], 'Ngày,Loại,Số tiền,Danh mục,Ví,Ví đích,Ghi chú');
      expect(lines[1], startsWith('2026-06-07,Chi,111'));
      expect(lines[2], startsWith('2026-06-08,Chi,222'));
    });
  });

  group('exportFilename', () {
    test('slug + yyyyMMdd stamp', () {
      expect(exportFilename(ExportScope.all, DateTime(2026, 6, 13)), 'moneynote-all-20260613.csv');
      expect(exportFilename(ExportScope.thisMonth, DateTime(2026, 12, 9)), 'moneynote-thismonth-20261209.csv');
      expect(exportFilename(ExportScope.last3Months, DateTime(2026, 1, 1)), 'moneynote-3months-20260101.csv');
      expect(exportFilename(ExportScope.thisYear, DateTime(2026, 6, 13)), 'moneynote-thisyear-20260613.csv');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

From `app/`: `flutter test test/domain/csv_export_test.dart`
Expected: FAIL — `buildTransactionsCsv` and `exportFilename` are not defined.

- [ ] **Step 3: Write minimal implementation**

Append to `app/lib/domain/csv_export.dart`:

```dart
const _headers = ['Ngày', 'Loại', 'Số tiền', 'Danh mục', 'Ví', 'Ví đích', 'Ghi chú'];

String _typeLabel(TransactionType t) => switch (t) {
      TransactionType.income => 'Thu',
      TransactionType.expense => 'Chi',
      TransactionType.transfer => 'Chuyển khoản',
    };

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// RFC4180: wrap in "..." if the field contains a comma, double-quote, or
/// line break; double any inner double-quotes.
String _csvField(String s) =>
    (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r'))
        ? '"${s.replaceAll('"', '""')}"'
        : s;

/// Builds the CSV text (header + one line per transaction, CRLF-terminated).
/// [txns] must already be filtered + sorted by the caller.
/// [categoryNames]/[walletNames] map id -> display name (from the providers,
/// soft-deleted rows already excluded). A missing category id (null or a
/// soft-deleted category) renders "Chưa phân loại"; a missing wallet id
/// renders "(không rõ)". Transfers have no category column value.
String buildTransactionsCsv(
  List<Transaction> txns, {
  required Map<String, String> categoryNames,
  required Map<String, String> walletNames,
}) {
  final buf = StringBuffer()
    ..write(_headers.map(_csvField).join(','))
    ..write('\r\n');
  for (final t in txns) {
    final isTransfer = t.type == TransactionType.transfer;
    final category =
        isTransfer ? '' : (categoryNames[t.categoryId] ?? 'Chưa phân loại');
    final row = [
      _isoDate(t.occurredAt),
      _typeLabel(t.type),
      t.amount.toString(),
      category,
      walletNames[t.walletId] ?? '(không rõ)',
      t.toWalletId == null ? '' : (walletNames[t.toWalletId] ?? '(không rõ)'),
      t.note,
    ];
    buf
      ..write(row.map(_csvField).join(','))
      ..write('\r\n');
  }
  return buf.toString();
}

/// File name: moneynote-<scope>-<yyyyMMdd>.csv. [now] is passed in for tests.
String exportFilename(ExportScope scope, DateTime now) {
  final slug = switch (scope) {
    ExportScope.thisMonth => 'thismonth',
    ExportScope.last3Months => '3months',
    ExportScope.thisYear => 'thisyear',
    ExportScope.all => 'all',
  };
  final stamp = '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  return 'moneynote-$slug-$stamp.csv';
}
```

- [ ] **Step 4: Run test to verify it passes**

From `app/`: `flutter test test/domain/csv_export_test.dart`
Expected: PASS (all groups green).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/domain/csv_export.dart test/domain/csv_export_test.dart
git commit -m "feat(export): build transactions CSV + filename (#6)"
```
Expected: analyze 0 issues; commit succeeds.

---

### Task 3: Data — CSV file writer with UTF-8 BOM + provider

**Files:**
- Create: `app/lib/data/csv_export_service.dart`
- Modify: `app/lib/state/providers.dart` (add `csvExporterProvider`)
- Test: `app/test/data/csv_export_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/data/csv_export_service_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/csv_export_service.dart';

void main() {
  group('csvBytesWithBom', () {
    test('prefixes UTF-8 BOM then the UTF-8 bytes', () {
      final bytes = csvBytesWithBom('Aá');
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(bytes.sublist(3), utf8.encode('Aá'));
    });

    test('empty string still carries the BOM', () {
      expect(csvBytesWithBom(''), [0xEF, 0xBB, 0xBF]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

From `app/`: `flutter test test/data/csv_export_service_test.dart`
Expected: FAIL — `csv_export_service.dart` / `csvBytesWithBom` do not exist.

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/data/csv_export_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// UTF-8 bytes prefixed with the BOM (EF BB BF) so Excel detects UTF-8 and
/// renders Vietnamese correctly.
List<int> csvBytesWithBom(String csv) => [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];

abstract class CsvExporter {
  /// Writes [csv] to a file named [filename]; returns the absolute path.
  Future<String> save(String filename, String csv);
}

class DiskCsvExporter implements CsvExporter {
  @override
  Future<String> save(String filename, String csv) async {
    final dir = await _targetDir();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(csvBytesWithBom(csv), flush: true);
    return file.path;
  }

  Future<Directory> _targetDir() async {
    final downloads = await getDownloadsDirectory(); // desktop/iOS; Android -> null
    if (downloads != null) return downloads;
    final ext = await getExternalStorageDirectory(); // Android app external dir
    if (ext != null) return ext;
    return getApplicationDocumentsDirectory();
  }
}
```

Then add the provider to `app/lib/state/providers.dart`. Add the import near the other `data/` imports:

```dart
import 'package:moneynote/data/csv_export_service.dart';
```

And add this provider (e.g. after `repositoryProvider`):

```dart
final csvExporterProvider = Provider<CsvExporter>((ref) => DiskCsvExporter());
```

- [ ] **Step 4: Run test to verify it passes**

From `app/`: `flutter test test/data/csv_export_service_test.dart`
Expected: PASS (both BOM tests green).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/data/csv_export_service.dart lib/state/providers.dart test/data/csv_export_service_test.dart
git commit -m "feat(export): CSV file writer with UTF-8 BOM (#6)"
```
Expected: analyze 0 issues; commit succeeds.

---

### Task 4: UI — Settings export action + preset sheet

**Files:**
- Modify: `app/lib/features/settings/settings_screen.dart`
- Test: `app/test/widget/csv_export_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/widget/csv_export_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/csv_export_service.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/data/repository.dart';
import 'package:moneynote/data/seed.dart';
import 'package:moneynote/features/settings/settings_screen.dart';
import 'package:moneynote/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../drift_setup.dart';

class FakeCsvExporter implements CsvExporter {
  int calls = 0;
  String? filename;
  String? csv;

  @override
  Future<String> save(String filename, String csv) async {
    calls++;
    this.filename = filename;
    this.csv = csv;
    return '/fake/$filename';
  }
}

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget app(AppDatabase db, FakeCsvExporter fake) => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        csvExporterProvider.overrideWithValue(fake),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );

void main() {
  setUpAll(setupSqliteForTests);

  testWidgets('export "Tất cả" saves a CSV and shows the saved path',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    final repo = AppRepository(db);
    final food = (await db.select(db.categories).get())
        .firstWhere((c) => c.name == 'Ăn uống');
    final w = (await db.select(db.wallets).get()).first;
    await repo.addTransaction(
      amount: 50000,
      type: TransactionType.expense,
      categoryId: food.id,
      walletId: w.id,
      note: 'Phở',
      occurredAt: DateTime(2026, 6, 10),
    );
    addTearDown(db.close);
    bigView(tester);

    final fake = FakeCsvExporter();
    await tester.pumpWidget(app(db, fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xuất CSV'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Tất cả'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(fake.calls, 1);
    expect(fake.filename, matches(RegExp(r'^moneynote-all-\d{8}\.csv$')));
    expect(fake.csv, contains('Ăn uống'));
    expect(fake.csv, contains('50000'));
    expect(fake.csv, contains('Phở'));
    expect(find.textContaining('Đã lưu:'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('export with no transactions shows the empty message',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db); // categories + wallets, but no transactions
    addTearDown(db.close);
    bigView(tester);

    final fake = FakeCsvExporter();
    await tester.pumpWidget(app(db, fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xuất CSV'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Tất cả'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(fake.calls, 0);
    expect(find.text('Không có giao dịch để xuất'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

From `app/`: `flutter test test/widget/csv_export_test.dart`
Expected: FAIL — there is no "Xuất CSV" tile yet (`find.text('Xuất CSV')` finds nothing).

- [ ] **Step 3: Write minimal implementation**

In `app/lib/features/settings/settings_screen.dart`:

(a) Add these imports after the existing imports at the top:

```dart
import 'package:flutter/services.dart';
import 'package:moneynote/domain/csv_export.dart';
```

(b) Inside the `ListView`'s `children`, immediately before the final `const SizedBox(height: 24),`, insert:

```dart
              const Divider(),
              const _SectionHeader('Dữ liệu'),
              ListTile(
                key: const Key('exportCsv'),
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Xuất CSV'),
                subtitle: const Text('Lưu giao dịch ra file .csv'),
                onTap: _openExportSheet,
              ),
```

(c) Add these two methods to `_SettingsScreenState` (e.g. just before `String _toneLabel(...)`):

```dart
  void _openExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Xuất CSV',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Chọn khoảng thời gian'),
            ),
            for (final (scope, label) in const [
              (ExportScope.thisMonth, 'Tháng này'),
              (ExportScope.last3Months, '3 tháng gần đây'),
              (ExportScope.thisYear, 'Năm nay'),
              (ExportScope.all, 'Tất cả'),
            ])
              ListTile(
                title: Text(label),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _exportCsv(scope);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(ExportScope scope) async {
    final now = DateTime.now();
    final txns = await ref.read(transactionsProvider.future);
    final cats = await ref.read(categoriesProvider.future);
    final wallets = await ref.read(walletsProvider.future);
    final r = exportRange(scope, now);
    final rows = filterByRange(txns, r.start, r.end)
      ..sort((a, b) {
        final c = a.occurredAt.compareTo(b.occurredAt);
        return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
      });
    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có giao dịch để xuất')));
      return;
    }
    final csv = buildTransactionsCsv(
      rows,
      categoryNames: {for (final c in cats) c.id: c.name},
      walletNames: {for (final w in wallets) w.id: w.name},
    );
    final path =
        await ref.read(csvExporterProvider).save(exportFilename(scope, now), csv);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã lưu: $path'),
      action: SnackBarAction(
        label: 'Sao chép',
        onPressed: () => Clipboard.setData(ClipboardData(text: path)),
      ),
    ));
  }
```

- [ ] **Step 4: Run test to verify it passes**

From `app/`: `flutter test test/widget/csv_export_test.dart`
Expected: PASS (both the populated-export and empty-message tests green).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze
git add lib/features/settings/settings_screen.dart test/widget/csv_export_test.dart
git commit -m "feat(export): Settings export action + presets (#6)"
```
Expected: analyze 0 issues; commit succeeds.

---

### Task 5: Full-suite verification + wrap-up

**Files:** none (verification only)

- [ ] **Step 1: Run the whole suite + analyzer**

From `app/`:
```bash
flutter analyze
flutter test
```
Expected: analyze 0 issues; all tests pass (the previous ~110 + the new domain/data/widget tests), no regressions. If `flutter test` hangs printing nothing, kill orphans (`taskkill //F //IM flutter_tester.exe`, `taskkill //F //IM dart.exe`) and re-run.

- [ ] **Step 2: Manual smoke check (optional but recommended)**

Run the app (`flutter run -d windows`, or the Pixel_6 emulator), open **Cài đặt → Dữ liệu → Xuất CSV**, pick a preset, confirm the SnackBar shows a path and the file opens in Excel/Sheets with Vietnamese intact (BOM working) and amounts as plain integers.

- [ ] **Step 3: Open PR**

```bash
git push -u origin feat/6-csv-export
gh pr create --base master --title "feat(export): CSV export from Settings (#6)" --body "Implements #6 — free CSV export (4 presets, UTF-8 BOM, save-to-disk + show path). Spec/plan in docs/superpowers/. Pure domain + injectable exporter; no new deps."
```
After merge: close #6 and open the follow-up issue "Nút Share CSV (share_plus)" noted in the spec.

---

## Self-Review

**1. Spec coverage:**
- §2 presets (Tháng này/3 tháng/Năm nay/Tất cả) → Task 1 `exportRange` + Task 4 sheet. ✓
- §2 save-file + show-path, no share_plus → Task 3 `DiskCsvExporter` + Task 4 SnackBar. ✓
- §2 raw positive amount + Loại column → Task 2 row builder + tests. ✓
- §2 UTF-8 BOM → Task 3 `csvBytesWithBom` + test. ✓
- §2 ISO date / CRLF / RFC4180 quoting → Task 2 `_isoDate` / `\r\n` / `_csvField` + tests. ✓
- §2 no new dependency → only `path`/`path_provider` (already present); no `pubspec.yaml` change. ✓
- §3 `exportRange`/`filterByRange`/`buildTransactionsCsv`/`exportFilename` → Tasks 1–2. ✓
- §4 `csvBytesWithBom`/`CsvExporter`/`DiskCsvExporter` + `csvExporterProvider` → Task 3. ✓
- §5 "Dữ liệu" section + preset sheet + sort asc + empty SnackBar + copy-path → Task 4. ✓
- §8 unit (range/filter/CSV/quoting/BOM/filename) + widget (fake exporter, populated + empty) → Tasks 1–4 tests. ✓
- §9 close #6 + follow-up share issue → Task 5 Step 3. ✓

**2. Placeholder scan:** No TBD/TODO; every code step shows full code, every run step shows command + expected result. ✓

**3. Type consistency:** `ExportScope` (Task 1) reused unchanged in Tasks 2 & 4. `exportRange` returns `({DateTime? start, DateTime? end})`, consumed as `r.start`/`r.end` in Task 4. `buildTransactionsCsv(List<Transaction>, {Map<String,String> categoryNames, Map<String,String> walletNames})` — same signature in Task 2 def, Task 2 tests, Task 4 call. `CsvExporter.save(String, String) -> Future<String>` — same in Task 3 def, `csvExporterProvider`, `FakeCsvExporter`, Task 4 call. `exportFilename(ExportScope, DateTime)` consistent. `seedIfEmpty`, `bigView`, `databaseProvider`/`csvExporterProvider` overrides match existing house patterns. ✓
