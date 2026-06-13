# MoneyNote — Export CSV (issue #6) — Design Spec

> Phase 3 (daily-use) sub-piece: **xuất giao dịch ra CSV** chia sẻ được, **không gate phí** (điểm thiện cảm vs đối thủ — master spec mục 12).
> Ngày: 2026-06-13 · Trạng thái: Approved qua brainstorming, chờ user review.
> Thứ tự còn lại do user chốt: **#6 export CSV (đây)** → #8 recurring/reminders → #9 passcode/biometric. (3a transfer+search ✅ · 3b budgets ✅ · 3c reports ✅.)

## 1. Mục tiêu & phạm vi

**Mục tiêu:** Người dùng xuất giao dịch ra **file CSV** mở được bằng Excel/Google Sheets để tự phân tích/lưu trữ, hoàn toàn miễn phí và offline.

**Trong phạm vi:**
- Lối vào: section **"Dữ liệu"** trong **Cài đặt** → item **"Xuất CSV"**.
- **4 preset phạm vi:** Tháng này · 3 tháng gần đây · Năm nay · Tất cả.
- Dựng CSV thuần (domain): tính khoảng thời gian, lọc, format dòng, quoting RFC4180.
- Ghi file **UTF-8 BOM** ra đĩa qua service inject được, **hiện đường dẫn** qua SnackBar (+ nút Sao chép).
- Empty state (không có giao dịch trong phạm vi).

**Ngoài phạm vi (follow-up, mở issue riêng):**
- **Nút Share thật** (share sheet qua `share_plus`) — user chốt v1 chỉ lưu-file + hiện path; share để follow-up.
- Khoảng thời gian tuỳ chọn (date-range picker) · chọn cột · xuất Excel/PDF · import CSV · lên lịch xuất tự động.

**Nguyên tắc giữ nguyên:** tiền là **int đồng VND, không dấu trừ**; transfer **không phải** thu cũng không phải chi (cột Loại riêng); "code computes" (CSV dựng thuần bằng code, không nhờ AI); offline 100%; `UI → providers → domain → data`; **không thêm dependency**.

## 2. Quyết định đã chốt (qua brainstorming)

| Hạng mục | Quyết định |
|---|---|
| Phạm vi xuất | **4 preset nhanh** (Tháng này / 3 tháng gần đây / Năm nay / Tất cả) — không date picker, không thêm UI state phức tạp |
| Giao file | **Lưu file ra đĩa + hiện đường dẫn** (SnackBar + Sao chép). **Không** thêm `share_plus` ở v1 |
| Số tiền | **Số nguyên dương thô** (`50000`, không nhóm nghìn) + **cột "Loại"** mang hướng (Thu/Chi/Chuyển khoản). Tôn trọng convention không dấu trừ; spreadsheet pivot/SUM theo nhóm dễ |
| Encoding | **UTF-8 có BOM** (`EF BB BF`) → Excel đọc đúng tiếng Việt |
| Ngày | **ISO `yyyy-MM-dd`** — sort & parse đúng trên spreadsheet, không lệ thuộc locale; bỏ phần giờ |
| Định dạng | Comma-separated, quoting **RFC4180**, kết dòng **CRLF** (`\r\n`) |
| Kiến trúc | **A**: logic CSV = hàm thuần `domain/`; ghi file = `CsvExporter` service inject được (provider override trong test). Không tự thêm package `csv` (quoting tự viết ~10 dòng) |
| Chỗ lưu | desktop → `getDownloadsDirectory()`; Android fallback `getExternalStorageDirectory()` → `getApplicationDocumentsDirectory()` |
| Tên file | `moneynote-<scope>-<yyyyMMdd>.csv` (vd `moneynote-all-20260613.csv`) |

## 3. Tầng domain — `lib/domain/csv_export.dart` (thuần, tạo mới)

