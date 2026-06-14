import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/features/onboarding/onboarding_gate.dart';
import 'package:moneynote/features/onboarding/onboarding_screen.dart';

Widget _app() => const ProviderScope(
      child: MaterialApp(home: OnboardingGate(child: Text('HOME'))),
    );

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('not seen → shows OnboardingScreen, hides child', (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('seen → shows child, no OnboardingScreen', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    bigView(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('finishing persists the flag and reveals the child',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    bigView(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboardSkip')));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
    expect((await tester.runAsync(AppPrefs.load))!.onboardingSeen, true);
  });
}
