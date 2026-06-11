# UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Áp dụng design spec [2026-06-12-ui-redesign-design.md](../specs/2026-06-12-ui-redesign-design.md): hệ token 2 phong cách (Tinh gọn / Sổ tay ấm) × light/dark, font Be Vietnam Pro, icon danh mục từ DB, restyle 7 màn hình, số tiền không dấu trừ, lời nhắn AI dạng card.

**Architecture:** Token tập trung trong `core/theme.dart` (hàm `buildTheme(style, brightness)` + `ThemeExtension MoneyColors`), phong cách lưu ở `AppPrefs` (`theme_style`). Screens chỉ đọc màu qua `Theme`/`MoneyColors`, icon danh mục qua `core/category_visuals.dart`. Widget dùng chung mới: `TransactionTile`, `EmptyState`. Mọi `Key` widget hiện có GIỮ NGUYÊN.

**Tech Stack:** Flutter (Material 3, Riverpod 2, Drift), font tĩnh Be Vietnam Pro bundle assets.

**Bối cảnh máy dev (Windows):** chạy test từ `app/`: `flutter test`. Nếu test treo không output: kill process mồ côi `taskkill //F //IM flutter_tester.exe; taskkill //F //IM dart.exe` rồi chạy lại. Trong `testWidgets`, đọc stream Drift (`watchX().first`) phải bọc `tester.runAsync(...)`.

**Quy ước chung cho mọi task:** sau khi sửa code chạy `flutter analyze` phải 0 lỗi trước khi commit.

---

### Task 1: AppThemeStyle trong AppPrefs

**Files:**
- Modify: `app/lib/core/prefs.dart`
- Test: `app/test/core/prefs_test.dart`

- [ ] **Step 1: Viết test fail** — thêm vào cuối `main()` của `prefs_test.dart`:

```dart
  test('theme style defaults to classic and persists', () async {
    final prefs = await AppPrefs.load();
    expect(prefs.themeStyle, AppThemeStyle.classic);
    await prefs.setThemeStyle(AppThemeStyle.warm);
    expect((await AppPrefs.load()).themeStyle, AppThemeStyle.warm);
  });
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/core/prefs_test.dart`
Expected: FAIL biên dịch, `AppThemeStyle` chưa tồn tại.

- [ ] **Step 3: Implement** — trong `prefs.dart`, thêm dưới `enum Tone`:

```dart
/// Phong cách giao diện: classic = Tinh gọn (emerald), warm = Sổ tay ấm.
enum AppThemeStyle { classic, warm }
```

Trong class `AppPrefs` thêm key và getter/setter (cạnh `_kThemeMode`):

```dart
  static const _kThemeStyle = 'theme_style';

  AppThemeStyle get themeStyle => AppThemeStyle.values.firstWhere(
        (s) => s.name == _p.getString(_kThemeStyle),
        orElse: () => AppThemeStyle.classic,
      );
  Future<void> setThemeStyle(AppThemeStyle s) =>
      _p.setString(_kThemeStyle, s.name);
```

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/core/prefs_test.dart`
Expected: PASS toàn bộ.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/prefs.dart app/test/core/prefs_test.dart
git commit -m "feat(ui): AppThemeStyle pref (classic/warm)"
```

---

### Task 2: Token + MoneyColors + buildTheme

**Files:**
- Rewrite: `app/lib/core/theme.dart`
- Create: `app/test/core/theme_test.dart`

- [ ] **Step 1: Viết test fail** — tạo `app/test/core/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';

void main() {
  test('buildTheme cấp MoneyColors cho cả 4 tổ hợp style x brightness', () {
    for (final s in AppThemeStyle.values) {
      for (final b in [Brightness.light, Brightness.dark]) {
        final t = buildTheme(s, b);
        expect(t.brightness, b);
        final money = t.extension<MoneyColors>();
        expect(money, isNotNull, reason: '$s/$b thiếu MoneyColors');
        expect(money!.expense, isNot(money.income));
      }
    }
  });

  test('primary đúng spec: classic emerald, warm terracotta', () {
    expect(buildTheme(AppThemeStyle.classic, Brightness.light).colorScheme.primary,
        const Color(0xFF0B7A4F));
    expect(buildTheme(AppThemeStyle.warm, Brightness.light).colorScheme.primary,
        const Color(0xFFD96C3B));
    expect(buildTheme(AppThemeStyle.classic, Brightness.dark).colorScheme.primary,
        const Color(0xFF5BC894));
    expect(buildTheme(AppThemeStyle.warm, Brightness.dark).colorScheme.primary,
        const Color(0xFFE0936A));
  });

  test('buildLightTheme/buildDarkTheme cũ vẫn dùng được (classic)', () {
    expect(buildLightTheme().colorScheme.primary, const Color(0xFF0B7A4F));
    expect(buildDarkTheme().brightness, Brightness.dark);
  });
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/core/theme_test.dart`
Expected: FAIL biên dịch (`buildTheme`, `MoneyColors` chưa có).

- [ ] **Step 3: Viết lại `app/lib/core/theme.dart`** (toàn bộ file):

