import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings can change the AI server URL', (tester) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('baseUrlField')), 'https://mn.example.com');
    await tester.tap(find.byKey(const Key('saveBaseUrl')));
    await tester.pumpAndSettle();

    final prefs = await tester.runAsync(AppPrefs.load);
    expect(prefs!.baseUrl, 'https://mn.example.com');
  });

  testWidgets('settings can switch theme mode to dark', (tester) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();

    final prefs = await tester.runAsync(AppPrefs.load);
    expect(prefs!.themeMode, ThemeMode.dark);
  });

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

    await tester.scrollUntilVisible(find.text('Sổ tay ấm'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Sổ tay ấm'));
    await tester.pumpAndSettle();

    final prefs = await tester.runAsync(AppPrefs.load);
    expect(prefs!.themeStyle, AppThemeStyle.warm);
  });
}
