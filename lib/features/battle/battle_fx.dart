import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Formas de proyectil por tipo de movimiento (puro y testeable).
enum MoveShape { flame, drop, bolt, leaf, shard, rock, wind, orb, star }

/// Agrupa los 18 tipos en 9 formas dibujadas por código (sin assets).
MoveShape moveShapeFor(String type) {
  switch (type.toLowerCase()) {
    case 'fire':
      return MoveShape.flame;
    case 'water':
      return MoveShape.drop;
    case 'electric':
      return MoveShape.bolt;
    case 'grass':
    case 'bug':
      return MoveShape.leaf;
    case 'ice':
      return MoveShape.shard;
    case 'ground':
    case 'rock':
    case 'steel':
      return MoveShape.rock;
    case 'flying':
      return MoveShape.wind;
    case 'psychic':
    case 'ghost':
    case 'dark':
    case 'dragon':
    case 'fairy':
    case 'poison':
      return MoveShape.orb;
    default:
      return MoveShape.star; // normal, fighting, stellar
  }
}

/// Proyectil con forma según el tipo del poder + núcleo blanco y estela.
/// [progress] 0..1 del vuelo (rota las formas rígidas).
class MoveProjectile extends StatelessWidget {
  final String type;
  final Color color;
  final double progress;
  final double size;
  const MoveProjectile({
    super.key,
    required this.type,
    required this.color,
    this.progress = 0.5,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final shape = moveShapeFor(type);
    final spins = shape == MoveShape.star ||
        shape == MoveShape.shard ||
        shape == MoveShape.rock ||
        shape == MoveShape.leaf;
    return SizedBox(
      width: size + 16,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Estela.
          Container(
            width: size + 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Transform.rotate(
            angle: spins ? progress * math.pi * 2 : 0.0,
            child: CustomPaint(
              size: Size(size, size),
              painter: _MoveShapePainter(shape, color),
            ),
          ),
          // Núcleo blanco.
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveShapePainter extends CustomPainter {
  final MoveShape shape;
  final Color color;
  _MoveShapePainter(this.shape, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dark = Paint()
      ..color = Color.lerp(color, Colors.black, 0.35)!
      ..style = PaintingStyle.fill;
    final light = Paint()
      ..color = Color.lerp(color, Colors.white, 0.45)!
      ..style = PaintingStyle.fill;
    // Halo exterior.
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.25));
    switch (shape) {
      case MoveShape.star:
        canvas.drawPath(_star(c, r, 5), fill);
        canvas.drawPath(_star(c, r * 0.55, 5), light);
        canvas.drawCircle(c, r * 0.18, Paint()..color = Colors.white);
      case MoveShape.flame:
        // Llama de 3 lenguas: externa oscura, media y núcleo claro.
        canvas.drawPath(_flame(c, r, 1.0), dark);
        canvas.drawPath(_flame(c, r * 0.72, 0.9), fill);
        canvas.drawPath(_flame(c, r * 0.45, 0.8), light);
        canvas.drawCircle(
            Offset(c.dx, c.dy + r * 0.35), r * 0.16, Paint()..color = Colors.white);
      case MoveShape.drop:
        // Gota con brillo lateral y burbuja interna.
        final p = Path()
          ..moveTo(c.dx, c.dy - r)
          ..quadraticBezierTo(
              c.dx + r * 0.85, c.dy + r * 0.1, c.dx, c.dy + r * 0.9)
          ..quadraticBezierTo(
              c.dx - r * 0.85, c.dy + r * 0.1, c.dx, c.dy - r)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(_flame(Offset(c.dx, c.dy + r * 0.15), r * 0.5, 1.0), light);
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx - r * 0.3, c.dy - r * 0.25),
              width: r * 0.28,
              height: r * 0.45),
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      case MoveShape.bolt:
        // Rayo con halo eléctrico y núcleo blanco.
        canvas.drawCircle(c, r * 0.9,
            Paint()..color = color.withValues(alpha: 0.35));
        final p = Path()
          ..moveTo(c.dx + r * 0.25, c.dy - r)
          ..lineTo(c.dx - r * 0.45, c.dy + r * 0.15)
          ..lineTo(c.dx - r * 0.02, c.dy + r * 0.15)
          ..lineTo(c.dx - r * 0.25, c.dy + r)
          ..lineTo(c.dx + r * 0.45, c.dy - r * 0.15)
          ..lineTo(c.dx + r * 0.02, c.dy - r * 0.15)
          ..close();
        canvas.drawPath(p, fill);
        final q = Path()
          ..moveTo(c.dx + r * 0.12, c.dy - r * 0.55)
          ..lineTo(c.dx - r * 0.2, c.dy + r * 0.1)
          ..lineTo(c.dx - r * 0.02, c.dy + r * 0.1)
          ..lineTo(c.dx - r * 0.12, c.dy + r * 0.55)
          ..lineTo(c.dx + r * 0.2, c.dy - r * 0.1)
          ..lineTo(c.dx + r * 0.02, c.dy - r * 0.1)
          ..close();
        canvas.drawPath(q, Paint()..color = Colors.white);
      case MoveShape.leaf:
        // Hoja bicolor con nervadura.
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-0.6);
        canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: r * 1.1, height: r * 1.7),
            fill);
        canvas.drawOval(
            Rect.fromCenter(
                center: const Offset(-2, -2), width: r * 0.7, height: r * 1.1),
            light);
        canvas.drawLine(Offset(0, -r * 0.8), Offset(0, r * 0.8),
            Paint()..color = dark.color..style = PaintingStyle.stroke..strokeWidth = 2);
        canvas.restore();
        canvas.drawCircle(c, r * 0.16, Paint()..color = Colors.white);
      case MoveShape.shard:
        // Cristal facetado con brillo.
        final p = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.55, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r * 0.55, c.dy)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r),
            Paint()..color = Colors.white.withValues(alpha: 0.8)..strokeWidth = 2);
        canvas.drawLine(Offset(c.dx - r * 0.55, c.dy),
            Offset(c.dx + r * 0.55, c.dy),
            Paint()..color = dark.color..strokeWidth = 1.5);
        canvas.drawCircle(Offset(c.dx - r * 0.15, c.dy - r * 0.3), r * 0.1,
            Paint()..color = Colors.white);
      case MoveShape.rock:
        // Roca con facetas oscuras y punto de luz.
        final p = Path()
          ..moveTo(c.dx - r * 0.7, c.dy - r * 0.5)
          ..lineTo(c.dx + r * 0.1, c.dy - r * 0.9)
          ..lineTo(c.dx + r * 0.8, c.dy - r * 0.1)
          ..lineTo(c.dx + r * 0.5, c.dy + r * 0.8)
          ..lineTo(c.dx - r * 0.6, c.dy + r * 0.6)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawLine(Offset(c.dx - r * 0.1, c.dy - r * 0.7),
            Offset(c.dx + r * 0.3, c.dy + r * 0.5),
            Paint()..color = dark.color..strokeWidth = 2.5);
        canvas.drawCircle(Offset(c.dx - r * 0.25, c.dy - r * 0.35), r * 0.12,
            Paint()..color = Colors.white.withValues(alpha: 0.9));
      case MoveShape.wind:
        // Remolino: 3 arcos + estelas + núcleo.
        final stroke = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        for (var k = -1; k <= 1; k++) {
          canvas.drawArc(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy + k * 9),
                width: r * 1.7,
                height: r * 0.9),
            -0.9,
            1.8,
            false,
            stroke,
          );
        }
        canvas.drawCircle(c, r * 0.35, light);
        canvas.drawCircle(c, r * 0.35,
            Paint()..color = Colors.white.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
        canvas.drawCircle(Offset(c.dx - r * 0.8, c.dy - r * 0.5), 2,
            Paint()..color = color.withValues(alpha: 0.7));
        canvas.drawCircle(Offset(c.dx + r * 0.8, c.dy + r * 0.5), 2,
            Paint()..color = color.withValues(alpha: 0.7));
      case MoveShape.orb:
        // Orbe de energía: núcleo + anillo + satélite.
        canvas.drawCircle(c, r * 0.75, fill);
        canvas.drawCircle(c, r * 0.45, light);
        canvas.drawCircle(
            c,
            r * 0.95,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
        canvas.drawCircle(Offset(c.dx + r * 0.7, c.dy - r * 0.7), r * 0.14,
            Paint()..color = Colors.white);
    }
  }

  /// Lengua de llama centrada en [c], radio [r] y altura [h].
  Path _flame(Offset c, double r, double h) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r * h)
      ..quadraticBezierTo(
          c.dx + r * 0.9, c.dy - r * 0.2, c.dx + r * 0.45, c.dy + r * 0.6)
      ..quadraticBezierTo(c.dx, c.dy + r, c.dx - r * 0.45, c.dy + r * 0.6)
      ..quadraticBezierTo(
          c.dx - r * 0.9, c.dy - r * 0.2, c.dx, c.dy - r * h)
      ..close();
    return p;
  }

  Path _star(Offset c, double r, int points) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / points;
      final pt = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant _MoveShapePainter old) =>
      old.shape != shape || old.color != color;
}

