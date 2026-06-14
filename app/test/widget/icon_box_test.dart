import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneynote/core/category_visuals.dart';

void main() {
  testWidgets('IconBox renders an Icon with the given IconData', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: IconBox(
              icon: Icons.star,
              background: Color(0xFFE3F2FD),
              foreground: Color(0xFF1565C0),
            ),
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.star);
    expect(icon.color, const Color(0xFF1565C0));
    expect(icon.size, 18.0);
  });

  testWidgets('IconBox has 36×36 size by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: IconBox(
              icon: Icons.star,
              background: Color(0xFFE3F2FD),
              foreground: Color(0xFF1565C0),
            ),
          ),
        ),
      ),
    );

    // The container is 36×36
    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.maxWidth, 36.0);
    expect(container.constraints?.maxHeight, 36.0);
  });

  testWidgets('IconBox applies background color and radius 12', (tester) async {
    const bg = Color(0xFFE3F2FD);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: IconBox(
              icon: Icons.swap_horiz,
              background: bg,
              foreground: Color(0xFF1565C0),
            ),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, bg);
    expect(decoration.borderRadius, BorderRadius.circular(12));
  });

  testWidgets('IconBox respects custom size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: IconBox(
              icon: Icons.star,
              background: Color(0xFFE3F2FD),
              foreground: Color(0xFF1565C0),
              size: 48,
            ),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.maxWidth, 48.0);
    expect(container.constraints?.maxHeight, 48.0);

    final icon = tester.widget<Icon>(find.byType(Icon));
    // icon size is size * 0.5
    expect(icon.size, 24.0);
  });
}
