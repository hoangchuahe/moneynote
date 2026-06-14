import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/features/reports/widgets/category_donut.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildTheme(AppThemeStyle.classic, Brightness.light),
        home: Scaffold(body: child),
      );

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows "Tổng chi" + total over the donut', (tester) async {
    bigView(tester);
    await tester.pumpWidget(host(const CategoryDonut(slices: [
      CategorySlice(label: 'Ăn uống', color: Color(0xFFEF5350), total: 600000),
      CategorySlice(label: 'Đi lại', color: Color(0xFF42A5F5), total: 400000),
    ])));
    await tester.pump();
    expect(find.text('Tổng chi'), findsOneWidget);
    expect(find.text('1.000.000 ₫'), findsOneWidget);
  });

  testWidgets('empty slices → empty state', (tester) async {
    bigView(tester);
    await tester.pumpWidget(host(const CategoryDonut(slices: [])));
    await tester.pump();
    expect(find.text('Chưa có chi tiêu kỳ này'), findsOneWidget);
  });
}
