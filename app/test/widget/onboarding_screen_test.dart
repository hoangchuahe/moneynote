import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/features/onboarding/onboarding_screen.dart';

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('pages through to Bắt đầu, which calls onDone', (tester) async {
    bigView(tester);
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onDone: () => done = true),
    ));
    await tester.pumpAndSettle();

    // First page: headline + "Tiếp" + "Bỏ qua".
    expect(find.text('Ghi chi tiêu trong 3 giây'), findsOneWidget);
    expect(find.text('Tiếp'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsOneWidget);

    // Advance to the last page (3 pages → 2 taps).
    await tester.tap(find.byKey(const Key('onboardNext')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboardNext')));
    await tester.pumpAndSettle();

    // Last page: the button becomes "Bắt đầu".
    expect(find.text('Bắt đầu'), findsOneWidget);
    expect(done, false);

    await tester.tap(find.byKey(const Key('onboardNext')));
    await tester.pumpAndSettle();
    expect(done, true);
  });

  testWidgets('Bỏ qua calls onDone immediately', (tester) async {
    bigView(tester);
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onDone: () => done = true),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboardSkip')));
    await tester.pumpAndSettle();
    expect(done, true);
  });
}
