import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/features/home/widgets/floating_pill_nav.dart';

void main() {
  Widget host({
    required int selected,
    ValueChanged<int>? onSelect,
    VoidCallback? onAdd,
    AppThemeStyle style = AppThemeStyle.classic,
    Brightness brightness = Brightness.light,
  }) =>
      MaterialApp(
        theme: buildTheme(style, brightness),
        home: Scaffold(
          body: Center(
            child: FloatingPillNav(
              selectedIndex: selected,
              onSelect: onSelect ?? (_) {},
              onAdd: onAdd ?? () {},
            ),
          ),
        ),
      );

  testWidgets('renders 4 tabs (selected filled, others outlined) + add',
      (tester) async {
    await tester.pumpWidget(host(selected: 0));
    expect(find.byIcon(Icons.pie_chart), findsOneWidget); // tab0 selected → filled
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget); // tab1
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget); // center action
  });

  testWidgets(
      'tapping each tab calls onSelect with its page index (incl. the cell after +)',
      (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(host(selected: 0, onSelect: taps.add));
    await tester.tap(find.byKey(const Key('navTab_1')));
    await tester.tap(find.byKey(const Key('navTab_2'))); // the cell AFTER the +
    await tester.tap(find.byKey(const Key('navTab_3')));
    expect(taps, [1, 2, 3]);
  });

  testWidgets('center + calls onAdd and never onSelect', (tester) async {
    final taps = <int>[];
    var added = false;
    await tester.pumpWidget(
        host(selected: 0, onSelect: taps.add, onAdd: () => added = true));
    await tester.tap(find.byKey(const Key('navAdd')));
    expect(added, isTrue);
    expect(taps, isEmpty);
  });

  testWidgets('tap at the inner edge of the Ví cell selects Ví, not add',
      (tester) async {
    final taps = <int>[];
    var added = false;
    await tester.pumpWidget(
        host(selected: 0, onSelect: taps.add, onAdd: () => added = true));
    final topLeft = tester.getTopLeft(find.byKey(const Key('navTab_2')));
    await tester.tapAt(topLeft + const Offset(3, 25));
    expect(taps, [2]);
    expect(added, isFalse);
  });

  testWidgets('selected cell paints primaryContainer under classic-light AND warm-dark',
      (tester) async {
    for (final (style, brightness) in [
      (AppThemeStyle.classic, Brightness.light),
      (AppThemeStyle.warm, Brightness.dark),
    ]) {
      await tester.pumpWidget(host(selected: 0, style: style, brightness: brightness));
      await tester.pumpAndSettle(); // MaterialApp animates theme changes
      final box = tester.widget<Container>(find.byKey(const Key('navTab_0')));
      final color = (box.decoration as BoxDecoration).color;
      expect(color, buildTheme(style, brightness).colorScheme.primaryContainer);
    }
  });
}
