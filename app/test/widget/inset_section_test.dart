import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/core/widgets/inset_section.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildTheme(AppThemeStyle.classic, Brightness.light),
        home: Scaffold(body: child),
      );

  testWidgets('renders header, footer, rows; onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(InsetSection(
      header: 'Ghi chú',
      footer: 'Chân trang',
      children: [
        const InsetRow(title: 'Hàng 1', value: 'A'),
        InsetRow(title: 'Hàng 2', onTap: () => tapped = true),
      ],
    )));
    expect(find.text('Ghi chú'), findsOneWidget);
    expect(find.text('Chân trang'), findsOneWidget);
    expect(find.text('Hàng 1'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    await tester.tap(find.text('Hàng 2'));
    expect(tapped, isTrue);
  });

  testWidgets('destructive row paints its title in the expense colour',
      (tester) async {
    late Color expected;
    await tester.pumpWidget(host(Builder(builder: (context) {
      expected = moneyColorsOf(context).expense;
      return const InsetSection(children: [
        InsetRow(title: 'Xoá', destructive: true),
      ]);
    })));
    final text = tester.widget<Text>(find.text('Xoá'));
    expect(text.style?.color, expected);
  });

  testWidgets('wrap:true row is not single-line ellipsized', (tester) async {
    await tester.pumpWidget(host(const InsetSection(children: [
      InsetRow(title: 'một ghi chú khá là dài dài dài', wrap: true),
    ])));
    final text = tester.widget<Text>(find.text('một ghi chú khá là dài dài dài'));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
  });
}
