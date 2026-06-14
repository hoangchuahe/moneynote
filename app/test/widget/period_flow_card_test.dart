import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/prefs.dart';
import 'package:moneynote/core/theme.dart';
import 'package:moneynote/domain/report_period.dart';
import 'package:moneynote/domain/reports.dart';
import 'package:moneynote/features/reports/widgets/period_flow_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildTheme(AppThemeStyle.classic, Brightness.light),
        home: Scaffold(body: child),
      );

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('renders Thu/Chi legend and month labels', (tester) async {
    bigView(tester);
    final flows = [
      for (var m = 1; m <= 6; m++)
        PeriodFlow(
            ReportPeriod.month(DateTime(2026, m, 1)), 1000000 * m, 500000 * m),
    ];
    await tester.pumpWidget(host(PeriodFlowCard(flows: flows)));
    await tester.pump();
    expect(find.text('Thu / chi · 6 tháng'), findsOneWidget);
    expect(find.text('Thu'), findsOneWidget);
    expect(find.text('Chi'), findsOneWidget);
    expect(find.text('T1'), findsOneWidget);
    expect(find.text('T6'), findsOneWidget);
  });

  testWidgets('year granularity relabels header + bars', (tester) async {
    bigView(tester);
    final flows = [
      for (var y = 2021; y <= 2026; y++)
        PeriodFlow(ReportPeriod.year(DateTime(y, 1, 1)), 0, 1000000),
    ];
    await tester.pumpWidget(host(PeriodFlowCard(flows: flows)));
    await tester.pump();
    expect(find.text('Thu / chi · 6 năm'), findsOneWidget);
    expect(find.text('2021'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
  });

  testWidgets('all-zero → empty state', (tester) async {
    bigView(tester);
    final flows = [
      for (var m = 1; m <= 6; m++)
        PeriodFlow(ReportPeriod.month(DateTime(2026, m, 1)), 0, 0),
    ];
    await tester.pumpWidget(host(PeriodFlowCard(flows: flows)));
    await tester.pump();
    expect(find.text('Chưa có thu chi nào'), findsOneWidget);
  });
}
