import 'package:flutter/material.dart';

import 'poke_widgets.dart';

/// Ilustraciones de los modos de batalla, dibujadas por código (sin imágenes).

/// Consola portátil morada (modo Normal, vista GBA clásica).
class GbaIllustration extends StatelessWidget {
  final double width;
  const GbaIllustration({super.key, this.width = 112});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(width, width * 0.66), painter: const _GbaPainter());
}

class _GbaPainter extends CustomPainter {
  const _GbaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outline = Paint()
      ..color = const Color(0xFF1A1440)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeJoin = StrokeJoin.round;
    // Cuerpo.
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.02, h * 0.1, w * 0.96, h * 0.82), Radius.circular(h * 0.28));
    canvas.drawRRect(body.shift(Offset(0, h * 0.04)), Paint()..color = Colors.black38);
    canvas.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8B7FE8), Color(0xFF4B3FB0)]).createShader(Offset.zero & size));
    canvas.drawRRect(body, outline);
    // Marco y pantalla.
    final bezel = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.28, h * 0.2, w * 0.44, h * 0.56), Radius.circular(h * 0.07));
    canvas.drawRRect(bezel, Paint()..color = const Color(0xFF3A3A55));
    canvas.drawRRect(bezel, outline);
    final screen = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.31, h * 0.26, w * 0.38, h * 0.44), Radius.circular(h * 0.04));
    canvas.drawRRect(screen, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9FD8F5), Color(0xFF4A8FD0)]).createShader(screen.outerRect));
    canvas.drawRRect(screen, Paint()..color = Colors.white.withValues(alpha: 0.18));
    // Cruceta.
    final pad = Paint()..color = const Color(0xFF2A2250);
    final dc = Offset(w * 0.15, h * 0.48);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: dc, width: w * 0.1, height: h * 0.07), const Radius.circular(2)), pad);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: dc, width: h * 0.07, height: w * 0.1 * 0.75), const Radius.circular(2)), pad);
    // Botones A y B.
    canvas.drawCircle(Offset(w * 0.86, h * 0.42), w * 0.04, Paint()..color = const Color(0xFFD7CCF5));
    canvas.drawCircle(Offset(w * 0.78, h * 0.55), w * 0.04, Paint()..color = const Color(0xFFD7CCF5));
    canvas.drawCircle(Offset(w * 0.86, h * 0.42), w * 0.04, outline..strokeWidth = w * 0.015);
    canvas.drawCircle(Offset(w * 0.78, h * 0.55), w * 0.04, outline);
    // Brillo superior.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.13, w * 0.8, h * 0.05), Radius.circular(h * 0.03)),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Arena isométrica con montañas (modo 2.5D).
class ArenaIllustration extends StatelessWidget {
  final double width;
  const ArenaIllustration({super.key, this.width = 112});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(width, width * 0.85), painter: const _ArenaPainter());
}

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..color = const Color(0xFF1B2A1B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeJoin = StrokeJoin.round;
    // Montañas al fondo.
    Path mountain(double x, double base, double mw, double mh) => Path()
      ..moveTo(x, base)
      ..lineTo(x + mw / 2, base - mh)
      ..lineTo(x + mw, base)
      ..close();
    final m1 = mountain(w * 0.05, h * 0.5, w * 0.45, h * 0.42);
    final m2 = mountain(w * 0.38, h * 0.45, w * 0.5, h * 0.4);
    for (final m in [m1, m2]) {
      canvas.drawPath(m, Paint()..color = const Color(0xFF8D8D8D));
      canvas.drawPath(m, line);
    }
    // Nieve de las cumbres.
    for (final peak in [Offset(w * 0.275, h * 0.08), Offset(w * 0.63, h * 0.05)]) {
      canvas.drawPath(
        Path()
          ..moveTo(peak.dx, peak.dy)
          ..lineTo(peak.dx + w * 0.07, peak.dy + h * 0.1)
          ..lineTo(peak.dx - w * 0.07, peak.dy + h * 0.1)
          ..close(),
        Paint()..color = Colors.white,
      );
    }
    // Losa isométrica: cara superior (rombo) y laterales.
    final cx = w * 0.5;
    final top = h * 0.38;
    final half = w * 0.46;
    final dy = h * 0.2;
    final thick = h * 0.2;
    final topFace = Path()
      ..moveTo(cx, top)
      ..lineTo(cx + half, top + dy)
      ..lineTo(cx, top + 2 * dy)
      ..lineTo(cx - half, top + dy)
      ..close();
    final left = Path()
      ..moveTo(cx - half, top + dy)
      ..lineTo(cx, top + 2 * dy)
      ..lineTo(cx, top + 2 * dy + thick)
      ..lineTo(cx - half, top + dy + thick)
      ..close();
    final right = Path()
      ..moveTo(cx + half, top + dy)
      ..lineTo(cx, top + 2 * dy)
      ..lineTo(cx, top + 2 * dy + thick)
      ..lineTo(cx + half, top + dy + thick)
      ..close();
    canvas.drawPath(left, Paint()..color = const Color(0xFF7A5230));
    canvas.drawPath(right, Paint()..color = const Color(0xFF5E3D22));
    canvas.drawPath(topFace, Paint()..color = const Color(0xFF6CC24A));
    // Campo de batalla (rombo más pequeño, arena).
    final f = 0.62;
    final inner = Path()
      ..moveTo(cx, top + dy * (1 - f))
      ..lineTo(cx + half * f, top + dy)
      ..lineTo(cx, top + dy * (1 + f))
      ..lineTo(cx - half * f, top + dy)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFF1DDB0));
    canvas.drawPath(inner, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = w * 0.02);
    for (final p in [topFace, left, right]) {
      canvas.drawPath(p, line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Wifi con una Pokébola (modo Online).
class OnlineIllustration extends StatelessWidget {
  final double width;
  const OnlineIllustration({super.key, this.width = 112});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.85,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: const _WifiPainter())),
          Positioned(right: width * 0.02, bottom: 0, child: PokeBallIcon(size: width * 0.42)),
        ],
      ),
    );
  }
}

class _WifiPainter extends CustomPainter {
  const _WifiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.3, h * 0.82);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.1
      ..color = const Color(0xFF1E88E5);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.145
      ..color = const Color(0xFF0D2B5E);
    for (final r in [w * 0.34, w * 0.62, w * 0.9]) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(rect, -1.5708 * 1.0 - 0.0, 1.5708, false, edge);
      canvas.drawArc(rect, -1.5708 * 1.0 - 0.0, 1.5708, false, arc);
    }
    canvas.drawCircle(c, w * 0.09, Paint()..color = const Color(0xFF0D2B5E));
    canvas.drawCircle(c, w * 0.065, Paint()..color = const Color(0xFF1E88E5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
