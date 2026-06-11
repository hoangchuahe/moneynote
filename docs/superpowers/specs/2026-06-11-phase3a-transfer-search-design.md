# MoneyNote Phase 3a — Transfer UI + Search/Filter — Design Spec

> First sub-piece of Phase 3. Adds the create-transfer flow (the P1-deferred transfer UI) and search/filter on the transactions list.
> Ngày: 2026-06-11 · Trạng thái: Approved qua brainstorming, chờ user review.
> Phase 3 (budgets, reports/charts, recurring/bill, transfer UI, search) được **decompose thành 4 sub-piece**; đây là **3a** (Transfer UI + Search). Các sub-piece khác (3b budgets, 3c reports, 3d recurring) có spec riêng khi tới lượt.

## 1. Mục tiêu & phạm vi

**Mục tiêu:** Cho phép tạo giao dịch **chuyển tiền giữa ví** (UI; schema + tính toán đã có từ P1) và **tìm/lọc** danh sách giao dịch.

**Trong phạm vi 3a:** transfer create-flow trên màn Add · search theo ghi chú · filter theo danh mục + khoảng ngày · validation transfer.

**Ngoài phạm vi:** budgets (3b), reports/charts (3c), recurring/reminders (3d), lọc theo ví. Không đụng data layer của transfer (đã xong P1) ngoài một validation nhỏ.

**Nguyên tắc giữ nguyên:** tiền int đồng; **transfer KHÔNG tính vào thu/chi** (đã có ở `summarize`); offline; tầng UI → providers → repository/domain (UI không query DB trực tiếp).

## 2. Quyết định đã chốt

| Hạng mục | Quyết định |
|---|---|
| Vị trí transfer | Segment thứ 3 **"Chuyển"** trên SegmentedButton màn Add (Chi/Thu/Chuyển) |
| Transfer mode UI | Ẩn smart input + danh mục; hiện **"Từ ví" + "Đến ví"** thay ô Ví đơn |
| Search/filter scope | **text (ghi chú) + danh mục (nhiều) + khoảng ngày**; KHÔNG lọc ví |
| Cơ chế lọc | Hàm **thuần** `filterTransactions` áp in-memory lên `transactionsProvider` — không query Drift mới |
| Transfer validation | Thêm vào `addTransaction`: type=transfer ⇒ `toWalletId` != null và != `walletId` |

## 3. Transfer UI (mở rộng `AddTransactionScreen`)

- SegmentedButton: thêm `ButtonSegment(value: TransactionType.transfer, label: Text('Chuyển'))`.
- State thêm: `String? _toWalletId`. Trong transfer mode, `_walletId` đóng vai "Từ ví".
- Khi `_type == transfer`:
  - **Ẩn**: smart-input row, danh mục chips (transfer không có category).
  - **Hiện**: hai dropdown "Từ ví" (`_walletId`) + "Đến ví" (`_toWalletId`).
  - Khi `_type == income/expense`: giữ nguyên hành vi hiện tại (danh mục + 1 ví + smart input).
- `_save()` cho transfer: validate số tiền > 0 + `_walletId != _toWalletId` (cả hai đã chọn) → `addTransaction(amount, type: transfer, categoryId: null, walletId: _walletId, toWalletId: _toWalletId, note, occurredAt: _date)`.
- Learn-on-correction/merchant **chỉ áp dụng income/expense** — bỏ qua khi transfer.
- List + dashboard đã render transfer ("Chuyển ví", icon swap) từ P1 — không đổi.

## 4. Repository — transfer validation (TDD)

Thêm vào `addTransaction` (giữ check `amount <= 0`):
```
if (type == transfer):
    if toWalletId == null || toWalletId == walletId:
        throw ArgumentError('transfer cần toWalletId khác walletId')
```

## 5. Search/Filter (`TransactionsListScreen`)

- **`domain/transaction_filter.dart`** (thuần, dễ test):
  - `class TxnFilter { String text; Set<String> categoryIds; DateTime? from; DateTime? to; bool get isActive; }`
  - `List<Transaction> filterTransactions(List<Transaction> txns, TxnFilter f)`:
    - text: `note.toLowerCase().contains(f.text.toLowerCase())` (rỗng = bỏ qua)
    - categoryIds: nếu không rỗng → `categoryId` phải thuộc set (transfer/null bị loại — đúng ý)
    - from/to: `occurredAt` trong `[from, to]` (bao gồm 2 đầu; from = đầu ngày, to = cuối ngày)
- **`state/providers.dart`**: `txnFilterProvider = StateProvider<TxnFilter>((_) => const TxnFilter())`.
- **`TransactionsListScreen`**: 
  - Thanh search (TextField) trên đầu → cập nhật `txnFilterProvider.text`.
  - Nút filter (icon) → bottom sheet: chips danh mục (multi-select) + chọn khoảng ngày (Tháng này / Tuỳ chọn từ–đến qua showDateRangePicker).
  - List = `filterTransactions(ref.watch(transactionsProvider).value, ref.watch(txnFilterProvider))`.
  - Filter đang bật hiện thành chip xoá nhanh; empty state khi không có kết quả ("Không có giao dịch khớp").

## 6. Files

| File | Thay đổi |
|---|---|
| `lib/domain/transaction_filter.dart` | **Tạo** — TxnFilter + filterTransactions |
| `lib/state/providers.dart` | **Sửa** — thêm `txnFilterProvider` |
| `lib/data/repository.dart` | **Sửa** — transfer validation trong addTransaction |
| `lib/features/transactions/add_transaction_screen.dart` | **Sửa** — segment Chuyển + từ/đến ví |
| `lib/features/transactions/transactions_list_screen.dart` | **Sửa** — search + filter sheet + apply |

## 7. Testing

- **Unit:** `filterTransactions` (text match; category subset; date range; kết hợp; rỗng = trả hết). `addTransaction` reject transfer thiếu/trùng `toWalletId`; chấp nhận transfer hợp lệ.
- **Widget:** màn Add chế độ Chuyển (chọn Chuyển → từ ví A → đến ví B → số tiền → lưu → 1 transaction type=transfer persisted, balance 2 ví đổi đúng); search lọc list (gõ text → chỉ còn giao dịch khớp).
- Full suite vẫn xanh (transfer/summarize/balanceOf cũ không hồi quy).

## 8. Roadmap Phase 3 còn lại

3b Budgets · 3c Reports & charts · 3d Recurring & bill reminders — mỗi cái spec→plan→build riêng khi tới lượt.