```dart
import 'package:moneynote/data/database.dart';

enum ExportScope { thisMonth, last3Months, thisYear, all }

/// Khoảng [start, end): start GỒM, end LOẠI. null = không chặn phía đó (cho `all`).
/// [anchor] truyền vào (không gọi DateTime.now() bên trong) để test xác định.
({DateTime? start, DateTime? end}) exportRange(ExportScope scope, DateTime anchor) {
  final y = anchor.year, m = anchor.month;
  switch (scope) {
    case ExportScope.thisMonth:
      return (start: DateTime(y, m, 1), end: DateTime(y, m + 1, 1));
    case ExportScope.last3Months:
      return (start: DateTime(y, m - 2, 1), end: DateTime(y, m + 1, 1)); // tự chuẩn hoá biên năm
    case ExportScope.thisYear:
      return (start: DateTime(y, 1, 1), end: DateTime(y + 1, 1, 1));
    case ExportScope.all:
      return (start: null, end: null);
  }
}

/// Lọc theo [start, end). Bound null = không chặn phía đó.
List<Transaction> filterByRange(List<Transaction> txns, DateTime? start, DateTime? end) {
  return txns.where((t) {
    if (start != null && t.occurredAt.isBefore(start)) return false;   // start gồm
    if (end != null && !t.occurredAt.isBefore(end)) return false;      // end loại
    return true;
  }).toList();
}

const _headers = ['Ngày', 'Loại', 'Số tiền', 'Danh mục', 'Ví', 'Ví đích', 'Ghi chú'];

String _typeLabel(TransactionType t) => switch (t) {
      TransactionType.income => 'Thu',
      TransactionType.expense => 'Chi',
      TransactionType.transfer => 'Chuyển khoản',
    };

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// RFC4180: bọc "..." nếu field chứa , " \n hoặc \r; nhân đôi " bên trong.
String _csvField(String s) =>
    (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r'))
        ? '"${s.replaceAll('"', '""')}"'
        : s;

/// Dựng CSV (header + rows). [txns] đã được caller lọc + sắp xếp.
/// [categoryNames]/[walletNames]: id -> tên (lấy từ provider, đã loại soft-deleted).
String buildTransactionsCsv(
  List<Transaction> txns, {
  required Map<String, String> categoryNames,
  required Map<String, String> walletNames,
}) {
  final buf = StringBuffer()..write(_headers.map(_csvField).join(','))..write('\r\n');
  for (final t in txns) {
    final isTransfer = t.type == TransactionType.transfer;
    final category = isTransfer
        ? '' // transfer không có danh mục
        : (categoryNames[t.categoryId] ?? 'Chưa phân loại'); // null hoặc danh mục đã xoá
    final row = [
      _isoDate(t.occurredAt),
      _typeLabel(t.type),
      t.amount.toString(),                              // số nguyên dương thô
      category,
      walletNames[t.walletId] ?? '(không rõ)',
      t.toWalletId == null ? '' : (walletNames[t.toWalletId] ?? '(không rõ)'),
      t.note,
    ];
    buf..write(row.map(_csvField).join(','))..write('\r\n');
  }
  return buf.toString();
}

/// Tên file: moneynote-<scope>-<yyyyMMdd>.csv. [now] truyền vào để test xác định.
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

**Vì sao thuần:** khớp pattern `domain/reports.dart`, `domain/calculations.dart` — test bằng `List<Transaction>` không cần DB, không cần filesystem. `categoryNames`/`walletNames` truyền map vào (UI join từ `categoriesProvider`/`walletsProvider`) → builder không phụ thuộc Drift.

## 4. Tầng data — `lib/data/csv_export_service.dart` (tạo mới)

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// UTF-8 bytes có prefix BOM (EF BB BF) → Excel nhận diện UTF-8, đọc đúng tiếng Việt.
List<int> csvBytesWithBom(String csv) => [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];

abstract class CsvExporter {
  /// Ghi [csv] thành file [filename], trả đường dẫn tuyệt đối đã lưu.
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
    final ext = await getExternalStorageDirectory(); // Android: app external dir
    if (ext != null) return ext;
    return getApplicationDocumentsDirectory();
  }
}
```

- **BOM tách thành `csvBytesWithBom` thuần** để unit-test 3 byte đầu mà không chạm đĩa.
- **`CsvExporter` abstract** → widget test inject `FakeCsvExporter` (ghi nhận `filename`+`csv`, trả path giả) qua provider override; **không** đụng filesystem/platform channel thật.

`lib/state/providers.dart` (sửa): thêm
```dart
final csvExporterProvider = Provider<CsvExporter>((ref) => DiskCsvExporter());
```

## 5. UI — `lib/features/settings/settings_screen.dart` (sửa)

- Thêm `const Divider()` + `_SectionHeader('Dữ liệu')` + `ListTile`:
  - `leading: Icon(Icons.download)` (hoặc `file_download`), `title: Text('Xuất CSV')`, `subtitle`: gợi ý ngắn ("Lưu giao dịch ra file .csv").
  - `onTap` → `showModalBottomSheet` liệt kê 4 preset (`ExportScope`) với nhãn tiếng Việt: *Tháng này / 3 tháng gần đây / Năm nay / Tất cả*.
- **Controller xuất** (method trong State, hoặc hàm nhận `ref`):
  1. `final now = DateTime.now();`
  2. Đọc snapshot: `txns = ref.read(transactionsProvider).value ?? []`, `cats = ref.read(categoriesProvider).value ?? []`, `wallets = ref.read(walletsProvider).value ?? []`.
  3. `final r = exportRange(scope, now); var rows = filterByRange(txns, r.start, r.end);`
  4. **Sắp xếp tăng dần** theo `occurredAt` rồi `createdAt` (ledger cũ→mới; provider trả desc nên đảo lại).
  5. Nếu `rows.isEmpty` → `SnackBar('Không có giao dịch để xuất')`, **return** (không gọi exporter).
  6. `csv = buildTransactionsCsv(rows, categoryNames: {for (c in cats) c.id: c.name}, walletNames: {for (w in wallets) w.id: w.name});`
  7. `path = await ref.read(csvExporterProvider).save(exportFilename(scope, now), csv);`
  8. `SnackBar('Đã lưu: $path')` + `SnackBarAction('Sao chép', () => Clipboard.setData(ClipboardData(text: path)))`.