```dart
import 'package:flutter/material.dart';
import 'package:moneynote/core/prefs.dart' show AppThemeStyle;

/// Màu ngữ nghĩa tiền tệ, tách khỏi ColorScheme. Screens lấy qua
/// Theme.of(context).extension<MoneyColors>()!
class MoneyColors extends ThemeExtension<MoneyColors> {
  final Color income;
  final Color expense;
  final Color transfer;
  final Color warn; // cảnh báo sớm + lời nhắn AI
  final Color warnContainer;
  final Color onWarnContainer;
  const MoneyColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warn,
    required this.warnContainer,
    required this.onWarnContainer,
  });

  @override
  MoneyColors copyWith({
    Color? income, Color? expense, Color? transfer,
    Color? warn, Color? warnContainer, Color? onWarnContainer,
  }) =>
      MoneyColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        transfer: transfer ?? this.transfer,
        warn: warn ?? this.warn,
        warnContainer: warnContainer ?? this.warnContainer,
        onWarnContainer: onWarnContainer ?? this.onWarnContainer,
      );

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    return MoneyColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnContainer: Color.lerp(warnContainer, other.warnContainer, t)!,
      onWarnContainer: Color.lerp(onWarnContainer, other.onWarnContainer, t)!,
    );
  }
}

class _Tokens {
  final Color bg, surface, primary, onPrimary, primaryContainer,
      onPrimaryContainer, warn, warnContainer, onWarnContainer,
      expense, income, transfer, ink, inkMuted, divider;
  const _Tokens({
    required this.bg, required this.surface, required this.primary,
    required this.onPrimary, required this.primaryContainer,
    required this.onPrimaryContainer, required this.warn,
    required this.warnContainer, required this.onWarnContainer,
    required this.expense, required this.income, required this.transfer,
    required this.ink, required this.inkMuted, required this.divider,
  });
}

const _classicLight = _Tokens(
  bg: Color(0xFFF6F7F5), surface: Color(0xFFFFFFFF),
  primary: Color(0xFF0B7A4F), onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFDFF0E8), onPrimaryContainer: Color(0xFF064D32),
  warn: Color(0xFFD97A4A), warnContainer: Color(0xFFF8E8DC),
  onWarnContainer: Color(0xFF7A3A1B),
  expense: Color(0xFFC04848), income: Color(0xFF0B7A4F),
  transfer: Color(0xFF5E6963),
  ink: Color(0xFF15201A), inkMuted: Color(0xFF5E6963),
  divider: Color(0xFFE7EBE8),
);

const _classicDark = _Tokens(
  bg: Color(0xFF111513), surface: Color(0xFF1A201C),
  primary: Color(0xFF5BC894), onPrimary: Color(0xFF06281A),
  primaryContainer: Color(0xFF1F3B2E), onPrimaryContainer: Color(0xFFBFE8D4),
  warn: Color(0xFFE0936A), warnContainer: Color(0xFF3D2A1E),
  onWarnContainer: Color(0xFFF0CDB5),
  expense: Color(0xFFE07A6E), income: Color(0xFF5BC894),
  transfer: Color(0xFF9BA59E),
  ink: Color(0xFFE7EDE9), inkMuted: Color(0xFF9BA59E),
  divider: Color(0xFF262D28),
);

const _warmLight = _Tokens(
  bg: Color(0xFFFAF3E7), surface: Color(0xFFFFFCF5),
  primary: Color(0xFFD96C3B), onPrimary: Color(0xFFFFF8EC),
  primaryContainer: Color(0xFFF6E3CB), onPrimaryContainer: Color(0xFF7A3A1B),
  warn: Color(0xFFB98345), warnContainer: Color(0xFFF2E2C8),
  onWarnContainer: Color(0xFF5C3D14),
  expense: Color(0xFFB3422F), income: Color(0xFF4F6E3C),
  transfer: Color(0xFF8A7A63),
  ink: Color(0xFF42382B), inkMuted: Color(0xFF8A7A63),
  divider: Color(0xFFF0E6D4),
);

const _warmDark = _Tokens(
  bg: Color(0xFF181411), surface: Color(0xFF221C16),
  primary: Color(0xFFE0936A), onPrimary: Color(0xFF2A1A10),
  primaryContainer: Color(0xFF3D2A1E), onPrimaryContainer: Color(0xFFF0CDB5),
  warn: Color(0xFFC99A5B), warnContainer: Color(0xFF38301F),
  onWarnContainer: Color(0xFFEAD9B8),
  expense: Color(0xFFE08573), income: Color(0xFF9DBE7F),
  transfer: Color(0xFFA89878),
  ink: Color(0xFFEFE6D8), inkMuted: Color(0xFFB3A48C),
  divider: Color(0xFF322A20),
);

ThemeData buildTheme(AppThemeStyle style, Brightness brightness) {
  final t = switch ((style, brightness)) {
    (AppThemeStyle.classic, Brightness.light) => _classicLight,
    (AppThemeStyle.classic, Brightness.dark) => _classicDark,
    (AppThemeStyle.warm, Brightness.light) => _warmLight,
    (AppThemeStyle.warm, Brightness.dark) => _warmDark,
  };
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.primary,
    onPrimary: t.onPrimary,
    primaryContainer: t.primaryContainer,
    onPrimaryContainer: t.onPrimaryContainer,
    secondary: t.warn,
    onSecondary: t.onPrimary,
    secondaryContainer: t.warnContainer,
    onSecondaryContainer: t.onWarnContainer,
    error: t.expense,
    onError: brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF2A0E0B),
    surface: t.surface,
    onSurface: t.ink,
    onSurfaceVariant: t.inkMuted,
    outline: t.divider,
    outlineVariant: t.divider,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    fontFamily: 'BeVietnamPro',
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: t.divider, thickness: 0.6),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      indicatorColor: t.primaryContainer,
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: t.inkMuted)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.divider, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.divider, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.primary, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: t.divider, width: 0.8),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: t.surface,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    extensions: [
      MoneyColors(
        income: t.income, expense: t.expense, transfer: t.transfer,
        warn: t.warn, warnContainer: t.warnContainer,
        onWarnContainer: t.onWarnContainer,
      ),
    ],
  );
}

ThemeData buildLightTheme() => buildTheme(AppThemeStyle.classic, Brightness.light);
ThemeData buildDarkTheme() => buildTheme(AppThemeStyle.classic, Brightness.dark);
```

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/core/theme_test.dart && flutter test`
Expected: PASS toàn bộ (75 + 3 test mới + test Task 1).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/theme.dart app/test/core/theme_test.dart
git commit -m "feat(ui): design tokens 2 styles x light/dark + MoneyColors extension"
```

---

### Task 3: Font Be Vietnam Pro (assets)

**Files:**
- Create: `app/assets/fonts/BeVietnamPro-Regular.ttf`, `BeVietnamPro-Medium.ttf`, `BeVietnamPro-SemiBold.ttf`
- Modify: `app/pubspec.yaml`

