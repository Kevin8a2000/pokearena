import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'duel_engine.dart';

/// Animación del luchador con el cuerpo ENTERO: nada de recortar el sprite en
/// piezas (eso lo deformaba). El movimiento sale de tres capas:
///  1. [poseFor]: la postura objetivo de cada acción (encoger/estirar,
///     inclinar, desplazar), con anticipación, golpe y recuperación.
///  2. [FighterAnim]: muelles amortiguados que siguen esa postura, así el
///     cuerpo acelera, se pasa un poco y se asienta (movimiento natural).
///  3. [FighterSprite]: aplica la postura desde los pies, sin cortar la imagen.
///
/// El sprite mira a la IZQUIERDA; quien lo use lo espeja para mirar a la derecha.

/// Postura del cuerpo (fracciones del tamaño del sprite; ángulos en radianes).
class RigPose {
  /// Desplazamiento: positivo = hacia atrás (derecha local), `dy` positivo = abajo.
  final double dx;
  final double dy;
  final double sx;
  final double sy;
  final double rot;
  const RigPose({this.dx = 0, this.dy = 0, this.sx = 1, this.sy = 1, this.rot = 0});

  static const neutral = RigPose();

  RigPose lerp(RigPose o, double t) => RigPose(
        dx: dx + (o.dx - dx) * t,
        dy: dy + (o.dy - dy) * t,
        sx: sx + (o.sx - sx) * t,
        sy: sy + (o.sy - sy) * t,
        rot: rot + (o.rot - rot) * t,
      );
}

double _ease(double t) => t * t * (3 - 2 * t);

/// Postura objetivo según lo que hace el luchador. Función pura (testeable).
/// [clock] segundos acumulados, [stateT] tiempo en el estado actual, [speed]
/// velocidad horizontal normalizada (0 parado, 1 andando, ~1.7 corriendo).
RigPose poseFor({
  required DuelState state,
  required double stateT,
  required double clock,
  double speed = 0,
  bool guarding = false,
  double y = 0,
  double vy = 0,
  double seed = 0,
}) {
  final t = clock + seed;

  // Reposo: respira despacio y se balancea un poco.
  var pose = RigPose(
    sy: 1 + 0.02 * math.sin(t * 3.2),
    sx: 1 - 0.01 * math.sin(t * 3.2),
    rot: 0.012 * math.sin(t * 1.7),
  );

  // Andar / correr: rebote al ritmo de los pasos y cuerpo inclinado al avanzar.
  if (speed > 0.05 && y <= 0 && (state == DuelState.idle)) {
    final f = 8.5 + 3.5 * math.min(speed, 1.7);
    final step = math.sin(t * f);
    final k = math.min(speed, 1.7);
    pose = RigPose(
      dy: -0.028 * k * step.abs(),
      sy: 1 - 0.018 * k * (1 - step.abs()),
      sx: 1 + 0.02 * k,
      rot: -(0.035 + 0.05 * k) + 0.025 * step * k, // adelante + balanceo
    );
  }

  // En el aire: se estira al subir y se recoge un poco al caer.
  if (y > 0 || vy > 0) {
    final up = vy > 0;
    pose = RigPose(sy: up ? 1.1 : 1.03, sx: up ? 0.93 : 0.98, rot: up ? -0.05 : 0.04);
  }

  switch (state) {
    case DuelState.attack:
      // Anticipación (se echa atrás), golpe (se lanza adelante) y recuperación.
      final p = (stateT / DuelTuning.meleeCooldown).clamp(0.0, 1.0).toDouble();
      final hitP = DuelTuning.meleeHitAt / DuelTuning.meleeCooldown;
      if (p < hitP) {
        final w = _ease(p / hitP);
        pose = RigPose(dx: 0.05 * w, sx: 1 - 0.08 * w, sy: 1 + 0.04 * w, rot: 0.1 * w);
      } else {
        final r = ((p - hitP) / (1 - hitP)).clamp(0.0, 1.0).toDouble();
        final strike = math.sin(math.pi * math.min(1.0, r * 1.5));
        pose = RigPose(dx: -0.17 * strike, sx: 1 + 0.13 * strike, sy: 1 - 0.07 * strike, rot: -0.17 * strike);
      }
    case DuelState.skill:
      // Horda: se afirma y empuja con cada disparo.
      final pulse = math.max(0.0, math.sin(stateT * 2 * math.pi / DuelTuning.hordeInterval));
      final w = _ease((stateT / 0.15).clamp(0.0, 1.0).toDouble());
      pose = RigPose(dx: 0.03 * w + 0.025 * pulse, sx: 1 - 0.03 * w + 0.03 * pulse, sy: 1 + 0.03 * w - 0.02 * pulse, rot: 0.05 * w - 0.05 * pulse);
    case DuelState.ultra:
      final p = (stateT / DuelTuning.ultraTime).clamp(0.0, 1.0).toDouble();
      final grow = math.sin(math.pi * math.min(1.0, p * 1.6));
      pose = RigPose(
        dx: 0.01 * math.sin(t * 60) * (p < 0.5 ? 1 : 0.4),
        sx: 1 + 0.1 * grow,
        sy: 1 + 0.1 * grow,
        rot: 0.06 * (1 - grow),
      );
    case DuelState.dodge:
      pose = const RigPose(sx: 1.18, sy: 0.88, rot: -0.2);
    case DuelState.slide:
      pose = const RigPose(sx: 1.2, sy: 0.66, rot: -0.1);
    case DuelState.hurt:
      final k = (1 - stateT / DuelTuning.hitStun).clamp(0.0, 1.0).toDouble();
      pose = RigPose(dx: 0.08 * k, sx: 1 - 0.08 * k, sy: 1 + 0.06 * k, rot: 0.2 * k);
    case DuelState.ko:
      pose = RigPose.neutral;
    case DuelState.idle:
      if (guarding) {
        pose = RigPose(sy: 0.9 + 0.01 * math.sin(t * 8), sx: 1.06, rot: 0.03);
      }
  }
  return pose;
}

