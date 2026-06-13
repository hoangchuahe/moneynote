import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A progress ring (the gallery's budget donut): a full track circle + a filled
/// arc from the top. [ratio] may exceed 1 when over budget — the arc clamps to a
/// full ring, while the [center] (built by the caller) can still read e.g. "139%".
class BudgetDonut extends StatelessWidget {
  const BudgetDonut({
    super.key,
    required this.ratio,
    required this.color,
    required this.center,
    this.size = 168,
    this.stroke = 20,
  });

  final double ratio;
  final Color color;
  final Widget center;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          ratio: ratio.clamp(0.0, 1.0),
          color: color,
          track: Theme.of(context).colorScheme.outlineVariant,
          stroke: stroke,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.ratio,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double ratio;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, base..color = track);
    if (ratio > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top
        2 * math.pi * ratio,
        false,
        base
          ..color = color
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.ratio != ratio ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
