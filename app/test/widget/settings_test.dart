import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('rows show current values + About by default', (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await pumpSettings(tester);

    expect(find.text('Nghiêm túc'), findsOneWidget);   // tone value
    expect(find.text('Theo hệ thống'), findsOneWidget); // theme value
    expect(find.text('Tinh gọn'), findsOneWidget);      // style value
    expect(find.text('MoneyNote'), findsOneWidget);     // About
    expect(find.byKey(const Key('exportCsv')), findsOneWidget);
    expect(find.byKey(const Key('recurringRules')), findsOneWidget);
  });

  testWidgets('can change the AI server URL via the drill-in sheet',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await pumpSettings(tester);

    await tester.tap(find.text('Máy chủ'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('baseUrlField')), 'https://mn.example.com');
    await tester.tap(find.byKey(const Key('saveBaseUrl')));
    await tester.pumpAndSettle();

    final prefs = await tester.runAsync(AppPrefs.load);
    expect(prefs!.baseUrl, 'https://mn.example.com');
  });

  testWidgets('can switch theme mode to dark via the picker', (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await pumpSettings(tester);

    await tester.tap(find.text('Chế độ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();

    final prefs = await tester.runAsync(AppPrefs.load);
    expect(prefs!.themeMode, ThemeMode.dark);
  });

  testWidgets('can switch theme style to warm via the picker', (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await pumpSettings(tester);

    await tester.tap(find.text('Phong cách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sổ tay ấm'));
    await tester.pumpAndSettle();

    final prefs = await tester.runAsync(AppPrefs.load);
    expect(prefs!.themeStyle, AppThemeStyle.warm);
  });

  testWidgets('CSV row opens the export range sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('exportCsv')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn khoảng thời gian'), findsOneWidget);
  });
}