/// Estallido al impactar: anillo + partículas + destello.
/// [t] 0..1 del impacto (0.5..0.9 de la animación de ataque).
class ImpactBurst extends StatelessWidget {
  final Color color;
  final double t;
  final double size;
  const ImpactBurst({
    super.key,
    required this.color,
    required this.t,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final v = t.clamp(0.0, 1.0);
    return Opacity(
      opacity: 1 - v * 0.85,
      child: CustomPaint(
        size: Size(size, size),
        painter: _BurstPainter(color, v),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final Color color;
  final double t;
  _BurstPainter(this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // Destello central.
    canvas.drawCircle(
        c,
        6 + 14 * (1 - t),
        Paint()..color = Colors.white.withValues(alpha: 0.9 * (1 - t)));
    canvas.drawCircle(
        c,
        10 + 10 * (1 - t),
        Paint()..color = color.withValues(alpha: 0.85 * (1 - t)));
    // Anillo expansivo.
    canvas.drawCircle(
        c,
        12 + t * 30,
        Paint()
          ..color = color.withValues(alpha: 0.9 * (1 - t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - t) + 1.5);
    // Partículas radiales.
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      final d = 10 + t * 32;
      final pt = Offset(c.dx + d * math.cos(a), c.dy + d * math.sin(a));
      canvas.drawCircle(
          pt,
          4 * (1 - t) + 1.2,
          Paint()..color = color.withValues(alpha: 0.9 * (1 - t)));
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.t != t || old.color != color;
}

/// Bocadillo de diálogo sobre la cabeza del luchador (sale de su boca).
/// Se muestra durante el ataque: el atacante dice su poder,
/// el defensor reacciona al impacto.
class SpeechBubble extends StatelessWidget {
  final String text;
  final Color color;
  const SpeechBubble({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black87),
          ),
        ),
        CustomPaint(
          size: const Size(14, 8),
          painter: _TailPainter(color),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) =>
      old.color != color;
}

/// Reacción del defensor según el resultado del golpe.
String defenderReaction(
    {required bool miss,
    required bool crit,
    required double effectiveness}) {
  if (miss) return '¡Fallo!';
  if (effectiveness == 0.0) return '¡Ni cosquillas!';
  if (crit) return '¡Ay, crítico!';
  if (effectiveness >= 2.0) return '¡Súper efectivo!';
  if (effectiveness < 1.0) return '¡Aguanto!';
  return '¡Toma eso!';
}
