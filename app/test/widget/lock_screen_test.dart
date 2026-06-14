import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/data/app_lock_service.dart';
import 'package:moneynote/features/lock/lock_screen.dart';
import 'package:moneynote/state/providers.dart';

class _FakeLock extends AppLockService {
  _FakeLock({this.authed = true});
  bool authed;
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<bool> authenticate() async => authed;
}

void main() {
  testWidgets('auto-authenticates on show; success calls onUnlocked',
      (tester) async {
    var unlocked = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [appLockServiceProvider.overrideWithValue(_FakeLock(authed: true))],
      child: MaterialApp(home: LockScreen(onUnlocked: () => unlocked = true)),
    ));
    await tester.pumpAndSettle();
    expect(unlocked, true);
  });

  testWidgets('failure stays locked; retry button re-authenticates',
      (tester) async {
    final fake = _FakeLock(authed: false);
    var unlocked = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [appLockServiceProvider.overrideWithValue(fake)],
      child: MaterialApp(home: LockScreen(onUnlocked: () => unlocked = true)),
    ));
    await tester.pumpAndSettle();
    expect(unlocked, false);
    expect(find.text('Mở khoá'), findsOneWidget);

    fake.authed = true;
    await tester.tap(find.byKey(const Key('unlockBtn')));
    await tester.pumpAndSettle();
    expect(unlocked, true);
  });
}
