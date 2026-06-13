import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/widgets/budget_donut.dart';

void main() {
  testWidgets('renders the centre child and exposes ratio/color', (tester) async {
    const red = Color(0xFFC04848);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: BudgetDonut(ratio: 1.39, color: red, center: Text('139%')),
        ),
      ),
    ));
    expect(find.text('139%'), findsOneWidget);
    final donut = tester.widget<BudgetDonut>(find.byType(BudgetDonut));
    expect(donut.ratio, 1.39);
    expect(donut.color, red);
  });
}
