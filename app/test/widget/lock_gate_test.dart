import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneynote/data/app_lock_service.dart';
import 'package:moneynote/features/lock/lock_gate.dart';
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

Widget _app(AppLockService svc) => ProviderScope(
      overrides: [appLockServiceProvider.overrideWithValue(svc)],
      child: const MaterialApp(home: LockGate(child: Text('HOME'))),
    );

void main() {
  testWidgets('enabled + auth fails → LockScreen shown, child hidden',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
    await tester.pumpWidget(_app(_FakeLock(authed: false)));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('enabled + auth succeeds → child shown', (tester) async {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
    await tester.pumpWidget(_app(_FakeLock(authed: true)));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('disabled → child shown immediately, never locks', (tester) async {
    SharedPreferences.setMockInitialValues({}); // appLockEnabled defaults false
    await tester.pumpWidget(_app(_FakeLock(authed: false)));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
  });

  testWidgets('re-locks on background then resume', (tester) async {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
    final fake = _FakeLock(authed: true);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget); // unlocked after cold-launch auth

    fake.authed = false; // so the post-resume auto-auth won't immediately unlock
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });
}
