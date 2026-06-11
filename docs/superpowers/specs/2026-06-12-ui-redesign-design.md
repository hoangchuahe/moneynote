# MoneyNote · UI Redesign Design Spec

> Làm mới giao diện toàn app theo hướng "fintech tinh gọn pha chất ấm", kèm hệ thống chủ đề chọn được (Tinh gọn / Sổ tay ấm).
> Ngày: 2026-06-12 · Trạng thái: đã duyệt design qua review từng phần với user (2 mockup vòng), chờ user review spec.

## 1. Mục tiêu & bối cảnh

App hiện dùng Material 3 mặc định: seed xanh lá, ListTile/Card nguyên bản, không icon danh mục, hardcode `Colors.red/green` rải rác. Chạy tốt nhưng nhìn "đồ án", chưa xứng vai trò portfolio và chưa tạo cảm giác "app xài mỗi ngày".

Mục tiêu: hiện đại theo chuẩn finance app 2026 (đọc nhanh, tin cậy, tối giản có cá tính), vẫn tối ưu cho daily-use. User đã chọn hướng **A pha chất ấm của B** trong 3 phương án đã trình (A fintech tinh gọn, B sổ tay ấm, C editorial tối), và yêu cầu thêm: **phong cách B phải là một lựa chọn đổi được trong Cài đặt**.

Nguyên tắc xuyên suốt:

- Nhìn 1 giây ra ngay "còn lại bao nhiêu". Số là nhân vật chính.
- Màu mang nghĩa, không trang trí: emerald = thu/tích cực, đỏ đất = chi, cam đất = lời nhắn AI, cảnh báo sớm và empty state.
- **Hạn chế dấu gạch**: số tiền chi KHÔNG có dấu trừ (màu + icon mang nghĩa), thu có thể mang dấu cộng kín đáo khi cần phân biệt, placeholder dùng chữ rõ ("Chưa phân loại") thay vì "—".
- Giữ Material 3 và mọi `Key` widget hiện có: 75 test không vỡ.

## 2. Hệ thống chủ đề (theme styles)

Hai phong cách, mỗi phong cách có đủ light + dark, đổi trong Cài đặt:

| Token | Tinh gọn light | Tinh gọn dark | Sổ tay ấm light | Sổ tay ấm dark |
|---|---|---|---|---|
| Background | #F6F7F5 | #111513 | #FAF3E7 | #181411 |
| Surface (card) | #FFFFFF | #1A201C | #FFFCF5 | #221C16 |
| Primary | #0B7A4F | #5BC894 | #D96C3B | #E0936A |
| Primary container | #DFF0E8 | #1F3B2E | #F6E3CB | #3D2A1E |
| On primary container | #064D32 | #BFE8D4 | #7A3A1B | #F0CDB5 |
| Warm accent (AI, cảnh báo sớm) | #D97A4A | #E0936A | #B98345 (đồng) | #C99A5B |
| Warm container | #F8E8DC | #3D2A1E | #F2E2C8 | #38301F |
| Expense (chi) | #C04848 | #E07A6E | #B3422F | #E08573 |
| Income (thu) | = primary | = primary | #4F6E3C | #9DBE7F |
| Transfer (chuyển) | #5E6963 | #9BA59E | #8A7A63 | #A89878 |
| Text chính | #15201A | #E7EDE9 | #42382B | #EFE6D8 |
| Text phụ | #5E6963 | #9BA59E | #7A6B52 | #B3A48C |
| Viền/divider | #E7EBE8 | #262D28 | #F0E6D4 | #322A20 |

Ghi chú: ở Sổ tay ấm, primary chính là màu ấm (terracotta), nên warm accent chuyển sang tông đồng để lời nhắn AI vẫn tách biệt khỏi nút chính. Income tách khỏi primary (xanh rêu) để thu/chi không cùng màu nút.

## 3. Typography & hình khối

- Font: **Be Vietnam Pro** (Regular 400, Medium 500, SemiBold 600), bundle .ttf vào `app/assets/fonts/`, khai báo trong pubspec. Không tải runtime, đúng local-first. Nếu thiếu glyph thì Flutter tự fallback hệ thống.
- Số tiền luôn bật tabular numerals (`FontFeature.tabularFigures()`): cột số thẳng hàng ở mọi danh sách.
- Thang chữ chính: hero 32 SemiBold, số trong dòng 14–15 Medium, tiêu đề dòng 15 Medium, phụ chú 13 Regular, nhãn nhỏ 11–12.
- Hình khối: card 16, chip/ô icon 10–12, dialog 20, bottom sheet 24 trên, FAB 15, thanh tiến độ 8px bo 4.
- Icon danh mục: ô 36px bo 12, nền là màu danh mục pha 14% alpha lên surface, icon dùng màu danh mục đậm. Danh mục đã có sẵn `icon` (chuỗi Material) và `color` trong DB từ Phase 1, UI hiện chưa dùng: giờ dùng thật.

## 4. Kiến trúc code

