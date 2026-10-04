import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Paint-only progress: callers supply the authoritative ratio and status colors.
/// Only the painted arc is capped; the child may display an uncapped percentage.
class AppCircularProgress extends StatelessWidget {
  const AppCircularProgress({super.key, required this.value,
    required this.gradientColors, required this.child, required this.semanticLabel});

  final double value;
  final List<Color> gradientColors;
  final Widget child;
  final String semanticLabel;

  double get paintedValue => value.isFinite ? value.clamp(0.0, 1.0) : 0;

  @override
  Widget build(BuildContext context) => Semantics(label: semanticLabel,
    excludeSemantics: true,
    child: SizedBox.square(dimension: 108,
      child: CustomPaint(painter: _RingPainter(paintedValue, gradientColors,
        context.appTokens.colors.elevatedSurface),
        child: Center(child: Padding(padding: const EdgeInsets.all(16),
          child: FittedBox(fit: BoxFit.scaleDown, child: child))),
      )),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.colors, this.track);
  final double value;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke
      ..strokeCap = StrokeCap.round..color = track;
    canvas.drawOval(rect, paint);
    if (value <= 0) return;
    paint.color = Colors.white;
    paint.shader = SweepGradient(colors: colors,
      transform: const GradientRotation(-math.pi / 2)).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.colors != colors || old.track != track;
}