- Bọc `if (context.mounted)` quanh các thao tác UI sau `await` (theo pattern `saveBaseUrl` hiện có).

## 6. Data flow

```
Settings "Xuất CSV" → bottom sheet (4 preset)
   → exportRange(scope, now)  ─┐
   → filterByRange(txns,…)     │ domain thuần
   → sort asc                  │
   → buildTransactionsCsv(…)  ─┘  (join tên từ categories/wallets snapshot)
   → csvExporterProvider.save(filename, csv)   (data: ghi UTF-8+BOM)
   → SnackBar đường dẫn (+ Sao chép)
```
Reuse `transactionsProvider` + `categoriesProvider` + `walletsProvider` đã có — **không** thêm provider/repository đọc mới (chỉ thêm `csvExporterProvider`).

## 7. Files

| File | Thay đổi |
|---|---|
| `lib/domain/csv_export.dart` | **Tạo** — `ExportScope`, `exportRange`, `filterByRange`, `buildTransactionsCsv`, `exportFilename` |
| `lib/data/csv_export_service.dart` | **Tạo** — `csvBytesWithBom`, `CsvExporter`, `DiskCsvExporter` |
| `lib/state/providers.dart` | **Sửa** — thêm `csvExporterProvider` |
| `lib/features/settings/settings_screen.dart` | **Sửa** — section "Dữ liệu" + sheet preset + controller xuất + SnackBar |
| `test/domain/csv_export_test.dart` | **Tạo** — unit (thuần) |
| `test/widget/csv_export_test.dart` | **Tạo** — widget (FakeCsvExporter override) |

**`pubspec.yaml`: không đổi** — `path`, `path_provider` đã có; không thêm dependency.

## 8. Testing (TDD: RED → GREEN → commit gộp)

**Unit `test/domain/csv_export_test.dart` (không DB, không FS):**
- `exportRange` với anchor cố định `2026-06-13`: thisMonth → `[2026-06-01, 2026-07-01)`; last3Months → `[2026-04-01, 2026-07-01)`; thisYear → `[2026-01-01, 2027-01-01)`; all → `(null, null)`. **Biên năm:** anchor `2026-01-15`, last3Months → `[2025-11-01, 2026-02-01)`.
- `filterByRange`: occurredAt == start **giữ**; == end **loại**; bound null không chặn.
- `buildTransactionsCsv`: dòng header đúng thứ tự cột; nhãn Thu/Chi/Chuyển khoản; amount thô (`50000`); `categoryId` null → `Chưa phân loại`; transfer → cột Danh mục trống + Ví đích có tên; wallet thiếu trong map → `(không rõ)`; **quoting**: note `a,b` → `"a,b"`, note có `"` → nhân đôi, note có `\n` → bọc; kết dòng **CRLF**; thứ tự dòng đúng input.
- `csvBytesWithBom`: 3 byte đầu `0xEF,0xBB,0xBF`, phần còn lại == `utf8.encode(csv)`.
- `exportFilename`: slug từng scope + stamp `yyyyMMdd`.

**Widget `test/widget/csv_export_test.dart` (FakeCsvExporter):**
- Seed DB in-memory (vài txn thu/chi/transfer). Override `databaseProvider` + `csvExporterProvider` (fake ghi nhận `filename`+`csv`, trả `/fake/x.csv`).
- Settings hiện "Xuất CSV"; tap → sheet 4 preset; chọn "Tất cả" → fake `save` **được gọi đúng 1 lần**, `filename` khớp `moneynote-all-…csv`, `csv` chứa dòng đã seed; SnackBar hiện path trả về.
- **Empty:** DB rỗng (hoặc scope không có txn) → fake **không** bị gọi + SnackBar "Không có giao dịch để xuất".
- Đọc Drift stream trong `testWidgets` bọc `tester.runAsync`; set `tester.view.physicalSize` rộng + reset trong `addTearDown` (theo convention).
- `flutter analyze` 0 lỗi; full suite (110 + mới) không hồi quy.

## 9. Sau khi xong

Đóng issue #6. Mở **issue follow-up** "Nút Share CSV (share_plus)" cho phần chia sẻ trực tiếp (ngoài phạm vi v1). Tiếp theo theo thứ tự user chốt: **#8 recurring + bill reminders** → **#9 passcode/biometric**.
