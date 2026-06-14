import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/features/settings/widgets/setting_picker.dart';

void main() {
  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows options, marks current, returns the tapped value',
      (tester) async {
    bigView(tester);
    ThemeMode? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showSettingPicker<ThemeMode>(
                  ctx,
                  title: 'Giao diện',
                  options: const [
                    ('Theo hệ thống', ThemeMode.system),
                    ('Sáng', ThemeMode.light),
                    ('Tối', ThemeMode.dark),
                  ],
                  current: ThemeMode.system,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Theo hệ thống'), findsOneWidget);
    expect(find.text('Sáng'), findsOneWidget);
    expect(find.text('Tối'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget); // only current

    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();
    expect(result, ThemeMode.dark);
  });

  testWidgets('returns null when dismissed', (tester) async {
    bigView(tester);
    ThemeMode? result = ThemeMode.light;
    var called = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () async {
                called = true;
                result = await showSettingPicker<ThemeMode>(
                  ctx,
                  title: 'Giao diện',
                  options: const [('Sáng', ThemeMode.light)],
                  current: ThemeMode.light,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 40)); // tap scrim above the sheet
    await tester.pumpAndSettle();

    expect(called, true);
    expect(result, isNull);
  });
}