/// Muelle amortiguado de una magnitud: la sigue con inercia y un pequeño
/// rebote, en vez de saltar de golpe a la postura nueva.
class Spring {
  double pos;
  double vel = 0;
  Spring(this.pos);

  void step(double target, double dt, {double stiffness = 220, double damping = 0.62}) {
    final c = 2 * math.sqrt(stiffness) * damping;
    // Subpasos pequeños: estable aunque el frame sea largo.
    var left = dt;
    while (left > 1e-6) {
      final h = math.min(left, 1 / 120);
      vel += (stiffness * (target - pos) - c * vel) * h;
      pos += vel * h;
      left -= h;
    }
  }
}

/// Estado de animación de un luchador: un muelle por canal de la postura.
class FighterAnim {
  final Spring dx = Spring(0), dy = Spring(0), sx = Spring(1), sy = Spring(1), rot = Spring(0);
  double _prevY = 0;
  double _landT = 0;

  RigPose get pose => RigPose(dx: dx.pos, dy: dy.pos, sx: sx.pos, sy: sy.pos, rot: rot.pos);

  /// Avanza [dt] segundos hacia la postura objetivo [target]. [y] es la altura
  /// actual (para detectar el aterrizaje y aplastar al caer).
  void step(RigPose target, double dt, {double y = 0, bool snappy = false}) {
    if (_prevY > 0 && y <= 0) _landT = 0.2; // acaba de aterrizar
    _prevY = y;
    _landT = math.max(0, _landT - dt);
    var t = target;
    if (_landT > 0) {
      final k = _ease((_landT / 0.2).clamp(0.0, 1.0).toDouble());
      t = RigPose(dx: t.dx, dy: t.dy, sx: t.sx + 0.12 * k, sy: t.sy - 0.16 * k, rot: t.rot);
    }
    // Las acciones de combate responden rápido; el reposo, con más suavidad.
    final k = snappy ? 520.0 : 230.0;
    final z = snappy ? 0.55 : 0.62;
    dx.step(t.dx, dt, stiffness: k, damping: z);
    dy.step(t.dy, dt, stiffness: k, damping: z);
    sx.step(t.sx, dt, stiffness: k, damping: z);
    sy.step(t.sy, dt, stiffness: k, damping: z);
    rot.step(t.rot, dt, stiffness: k, damping: z);
  }
}

/// Aplica la postura al sprite ENTERO, con los pies como pivote.
class FighterSprite extends StatelessWidget {
  final Widget child;
  final double size;
  final RigPose pose;
  const FighterSprite({super.key, required this.child, required this.size, required this.pose});

  @override
  Widget build(BuildContext context) {
    final m = Matrix4.identity()
      ..translateByDouble(pose.dx * size, pose.dy * size, 0, 1)
      ..rotateZ(pose.rot)
      ..scaleByDouble(pose.sx, pose.sy, 1, 1);
    return SizedBox(
      width: size,
      height: size,
      child: Transform(alignment: Alignment.bottomCenter, transform: m, child: child),
    );
  }
}