Đây là task cấu hình, không có test riêng; gate là `flutter analyze` + full suite.

- [ ] **Step 1: Tải font** (từ repo google/fonts, license OFL):

```bash
mkdir -p app/assets/fonts
cd app/assets/fonts
curl -fLO https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro/BeVietnamPro-Regular.ttf
curl -fLO https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro/BeVietnamPro-Medium.ttf
curl -fLO https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro/BeVietnamPro-SemiBold.ttf
```

Expected: 3 file .ttf, mỗi file > 100KB. NẾU tải lỗi (offline/404): BỎ QUA toàn bộ task này và xoá dòng `fontFamily: 'BeVietnamPro',` trong `theme.dart` (app dùng font hệ thống, các task sau không phụ thuộc font), commit ghi chú rõ.

- [ ] **Step 2: Khai báo trong `app/pubspec.yaml`** — thay block `flutter:` cuối file:

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: BeVietnamPro
      fonts:
        - asset: assets/fonts/BeVietnamPro-Regular.ttf
        - asset: assets/fonts/BeVietnamPro-Medium.ttf
          weight: 500
        - asset: assets/fonts/BeVietnamPro-SemiBold.ttf
          weight: 600
```

- [ ] **Step 3: Verify**

Run: `flutter pub get && flutter analyze && flutter test`
Expected: 0 lỗi, toàn bộ test pass.

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml app/assets/fonts
git commit -m "feat(ui): bundle Be Vietnam Pro (OFL) as app font"
```

---

### Task 4: MaterialApp áp dụng phong cách từ prefs

**Files:**
- Modify: `app/lib/main.dart`
- Test: `app/test/widget/app_locale_test.dart`

- [ ] **Step 1: Viết test fail** — thêm vào cuối `main()` của `app_locale_test.dart`:

```dart
  testWidgets('saved theme style (warm) is applied to MaterialApp', (tester) async {
    SharedPreferences.setMockInitialValues({'theme_style': 'warm'});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MoneyNoteApp(),
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, const Color(0xFFD96C3B));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/widget/app_locale_test.dart`
Expected: test mới FAIL (primary vẫn emerald vì style chưa được wire).

- [ ] **Step 3: Sửa `main.dart`** — trong `MoneyNoteApp.build`, thay phần đọc prefs và `theme`/`darkTheme`:

```dart
    final prefs = ref.watch(prefsProvider).valueOrNull;
    final themeMode = prefs?.themeMode ?? ThemeMode.system;
    final style = prefs?.themeStyle ?? AppThemeStyle.classic;
    return MaterialApp(
      title: 'MoneyNote',
      theme: buildTheme(style, Brightness.light),
      darkTheme: buildTheme(style, Brightness.dark),
      themeMode: themeMode,
```

Thêm import nếu thiếu: `import 'package:moneynote/core/prefs.dart';`

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/widget/app_locale_test.dart && flutter test`
Expected: PASS toàn bộ.

- [ ] **Step 5: Commit**

```bash
git add app/lib/main.dart app/test/widget/app_locale_test.dart
git commit -m "feat(ui): MaterialApp builds theme from saved style + mode"
```

---

### Task 5: Cài đặt có mục Phong cách

**Files:**
- Modify: `app/lib/features/settings/settings_screen.dart`
- Test: `app/test/widget/settings_test.dart`

- [ ] **Step 1: Viết test fail** — thêm vào `settings_test.dart`:

```dart
  testWidgets('settings can switch theme style to warm', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sổ tay ấm'));
    await tester.pumpAndSettle();

    final prefs = await tester.runAsync(AppPrefs.load);
    expect(prefs!.themeStyle, AppThemeStyle.warm);
  });
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/widget/settings_test.dart`
Expected: FAIL, không tìm thấy text 'Sổ tay ấm'.

- [ ] **Step 3: Implement** — trong `settings_screen.dart`, dưới section 'Giao diện' (RadioGroup ThemeMode) thêm:

```dart
              const _SectionHeader('Phong cách'),
              RadioGroup<AppThemeStyle>(
                groupValue: prefs.themeStyle,
                onChanged: (v) async {
                  if (v == null) return;
                  await prefs.setThemeStyle(v);
                  ref.invalidate(prefsProvider);
                },
                child: Column(
                  children: [
                    for (final s in AppThemeStyle.values)
                      RadioListTile<AppThemeStyle>(
                        title: Text(_styleLabel(s)),
                        secondary: _StylePreviewDot(style: s),
                        value: s,
                      ),
                  ],
                ),
              ),
              const Divider(),
```

Thêm helper trong `_SettingsScreenState`:

```dart
  String _styleLabel(AppThemeStyle s) => switch (s) {
        AppThemeStyle.classic => 'Tinh gọn',
        AppThemeStyle.warm => 'Sổ tay ấm',
      };
```

Thêm widget cuối file:

```dart
class _StylePreviewDot extends StatelessWidget {
  final AppThemeStyle style;
  const _StylePreviewDot({required this.style});