- `core/theme.dart` viết lại thành builder: `buildTheme(AppThemeStyle style, Brightness b)`. Token đặt trong các const class nội bộ, KHÔNG dùng `ColorScheme.fromSeed` nữa (tự chỉ định scheme để khớp bảng màu mục 2).
- `MoneyColors` là `ThemeExtension`: `income`, `expense`, `transfer`, `warn`, `warnContainer`, `onWarnContainer`. Mọi screen lấy màu tiền qua `Theme.of(context).extension<MoneyColors>()!`. Cấm `Colors.red/green/grey` trong `features/`.
- `core/category_visuals.dart`: `IconData categoryIcon(String name)` map chuỗi icon DB sang `Icons.*` (restaurant, directions_bus, receipt_long, shopping_bag, sports_esports, health_and_safety, school, payments, card_giftcard, category) với fallback `Icons.category`; helper `Color categoryTint(int color, ThemeData)` cho nền ô icon.
- `AppThemeStyle` enum (`classic` = Tinh gọn, `warm` = Sổ tay ấm) đặt ở `core/prefs.dart`, lưu key `theme_style`, mặc định `classic`. `MoneyNoteApp` watch prefs, build `theme`/`darkTheme` theo style; `themeMode` giữ cơ chế hiện có.
- Component theme đặt một chỗ trong builder: CardTheme, NavigationBarTheme (indicator pill primary container), InputDecorationTheme (filled, bo 14), ChipTheme, FAB theme, DialogTheme, ProgressIndicatorTheme, SnackBarTheme.

## 5. Từng màn hình

- **Tổng quan**: hero card gồm nhãn "Còn lại tháng này", số to căn giữa màu primary, hàng Thu | Chi chia đôi có vạch giữa; điều hướng tháng giữ key `prevMonth`/`nextMonth`. Card Ngân sách: mỗi dòng icon + tên + "đã chi / hạn mức", thanh 8px; đạt 80% chuyển warm, vượt 100% chuyển expense kèm nhãn "vượt". Gần đây: nhóm nhãn ngày ("Hôm nay", "Hôm qua", còn lại "12/6"), dòng = ô icon danh mục + tên + ghi chú, số bên phải màu theo loại, không dấu trừ; chuyển ví dùng icon hai mũi tên, ghi chú dạng "A sang B".
- **Thêm/Sửa giao dịch**: smart input dạng pill icon sparkles + nút Phân tích filled (giữ key `smartInput`, `parseButton`); **lời nhắn AI bỏ SnackBar**, thành card warm container dưới smart input, icon bóng thoại, comment rỗng thì không hiện, có nút x ẩn; amount field to căn giữa 30–32, gạch chân 2px primary (giữ key `amountField`, formatter nghìn giữ nguyên); chip danh mục có icon nhỏ (giữ key `cat_<tên>`); ví + ngày gộp một card hai dòng; nút Lưu filled full-width (giữ key `saveButton`); segmented Chi/Thu/Chuyển giữ nguyên hành vi, khi Sửa ẩn smart input như hiện tại.
- **Danh sách giao dịch**: search pill (giữ key `searchField`, `filterButton`), nhóm theo ngày như Tổng quan, swipe xoá nền expense + icon thùng rác, undo giữ.
- **Ngân sách**: tile như card Tổng quan, FAB giữ, dialog theo DialogTheme mới.
- **Ví**: icon theo loại (`Icons.payments` tiền mặt, `Icons.account_balance` ngân hàng, `Icons.smartphone` ví điện tử), số dư tabular căn phải, tên + loại như dòng chuẩn.
- **Danh mục**: ô icon màu thật của danh mục thay chấm tròn; tách nhóm Chi/Thu bằng section header.
- **Cài đặt**: các section trong card; mục Giao diện gồm 2 nhóm: "Chế độ" (Hệ thống/Sáng/Tối, giữ logic themeMode) và "Phong cách" (Tinh gọn/Sổ tay ấm, radio kèm chấm preview 2 màu của từng phong cách); section Máy chủ AI giữ key `baseUrlField`, `saveBaseUrl`.
- **Empty states**: icon to nhạt + 1 câu thân thiện + gợi ý hành động. Giao dịch: "Chưa có giao dịch nào. Bấm Thêm rồi gõ 'ăn phở 50k' là xong." Ngân sách: "Đặt hạn mức cho một danh mục để app nhắc khi sắp vượt." Ví/danh mục tương tự một câu.
- **Shell**: NavigationBar M3 indicator pill, FAB extended giữ nhãn theo tab như hiện tại.

## 6. Hành vi & edge case

- Số tiền: chi và chuyển không dấu, thu hiện "+" nhỏ trước số CHỈ ở danh sách lẫn lộn loại (Gần đây, Danh sách); màn chỉ có một loại thì không dấu.
- Icon string lạ (danh mục user tự tạo sau này): fallback `Icons.category`, tint theo màu danh mục.
- Lời nhắn AI: chỉ render khi `comment` khác rỗng; lỗi AI vẫn dùng SnackBar lỗi như cũ ("AI không khả dụng, nhập tay nhé").
- Dark mode: cả hai phong cách phải đạt contrast đọc được (text chính trên surface ≥ 4.5:1); số liệu bảng màu mục 2 đã chọn theo tiêu chí đó, kiểm tra lại bằng mắt khi implement.
- Đổi phong cách/chế độ áp dụng tức thì (watch prefsProvider, pattern sẵn có).

## 7. Out of scope (ghi nhận, không làm đợt này)

- App icon, splash screen, onboarding tour.
- Animation chuyển cảnh cầu kỳ, hero animation.
- Màn Reports (thuộc phase Reports riêng, sẽ kế thừa token).
- Haptic feedback tinh chỉnh.

## 8. Testing

- Giữ nguyên 75 test, không đổi `Key` nào.
- `category_visuals_test`: map đúng 10 chuỗi icon seed, fallback chuỗi lạ.
- `theme_test`: `buildTheme` trả đủ `MoneyColors` cho 4 tổ hợp (2 style × light/dark); style lưu/đọc từ prefs đúng.
- Widget test: lời nhắn AI hiện thành card (không SnackBar) khi comment khác rỗng, ẩn khi rỗng; settings đổi phong cách thì prefs ghi `theme_style` và MaterialApp đổi theme; dòng chi trong danh sách không render dấu trừ.
- Test nhóm theo ngày: header "Hôm nay"/"Hôm qua" xuất hiện đúng.
