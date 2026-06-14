import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/data/app_lock_service.dart';
import 'package:moneynote/features/settings/settings_screen.dart';
import 'package:moneynote/state/providers.dart';

class _FakeLock extends AppLockService {
  _FakeLock({this.supported = true, this.authed = true});
  final bool supported;
  bool authed;
  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<bool> authenticate() async => authed;
}

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pump(WidgetTester tester, AppLockService svc) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [appLockServiceProvider.overrideWithValue(svc)],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('enabling authenticates then persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await pump(tester, _FakeLock(supported: true, authed: true));

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(AppPrefs.load))!.appLockEnabled, true);
  });

  testWidgets('failed confirm leaves it off', (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await pump(tester, _FakeLock(supported: true, authed: false));

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(AppPrefs.load))!.appLockEnabled, false);
  });

  testWidgets('unsupported device disables the switch + shows hint',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await pump(tester, _FakeLock(supported: false));

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.textContaining('Thiết bị chưa cài'), findsOneWidget);
  });
}