  @override
  Widget build(BuildContext context) {
    final light = buildTheme(style, Brightness.light).colorScheme;
    return SizedBox(
      width: 36,
      child: Stack(
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
                color: light.primary, shape: BoxShape.circle),
          ),
          Positioned(
            left: 14,
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: light.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Theme.of(context).colorScheme.outline, width: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Thêm import: `import 'package:moneynote/core/theme.dart';`

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/widget/settings_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/settings/settings_screen.dart app/test/widget/settings_test.dart
git commit -m "feat(ui): theme style picker (Tinh gon / So tay am) in settings"
```

---

### Task 6: category_visuals (icon + tint từ DB)

**Files:**
- Create: `app/lib/core/category_visuals.dart`
- Test: `app/test/core/category_visuals_test.dart`

- [ ] **Step 1: Viết test fail** — tạo `app/test/core/category_visuals_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/category_visuals.dart';

void main() {
  test('map đủ 10 icon seed', () {
    expect(categoryIcon('restaurant'), Icons.restaurant);
    expect(categoryIcon('directions_bus'), Icons.directions_bus);
    expect(categoryIcon('receipt_long'), Icons.receipt_long);
    expect(categoryIcon('shopping_bag'), Icons.shopping_bag);
    expect(categoryIcon('sports_esports'), Icons.sports_esports);
    expect(categoryIcon('health_and_safety'), Icons.health_and_safety);
    expect(categoryIcon('school'), Icons.school);
    expect(categoryIcon('payments'), Icons.payments);
    expect(categoryIcon('card_giftcard'), Icons.card_giftcard);
    expect(categoryIcon('category'), Icons.category);
  });

  test('chuỗi lạ fallback Icons.category', () {
    expect(categoryIcon('khong_ton_tai'), Icons.category);
  });

  test('categoryTint giữ RGB, alpha 36', () {
    final tint = categoryTint(0xFFEF5350);
    expect(tint.alpha, 36);
    expect(tint.red, 0xEF);
  });
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/core/category_visuals_test.dart`
Expected: FAIL biên dịch (file chưa tồn tại).

- [ ] **Step 3: Implement** — tạo `app/lib/core/category_visuals.dart`:

```dart
import 'package:flutter/material.dart';

const _icons = <String, IconData>{
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'receipt_long': Icons.receipt_long,
  'shopping_bag': Icons.shopping_bag,
  'sports_esports': Icons.sports_esports,
  'health_and_safety': Icons.health_and_safety,
  'school': Icons.school,
  'payments': Icons.payments,
  'card_giftcard': Icons.card_giftcard,
  'category': Icons.category,
};

/// Map chuỗi icon lưu trong DB sang IconData; chuỗi lạ fallback Icons.category.
IconData categoryIcon(String name) => _icons[name] ?? Icons.category;

/// Nền ô icon: màu danh mục với alpha 14% (36/255), dùng được cả light/dark.
Color categoryTint(int argb) => Color(argb).withAlpha(36);

/// Ô icon danh mục 36px bo 12 dùng chung mọi danh sách.
class CategoryIconBox extends StatelessWidget {
  final String iconName;
  final int color;
  final double size;
  const CategoryIconBox({
    super.key,
    required this.iconName,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: categoryTint(color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(categoryIcon(iconName), size: size * 0.5, color: Color(color)),
      );
}
```

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/core/category_visuals_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/category_visuals.dart app/test/core/category_visuals_test.dart
git commit -m "feat(ui): category icon/tint visuals from existing DB fields"
```

---

### Task 7: groupByDay (domain thuần)

**Files:**
- Create: `app/lib/domain/txn_grouping.dart`
- Test: `app/test/domain/txn_grouping_test.dart`

- [ ] **Step 1: Viết test fail** — tạo `app/test/domain/txn_grouping_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/domain/txn_grouping.dart';

Transaction _txn(String id, DateTime at) => Transaction(
      id: id, amount: 1000, type: TransactionType.expense,
      categoryId: null, walletId: 'w1', toWalletId: null,
      note: '', occurredAt: at, createdAt: at, updatedAt: at,
    );

void main() {
  test('nhóm theo ngày với nhãn Hôm nay / Hôm qua / d/M / d/M/yyyy', () {
    final today = DateTime(2026, 6, 12);
    final groups = groupByDay([
      _txn('1', DateTime(2026, 6, 12, 9)),
      _txn('2', DateTime(2026, 6, 12, 7)),
      _txn('3', DateTime(2026, 6, 11)),
      _txn('4', DateTime(2026, 5, 30)),
      _txn('5', DateTime(2025, 12, 31)),
    ], today);
    expect(groups.map((g) => g.label),
        ['Hôm nay', 'Hôm qua', '30/5', '31/12/2025']);
    expect(groups.first.txns, hasLength(2));
  });

  test('danh sách rỗng trả về rỗng', () {
    expect(groupByDay(const [], DateTime(2026, 6, 12)), isEmpty);
  });
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/domain/txn_grouping_test.dart`
Expected: FAIL biên dịch.

- [ ] **Step 3: Implement** — tạo `app/lib/domain/txn_grouping.dart`:

```dart
import 'package:moneynote/data/database.dart';

class DayGroup {
  final String label;
  final List<Transaction> txns;
  const DayGroup(this.label, this.txns);
}

/// Nhóm giao dịch (đã sort mới trước) theo ngày, nhãn thân thiện theo [today].
List<DayGroup> groupByDay(List<Transaction> txns, DateTime today) {
  final groups = <DayGroup>[];
  DateTime? currentDay;
  for (final t in txns) {
    final d = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
    if (currentDay == null || d != currentDay) {
      currentDay = d;
      groups.add(DayGroup(_label(d, today), []));
    }
    groups.last.txns.add(t);
  }
  return groups;
}

String _label(DateTime d, DateTime today) {
  final t = DateTime(today.year, today.month, today.day);
  if (d == t) return 'Hôm nay';
  if (d == t.subtract(const Duration(days: 1))) return 'Hôm qua';
  if (d.year == t.year) return '${d.day}/${d.month}';
  return '${d.day}/${d.month}/${d.year}';
}
```

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/domain/txn_grouping_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/domain/txn_grouping.dart app/test/domain/txn_grouping_test.dart
git commit -m "feat(ui): pure day-grouping for transaction lists"
```

---

### Task 8: TransactionTile (widget dùng chung)

**Files:**
- Create: `app/lib/features/transactions/transaction_tile.dart`
- Test: `app/test/widget/transaction_tile_test.dart`

- [ ] **Step 1: Viết test fail** — tạo `app/test/widget/transaction_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/database.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';

Transaction _txn(TransactionType type, int amount) => Transaction(
      id: 't-${type.name}', amount: amount, type: type,
      categoryId: type == TransactionType.transfer ? null : 'c1',
      walletId: 'w1', toWalletId: null, note: 'ghi chú',
      occurredAt: DateTime(2026, 6, 12), createdAt: DateTime(2026, 6, 12),
      updatedAt: DateTime(2026, 6, 12),
    );

Category get _cat => Category(
      id: 'c1', name: 'Ăn uống', icon: 'restaurant', color: 0xFFEF5350,
      type: CategoryType.expense, isDefault: true,
      createdAt: DateTime(2026, 6, 1), updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildTheme(AppThemeStyle.classic, Brightness.light),
        home: Scaffold(body: child),
      );

  testWidgets('chi: không dấu trừ; thu: có dấu cộng; chuyển: trung tính',
      (tester) async {
    await tester.pumpWidget(host(Column(children: [
      TransactionTile(txn: _txn(TransactionType.expense, 50000), category: _cat),
      TransactionTile(txn: _txn(TransactionType.income, 2000000), category: _cat),
      TransactionTile(txn: _txn(TransactionType.transfer, 300000)),
    ])));

    expect(find.text('50.000 ₫'), findsOneWidget);
    expect(find.text('+2.000.000 ₫'), findsOneWidget);
    expect(find.text('300.000 ₫'), findsOneWidget);
    expect(find.textContaining('-50'), findsNothing);
    expect(find.text('Chuyển ví'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant), findsNWidgets(2));
  });

  testWidgets('không category và không transfer: nhãn Chưa phân loại',
      (tester) async {
    await tester.pumpWidget(host(
        TransactionTile(txn: _txn(TransactionType.expense, 1000))));
    expect(find.text('Chưa phân loại'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/widget/transaction_tile_test.dart`
Expected: FAIL biên dịch.

- [ ] **Step 3: Implement** — tạo `app/lib/features/transactions/transaction_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/money.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/data/database.dart';

/// Dòng giao dịch chuẩn dùng ở Tổng quan và Danh sách.
/// Quy ước tiền: chi và chuyển KHÔNG dấu, thu mang dấu cộng.
class TransactionTile extends StatelessWidget {
  final Transaction txn;
  final Category? category;
  final String? subtitle; // override; mặc định dùng txn.note
  final VoidCallback? onTap;
  const TransactionTile({
    super.key,
    required this.txn,
    this.category,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final money = Theme.of(context).extension<MoneyColors>()!;
    final isTransfer = txn.type == TransactionType.transfer;
    final amountColor = switch (txn.type) {
      TransactionType.income => money.income,
      TransactionType.expense => money.expense,
      TransactionType.transfer => money.transfer,
    };
    final prefix = txn.type == TransactionType.income ? '+' : '';
    final title = category?.name ?? (isTransfer ? 'Chuyển ví' : 'Chưa phân loại');
    final sub = subtitle ?? txn.note;

    return ListTile(
      onTap: onTap,
      leading: isTransfer
          ? Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: money.transfer.withAlpha(36),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.swap_horiz, size: 18, color: money.transfer),
            )
          : CategoryIconBox(
              iconName: category?.icon ?? 'category',
              color: category?.color ?? 0xFF9E9E9E,
            ),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: sub.isEmpty
          ? null
          : Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: Text(
        '$prefix${formatVnd(txn.amount)}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: amountColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
```

Lưu ý import `dart:ui` không cần: `FontFeature` có sẵn qua material.

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/widget/transaction_tile_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/transactions/transaction_tile.dart app/test/widget/transaction_tile_test.dart
git commit -m "feat(ui): shared TransactionTile (no minus sign, category icons)"
```

---

### Task 9: EmptyState + Danh sách giao dịch restyle

**Files:**
- Create: `app/lib/core/widgets/empty_state.dart`
- Modify: `app/lib/features/transactions/transactions_list_screen.dart`
- Test: `app/test/widget/search_filter_test.dart` (đã có, phải vẫn pass), thêm assert nhóm ngày

- [ ] **Step 1: Tạo `app/lib/core/widgets/empty_state.dart`** (widget thuần trình bày, test qua màn hình dùng nó):

```dart
import 'package:flutter/material.dart';

/// Trạng thái rỗng thân thiện: icon nhạt + tiêu đề + gợi ý hành động.
/// QUAN TRỌNG: title là Text riêng để các test find.text khớp chính xác.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  const EmptyState({super.key, required this.icon, required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Viết test fail cho nhóm ngày** — thêm vào `search_filter_test.dart` (file đã pump TransactionsListScreen với data; thêm test mới cùng cách setup, dùng giao dịch hôm nay):

```dart
  testWidgets('danh sách hiện header nhóm ngày', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    await tester.runAsync(() async {
      final w = (await repo.watchWallets().first).single;
      await repo.addTransaction(
          amount: 50000, type: TransactionType.expense, walletId: w.id);
    });

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: TransactionsListScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hôm nay'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
```

(Thêm import còn thiếu cho file test nếu chưa có: `repository.dart`.)

- [ ] **Step 3: Chạy để thấy fail**

Run: `flutter test test/widget/search_filter_test.dart`
Expected: test mới FAIL ('Hôm nay' chưa tồn tại), test cũ vẫn pass.

- [ ] **Step 4: Sửa `transactions_list_screen.dart`** — thay block `data: (all) {...}` bên trong `txnsAsync.when`:

```dart
            data: (all) {
              final txns =
                  filterTransactions(all, filter, categoryNameById: catName);
              if (txns.isEmpty) {
                return filter.isActive
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Không có giao dịch khớp')
                    : const EmptyState(
                        icon: Icons.receipt_long,
                        title: 'Chưa có giao dịch nào',
                        hint: "Bấm Thêm rồi gõ 'ăn phở 50k' là xong");
              }
              final catById = {for (final c in categories) c.id: c};
              final groups = groupByDay(txns, DateTime.now());
              return ListView(
                children: [
                  for (final g in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                      child: Text(g.label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ),
                    for (final t in g.txns)
                      Dismissible(
                        key: Key('txn_${t.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Theme.of(context)
                              .extension<MoneyColors>()!
                              .expense,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          final repo = ref.read(repositoryProvider);
                          repo.softDeleteTransaction(t.id);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              content: const Text('Đã xoá giao dịch'),
                              action: SnackBarAction(
                                label: 'Hoàn tác',
                                onPressed: () => repo.restoreTransaction(t.id),
                              ),
                            ));
                        },
                        child: TransactionTile(
                          txn: t,
                          category: catById[t.categoryId],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    AddTransactionScreen(existing: t)),
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
```

Imports thêm vào đầu file:

```dart
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/domain/txn_grouping.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
```

Search field: đổi `hintText` giữ nguyên, thêm bo pill bằng cách bọc `isDense: true` hiện có với `border` mặc định theme (đã bo 14 từ InputDecorationTheme, không cần sửa thêm).

- [ ] **Step 5: Chạy test pass**

Run: `flutter test test/widget/search_filter_test.dart test/widget/edit_transaction_test.dart`
Expected: PASS toàn bộ (edit test vẫn tap qua `find.text('Ăn uống')`, TransactionTile vẫn render text đó).

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/widgets/empty_state.dart app/lib/features/transactions/transactions_list_screen.dart app/test/widget/search_filter_test.dart
git commit -m "feat(ui): transactions list with day groups, shared tile, empty states"
```

---

### Task 10: BudgetTile restyle (icon, cảnh báo 80%)

**Files:**
- Modify: `app/lib/features/budgets/budgets_screen.dart`
- Test: `app/test/widget/budgets_test.dart`

- [ ] **Step 1: Đọc `app/test/widget/budgets_test.dart`** để biết assertion hiện tại (test over-budget màu đỏ). Viết test fail mới thêm vào file đó:

```dart
  testWidgets('ngân sách chạm 80% hiện màu cảnh báo (warn)', (tester) async {
    // Setup giống test over-budget hiện có nhưng spent/limit = 0.85.
    // Sau khi pump BudgetsScreen với budget limit 100000 và expense 85000:
    final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator).first);
    final warnColor = buildTheme(AppThemeStyle.classic, Brightness.light)
        .extension<MoneyColors>()!
        .warn;
    expect(progress.color, warnColor);
  });
```

(Engineer: copy phần setup db/seed/budget từ test over-budget có sẵn trong file, đổi số tiền expense thành 85000, limit 100000. Thêm import `core/prefs.dart`, `core/theme.dart`.)

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/widget/budgets_test.dart`
Expected: test mới FAIL (màu hiện tại là null/red, chưa có warn).

- [ ] **Step 3: Sửa `BudgetTile`** trong `budgets_screen.dart`, thay toàn bộ class:

```dart
/// Progress tile dùng ở màn Ngân sách và card ngân sách trên Tổng quan.
/// Trạng thái màu: đủ 100% trở lên = expense (+ nhãn "vượt"), từ 80% = warn,
/// dưới đó = primary.
class BudgetTile extends StatelessWidget {
  final String name;
  final int spent;
  final int limit;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const BudgetTile({
    super.key,
    required this.name,
    required this.spent,
    required this.limit,
    this.leading,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final money = Theme.of(context).extension<MoneyColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final over = spent > limit;
    final ratioRaw = limit <= 0 ? 0.0 : spent / limit;
    final ratio = ratioRaw.clamp(0.0, 1.0);
    final barColor = over
        ? money.expense
        : ratioRaw >= 0.8
            ? money.warn
            : scheme.primary;
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: leading,
      title: Text(name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: barColor,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatVnd(spent)} / ${formatVnd(limit)}',
                  style: TextStyle(
                      fontSize: 13,
                      color: over ? money.expense : scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              if (over)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: money.expense.withAlpha(28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('vượt',
                      style: TextStyle(fontSize: 11, color: money.expense)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

Import thêm: `import 'package:moneynote/core/theme.dart';`

Trong `BudgetsScreen.build`, truyền leading cho mỗi tile (cần map category đầy đủ):

```dart
    final catById = {for (final c in categories) c.id: c};
```

và trong vòng `for (final b in budgets)`:

```dart
                  BudgetTile(
                    name: b.categoryId == null
                        ? 'Tổng'
                        : (catName[b.categoryId] ?? 'Chưa phân loại'),
                    leading: b.categoryId == null
                        ? Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.account_balance_wallet,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme.onPrimaryContainer),
                          )
                        : CategoryIconBox(
                            iconName: catById[b.categoryId]?.icon ?? 'category',
                            color: catById[b.categoryId]?.color ?? 0xFF9E9E9E),
                    spent: spentInMonth(txns, month, categoryId: b.categoryId),
                    limit: b.amount,
                    onTap: () => _editBudget(context, ref, b),
                    onLongPress: () => _confirmDelete(context, ref, b),
                  ),
```

Import: `import 'package:moneynote/core/category_visuals.dart';`

Nếu test cũ assert `'⚠ vượt'` hoặc màu `Colors.red`: cập nhật thành `find.text('vượt')` và màu `money.expense` tương ứng.

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/widget/budgets_test.dart`
Expected: PASS toàn bộ.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/budgets/budgets_screen.dart app/test/widget/budgets_test.dart
git commit -m "feat(ui): BudgetTile icons + 80% warn state + 'vuot' chip"
```

---

### Task 11: Dashboard restyle (hero + ngân sách + gần đây)

**Files:**
- Modify: `app/lib/features/dashboard/dashboard_screen.dart`
- Test: `app/test/widget/dashboard_test.dart`

- [ ] **Step 1: Viết test fail** — thêm vào `dashboard_test.dart`:

```dart
  testWidgets('hero hiện Còn lại tháng này và nhóm ngày ở Gần đây',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedIfEmpty(db);
    addTearDown(db.close);
    final repo = AppRepository(db);
    await tester.runAsync(() async {
      final w = (await repo.watchWallets().first).single;
      await repo.addTransaction(
          amount: 50000, type: TransactionType.expense, walletId: w.id);
    });

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Còn lại tháng này'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.textContaining('-'), findsNothing); // không dấu trừ

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
```

(Import thêm `repository.dart` nếu thiếu.)

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/widget/dashboard_test.dart`
Expected: test mới FAIL ('Còn lại tháng này' chưa có).

- [ ] **Step 3: Viết lại phần `data:` của `DashboardScreen.build`** — thay `ListView` hiện tại:

```dart
      data: (txns) {
        final s = summarize(txns, month);
        final catById = {for (final c in categories) c.id: c};
        final recentGroups = groupByDay(txns.take(15).toList(), DateTime.now());
        final money = Theme.of(context).extension<MoneyColors>()!;
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const Key('prevMonth'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () =>
                        ref.read(selectedMonthProvider.notifier).state =
                            DateTime(month.year, month.month - 1, 1),
                  ),
                  Text('Tháng ${month.month}/${month.year}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  IconButton(
                    key: const Key('nextMonth'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () =>
                        ref.read(selectedMonthProvider.notifier).state =
                            DateTime(month.year, month.month + 1, 1),
                  ),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Còn lại tháng này',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      formatVnd(s.net),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: s.net >= 0 ? money.income : money.expense,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _stat(context, 'Thu', s.income, money.income)),
                        SizedBox(
                            height: 28,
                            child: VerticalDivider(
                                width: 1,
                                color: Theme.of(context).colorScheme.outline)),
                        Expanded(
                            child: _stat(
                                context, 'Chi', s.expense, money.expense)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BudgetsScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text('Ngân sách',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      if (budgets.isEmpty)
                        const ListTile(
                          dense: true,
                          title: Text('Thêm ngân sách →'),
                        )
                      else
                        for (final b in budgets)
                          BudgetTile(
                            name: b.categoryId == null
                                ? 'Tổng'
                                : (catName[b.categoryId] ?? 'Chưa phân loại'),
                            leading: b.categoryId == null
                                ? Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.account_balance_wallet,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme.onPrimaryContainer),
                                  )
                                : CategoryIconBox(
                                    iconName:
                                        catById[b.categoryId]?.icon ?? 'category',
                                    color: catById[b.categoryId]?.color ??
                                        0xFF9E9E9E),
                            spent: spentInMonth(txns, month,
                                categoryId: b.categoryId),
                            limit: b.amount,
                          ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('Gần đây',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            if (txns.isEmpty)
              const EmptyState(
                  icon: Icons.receipt_long,
                  title: 'Chưa có giao dịch nào',
                  hint: "Bấm Thêm rồi gõ 'ăn phở 50k' là xong"),
            for (final g in recentGroups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(g.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              for (final t in g.txns)
                TransactionTile(txn: t, category: catById[t.categoryId]),
            ],
          ],
        );
      },
```

Thay helper `_row` cũ bằng `_stat`:

```dart
  Widget _stat(BuildContext c, String label, int amount, Color color) => Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(c).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(formatVnd(amount),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      );
```

Imports thêm:

```dart
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/empty_state.dart';
import 'package:moneynote/domain/txn_grouping.dart';
import 'package:moneynote/features/transactions/transaction_tile.dart';
```

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/widget/dashboard_test.dart && flutter test`
Expected: PASS toàn bộ (month nav test cũ vẫn pass nhờ giữ key).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/dashboard/dashboard_screen.dart app/test/widget/dashboard_test.dart
git commit -m "feat(ui): dashboard hero card, budget icons, day-grouped recents"
```

---

### Task 12: Màn Thêm/Sửa giao dịch (lời nhắn AI dạng card)

**Files:**
- Modify: `app/lib/features/transactions/add_transaction_screen.dart`
- Test: `app/test/widget/smart_input_test.dart`

- [ ] **Step 1: Viết test fail** — trong test đầu của `smart_input_test.dart` ('smart input parses and pre-fills the form'), thêm sau `expect(find.text('50.000'), findsOneWidget);`:

```dart
    expect(find.byKey(const Key('aiCommentCard')), findsOneWidget);
    expect(find.text('ok'), findsOneWidget); // comment hiện trong card
    expect(find.byType(SnackBar), findsNothing); // không còn SnackBar comment
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/widget/smart_input_test.dart`
Expected: FAIL (`aiCommentCard` chưa tồn tại).

- [ ] **Step 3: Implement trong `add_transaction_screen.dart`:**

3a. Thêm state: dưới `String? _aiSuggestedCategoryId;` thêm:

```dart
  String? _aiComment;
```

3b. Trong `_runSmartParse`, ở `setState` thành công thêm dòng, và XOÁ block SnackBar comment:

```dart
      setState(() {
        _type = res.type == 'income' ? TransactionType.income : TransactionType.expense;
        if (res.amount > 0) _amountCtrl.text = groupThousands(res.amount);
        _categoryId = catId;
        _aiSuggestedCategoryId = catId;
        _merchant = res.merchant;
        _aiComment = res.comment.isEmpty ? null : res.comment;
        if (res.note.isNotEmpty) _noteCtrl.text = res.note;
      });
```

(Xoá hẳn `if (res.comment.isNotEmpty) { ScaffoldMessenger...showSnackBar(...); }`. SnackBar lỗi AI trong `on AiException` GIỮ NGUYÊN.)

Khi parse mới bắt đầu, reset: trong `setState(() { _parsing = true; ... })` thêm `_aiComment = null;`.

3c. Render card dưới hàng smart input, ngay sau `const Divider(height: 24),` đổi thành:

```dart
            if (_aiComment != null)
              Container(
                key: const Key('aiCommentCard'),
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .extension<MoneyColors>()!
                      .warnContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 16,
                        color: Theme.of(context)
                            .extension<MoneyColors>()!
                            .onWarnContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_aiComment!,
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .extension<MoneyColors>()!
                                  .onWarnContainer)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close,
                          size: 16,
                          color: Theme.of(context)
                              .extension<MoneyColors>()!
                              .onWarnContainer),
                      onPressed: () => setState(() => _aiComment = null),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
```

3d. Amount field: thêm `textAlign: TextAlign.center,` và đổi style `fontSize: 32` giữ nguyên weight; decoration thay `labelText` bằng:

```dart
            decoration: const InputDecoration(
              hintText: '0',
              suffixText: '₫',
            ),
```

3e. Chip danh mục có icon: trong `Wrap`, thay `ChoiceChip` hiện tại:

```dart
                for (final c in cats)
                  ChoiceChip(
                    key: Key('cat_${c.name}'),
                    avatar: Icon(categoryIcon(c.icon),
                        size: 16,
                        color: _categoryId == c.id
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Color(c.color)),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    selectedColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
```

3f. Nút Lưu full-width: thay `FilledButton.icon` cuối:

```dart
          FilledButton.icon(
            key: const Key('saveButton'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(_isEditing ? 'Lưu thay đổi' : 'Lưu'),
          ),
```

LƯU Ý: `edit_transaction_test.dart` tap `find.byKey(const Key('saveButton'))` nên đổi label không vỡ test.

Imports thêm:

```dart
import 'package:moneynote/core/category_visuals.dart';
import 'package:moneynote/core/theme.dart';
```

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/widget/smart_input_test.dart test/widget/add_transaction_test.dart test/widget/transfer_test.dart test/widget/edit_transaction_test.dart`
Expected: PASS toàn bộ.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/transactions/add_transaction_screen.dart app/test/widget/smart_input_test.dart
git commit -m "feat(ui): AI comment as warm inline card, centered amount, icon chips"
```

---

### Task 13: Ví + Danh mục có icon thật

**Files:**
- Modify: `app/lib/features/wallets/wallets_screen.dart`
- Modify: `app/lib/features/categories/categories_screen.dart`
- Test: `app/test/widget/wallets_categories_test.dart` (mới)

- [ ] **Step 1: Viết test fail** — tạo `app/test/widget/wallets_categories_test.dart`:

```dart
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
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `flutter test test/widget/wallets_categories_test.dart`
Expected: FAIL (icon hiện tại là account_balance_wallet chung và chấm tròn).

- [ ] **Step 3: Implement.**

`wallets_screen.dart`: thêm helper trên `walletTypeLabel`:

```dart
IconData walletTypeIcon(WalletType t) => switch (t) {
      WalletType.cash => Icons.payments,
      WalletType.bank => Icons.account_balance,
      WalletType.ewallet => Icons.smartphone,
    };
```

Trong `ListTile` của ví, thay `leading` và `trailing`:

```dart
          ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(walletTypeIcon(w.type),
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            title: Text(w.name),
            subtitle: Text(walletTypeLabel(w.type)),
            trailing: Text(formatVnd(balanceOf(w, txns)),
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()])),
            onLongPress: () => _confirmDelete(context, ref, w),
          ),
```

Empty state ví: thay `const Center(child: Text('Chưa có ví nào'))` bằng:

```dart
      return const EmptyState(
          icon: Icons.account_balance_wallet,
          title: 'Chưa có ví nào',
          hint: 'Bấm Thêm ví để tạo ví đầu tiên');
```

Import: `import 'package:moneynote/core/widgets/empty_state.dart';`

`categories_screen.dart`: thay `_tile`:

```dart
  Widget _tile(BuildContext context, WidgetRef ref, Category c) => ListTile(
        leading: CategoryIconBox(iconName: c.icon, color: c.color),
        title: Text(c.name),
        onLongPress: () => _confirmDelete(context, ref, c),
      );
```

Import: `import 'package:moneynote/core/category_visuals.dart';`

- [ ] **Step 4: Chạy test pass**

Run: `flutter test test/widget/wallets_categories_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/wallets/wallets_screen.dart app/lib/features/categories/categories_screen.dart app/test/widget/wallets_categories_test.dart
git commit -m "feat(ui): wallet type icons, real category icons, friendly empty states"
```

---

### Task 14: Tổng kiểm + dọn màu hardcode

**Files:**
- Modify: bất kỳ file nào trong `app/lib/features/` còn `Colors.`

- [ ] **Step 1: Quét màu hardcode**

Run: `grep -rn "Colors\." app/lib/features/ | grep -v "Colors.white"`
Expected: chỉ còn `Colors.white` trong icon thùng rác Dismissible (chấp nhận). Mọi `Colors.red/green/grey` khác phải thay bằng `MoneyColors`/`colorScheme` theo pattern các task trước. Nếu còn sót thì sửa nốt cùng pattern.

- [ ] **Step 2: Gate cuối**

Run: `flutter analyze && flutter test`
Expected: 0 lỗi, toàn bộ test pass (dự kiến ~90 test).

- [ ] **Step 3: Chạy thử bằng mắt (nếu có emulator):** `flutter run`, kiểm tra 4 tổ hợp (2 phong cách × sáng/tối) ở Cài đặt, đọc được chữ ở mọi màn.

- [ ] **Step 4: Commit cuối**

```bash
git add -A
git commit -m "chore(ui): sweep hardcoded colors, final gate for UI redesign"
```

---

## Self-Review (đã chạy khi viết plan)

- Spec coverage: token 2 phong cách (Task 2), đổi phong cách trong Cài đặt (Task 5), font (Task 3), icon danh mục từ DB (Task 6, 8, 10, 11, 13), không dấu trừ + dấu cộng thu (Task 8), nhóm theo ngày (Task 7, 9, 11), lời nhắn AI card (Task 12), cảnh báo 80% (Task 10), empty states (Task 9, 11, 13), giữ Keys (mọi task).
- Placeholder: không còn TBD; Task 10 Step 1 yêu cầu engineer đọc test hiện có trước khi copy setup, có chỉ dẫn cụ thể số tiền.
- Type consistency: `MoneyColors` (income/expense/transfer/warn/warnContainer/onWarnContainer), `buildTheme(AppThemeStyle, Brightness)`, `categoryIcon(String)`, `CategoryIconBox(iconName:, color:)`, `groupByDay(List<Transaction>, DateTime)`, `TransactionTile(txn:, category:, subtitle:, onTap:)` dùng thống nhất ở Task 8 đến 13.
