import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/large_title_header.dart';

void main() {
  testWidgets('renders the title at 32/w600 and fires action callbacks',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(AppThemeStyle.classic, Brightness.light),
      home: Scaffold(
        body: LargeTitleHeader(
          title: 'Tổng quan',
          actions: [
            IconButton(
              key: const Key('act'),
              icon: const Icon(Icons.settings),
              onPressed: () => tapped = true,
            ),
          ],
        ),
      ),
    ));

    final text = tester.widget<Text>(find.text('Tổng quan'));
    expect(text.style?.fontSize, 32);
    expect(text.style?.fontWeight, FontWeight.w600);

    await tester.tap(find.byKey(const Key('act')));
    expect(tapped, isTrue);
  });

  testWidgets('builds under a dark variant without exception', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(AppThemeStyle.warm, Brightness.dark),
      home: const Scaffold(body: LargeTitleHeader(title: 'Ví')),
    ));
    expect(find.text('Ví'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
