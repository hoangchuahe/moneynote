import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/features/reports/widgets/expense_pie_card.dart';

Widget host(Widget child) => MaterialApp(
      theme: buildTheme(AppThemeStyle.classic, Brightness.light),
      home: Scaffold(body: child),
    );

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('ExpensePieCard', () {
    testWidgets('renders legend with names, amounts and percents', (tester) async {
      bigView(tester);
      await tester.pumpWidget(host(const ExpensePieCard(slices: [
        CategorySlice(label: 'Ăn uống', color: Color(0xFFEF5350), total: 600000),
        CategorySlice(label: 'Đi lại', color: Color(0xFF42A5F5), total: 400000),
      ])));
      await tester.pump();

      expect(find.text('Chi theo danh mục'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('600.000 ₫'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('1.000.000 ₫'), findsOneWidget); // tổng cạnh tiêu đề
    });

    testWidgets('shows empty state when no slices', (tester) async {
      bigView(tester);
      await tester.pumpWidget(host(const ExpensePieCard(slices: [])));
      await tester.pump();
      expect(find.text('Chưa có chi tiêu tháng này'), findsOneWidget);
    });
  });
}
