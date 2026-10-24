import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo de rayos rojo / amarillo / naranja que salen de un punto (Quiz).
class SunburstBackground extends StatelessWidget {
  /// Centro de los rayos (fracción del ancho/alto).
  final Alignment center;

  /// Número de rayos de cada color (el total es el triple).
  final int rays;
  const SunburstBackground({super.key, this.center = const Alignment(0, -0.1), this.rays = 10});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _SunburstPainter(center, rays), size: Size.infinite),
    );
  }
}

class _SunburstPainter extends CustomPainter {
  final Alignment center;
  final int rays;
  const _SunburstPainter(this.center, this.rays);

  static const _colors = [Color(0xFFFFC400), Color(0xFFE53935), Color(0xFFFFE000)];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset((center.x + 1) / 2 * size.width, (center.y + 1) / 2 * size.height);
    canvas.drawRect(Offset.zero & size, Paint()..color = _colors[0]);
    final n = rays * 3;
    final step = 2 * math.pi / n;
    final r = size.longestSide * 1.6;
    for (var i = 0; i < n; i++) {
      final color = _colors[i % 3];
      if (i % 3 == 0) continue; // el color base ya está pintado
      final a0 = i * step - math.pi / 2;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a0) * r, c.dy + math.sin(a0) * r)
        ..lineTo(c.dx + math.cos(a0 + step) * r, c.dy + math.sin(a0 + step) * r)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter old) => old.center != center || old.rays != rays;
}
