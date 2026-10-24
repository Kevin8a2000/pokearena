import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gba/gba_sprites.dart';

/// Efectos extra de la vista GBA (aditivos: `battle_fx.dart` no cambia porque
/// también lo usan la vista moderna y la arena 2.5D).

/// Sacudida de pantalla al recibir un golpe.
class ScreenShake {
  ScreenShake._();

  /// Amplitud en px: crece con el daño (fracción de los PS del defensor), el
  /// crítico y la súper efectividad; baja si no es muy eficaz; 0 si falla.
  static double amplitude({
    required int damage,
    required int defenderMaxHp,
    required bool crit,
    required double effectiveness,
    required bool miss,
  }) {
    if (miss || damage <= 0) return 0;
    final frac = defenderMaxHp <= 0 ? 0.0 : (damage / defenderMaxHp).clamp(0.0, 1.0).toDouble();
    var a = 2 + 8 * frac;
    if (crit) a *= 1.5;
    if (effectiveness >= 2) {
      a *= 1.3;
    } else if (effectiveness > 0 && effectiveness < 1) {
      a *= 0.7;
    }
    return a.clamp(0.0, 12.0).toDouble();
  }

  /// Desplazamiento en el instante [a] (0..1) de la animación de ataque: solo
  /// tiembla durante el impacto (a entre 0.5 y 0.92) y se amortigua.
  static Offset offset(double a, double amplitude) {
    if (amplitude <= 0 || a < 0.5 || a > 0.92) return Offset.zero;
    final decay = 1 - (a - 0.5) / 0.42;
    final x = (a - 0.5) * 90;
    return Offset(math.sin(x) * amplitude * decay, math.cos(x * 1.3) * amplitude * 0.6 * decay);
  }
}

/// Texto de efectividad del golpe (null si no hay nada que decir).
String? effectivenessBanner({required double effectiveness, required bool miss, required bool crit}) {
  if (miss) return null;
  if (effectiveness == 0) return 'No afecta...';
  if (effectiveness >= 2) return crit ? '¡Golpe crítico! ¡Es muy eficaz!' : '¡Es muy eficaz!';
  if (effectiveness < 1) return crit ? '¡Golpe crítico! No es muy eficaz...' : 'No es muy eficaz...';
  return crit ? '¡Golpe crítico!' : null;
}

/// Cuántas partículas de sprite se lanzan según la potencia del golpe.
int burstCount({required bool crit, required double effectiveness}) {
  var n = 6;
  if (effectiveness >= 2) n += 2;
  if (crit) n += 3;
  if (effectiveness > 0 && effectiveness < 1) n -= 2;
  return n.clamp(3, 12).toInt();
}

/// Ráfaga de sprites FRLG del tipo del movimiento: una secuencia en el centro
/// (p. ej. la explosión de fuego) y partículas que salen disparadas y se
/// desvanecen. Si la hoja no cargó, no dibuja nada (queda `ImpactBurst`).
class SpriteBurst extends StatelessWidget {
  final String type;

  /// Progreso 0..1 del estallido.
  final double t;
  final double size;
  final int count;
  const SpriteBurst({super.key, required this.type, required this.t, required this.size, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(size),
        painter: _SpriteBurstPainter(type: type, t: t, count: count),
      ),
    );
  }
}

class _SpriteBurstPainter extends CustomPainter {
  final String type;
  final double t;
  final int count;
  _SpriteBurstPainter({required this.type, required this.t, required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = GbaSprites.attackFx;
    if (sheet == null) return;
    final center = size.center(Offset.zero);
    final tt = t.clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    // Secuencia central (solo algunos tipos).
    final seq = GbaFx.sequenceFor(type);
    if (seq.isNotEmpty) {
      final i = math.min(seq.length - 1, (tt * seq.length).floor());
      final src = seq[i];
      final s = size.width * 0.62 / src.width;
      paint.color = Colors.white.withValues(alpha: tt < 0.85 ? 1 : (1 - tt) / 0.15);
      canvas.drawImageRect(sheet, src, Rect.fromCenter(center: center, width: src.width * s, height: src.height * s), paint);
    }

    // Partículas.
    final parts = GbaFx.particlesFor(type);
    if (parts.isEmpty) return;
    final ease = 1 - math.pow(1 - tt, 2).toDouble();
    final fade = tt < 0.65 ? 1.0 : ((1 - tt) / 0.35).clamp(0.0, 1.0).toDouble();
    for (var k = 0; k < count; k++) {
      final r = math.Random(k * 7919 + type.hashCode);
      final angle = (k / count) * 2 * math.pi + r.nextDouble() * 0.6;
      final dist = ease * size.width * (0.28 + 0.22 * r.nextDouble());
      final src = parts[k % parts.length];
      final big = math.max(src.width, src.height);
      final scale = (size.width * 0.26 / big).clamp(1.0, 3.0).toDouble();
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate((r.nextDouble() - 0.5) * 1.2 + ease * (r.nextDouble() - 0.5) * 2);
      paint.color = Colors.white.withValues(alpha: fade);
      final w = src.width * scale, h = src.height * scale;
      canvas.drawImageRect(sheet, src, Rect.fromLTWH(-w / 2, -h / 2, w, h), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SpriteBurstPainter old) => old.t != t || old.type != type || old.count != count;
}
