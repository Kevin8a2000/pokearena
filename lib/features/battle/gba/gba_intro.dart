import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gba_sprites.dart';

enum IntroPhase { trainersEnter, throwing, ballFlight, ballOpens, pokemonEmerges, done }

/// Línea de tiempo (en milisegundos) de la entrada de la batalla GBA:
/// el entrenador entra, lanza la Poké Ball, la bola vuela en arco y se abre,
/// y de ella sale el Pokémon; el rival hace lo mismo un poco después.
///
/// Son funciones puras (sin Flutter) para poder probarlas.
class IntroTimeline {
  IntroTimeline._();

  /// Duración total de `entering` en la vista GBA Normal.
  static const total = 3400;

  // --- Jugador ---
  static const trainerInMs = 450;
  static const throwStart = 450;
  static const throwFrameMs = 150;
  static const releaseFrame = 3; // cuadro en que la mano suelta la bola
  static const releaseAt = throwStart + throwFrameMs * releaseFrame; // 900
  static const flightMs = 650;
  static const landAt = releaseAt + flightMs; // 1550
  static const stageMs = 100; // cada fase de apertura de la bola
  static const emergeAt = landAt + stageMs; // 1650
  static const emergeMs = 550;
  static const trainerOutAt = 1700;
  static const trainerOutMs = 600;
  static const playerCryAt = emergeAt + 100; // 1750

  // --- Rival ---
  static const rivalInMs = 500;
  static const rivalReleaseAt = 1250;
  static const rivalFlightMs = 500;
  static const rivalLandAt = rivalReleaseAt + rivalFlightMs; // 1750
  static const rivalEmergeAt = rivalLandAt + stageMs; // 1850
  static const rivalOutAt = 2400;
  static const rivalOutMs = 600;
  static const rivalCryAt = rivalEmergeAt + 200; // 2050

  /// Las placas de PS aparecen cuando ya salieron los dos Pokémon.
  static const platesAt = 2300;
  static const platesMs = 300;

  static double _lin(double ms, num start, num dur) => ((ms - start) / dur).clamp(0.0, 1.0).toDouble();
  static double _ease(double t) => 1 - (1 - t) * (1 - t);

  /// 0 = el entrenador está en su sitio, 1 = fuera de pantalla (a la izquierda).
  static double trainerOffset(double ms) {
    if (ms < trainerOutAt) return 1 - _ease(_lin(ms, 0, trainerInMs));
    return _ease(_lin(ms, trainerOutAt, trainerOutMs));
  }

  /// Cuadro de lanzamiento de la espalda (0..4).
  static int throwFrame(double ms) {
    if (ms < throwStart) return 0;
    return math.min(GbaSprites.throwFrames - 1, (ms - throwStart) ~/ throwFrameMs);
  }

  /// Progreso del vuelo de la bola del jugador (0 antes de soltarla, 1 al caer).
  static double ballFlight(double ms) => _lin(ms, releaseAt, flightMs);

  /// 0 cerrada (en vuelo), 1 abriéndose, 2 abierta, -1 ya no se ve.
  static int ballStage(double ms) {
    if (ms < releaseAt) return -1;
    if (ms < landAt) return 0;
    if (ms < landAt + stageMs) return 1;
    if (ms < landAt + stageMs * 3) return 2;
    return -1;
  }

  /// Destello blanco al abrirse la bola (1 → 0).
  static double flash(double ms, {bool rival = false}) {
    final at = (rival ? rivalLandAt : landAt) + stageMs;
    if (ms < at) return 0;
    return 1 - _lin(ms, at, 350);
  }

  /// 0 = Pokémon oculto, 1 = ya completo.
  static double playerReveal(double ms) => _lin(ms, emergeAt, emergeMs);

  // --- Rival ---
  /// 0 = en su sitio, 1 = fuera de pantalla (a la derecha).
  static double rivalOffset(double ms) {
    if (ms < rivalOutAt) return 1 - _ease(_lin(ms, 0, rivalInMs));
    return _ease(_lin(ms, rivalOutAt, rivalOutMs));
  }

  static double rivalBallFlight(double ms) => _lin(ms, rivalReleaseAt, rivalFlightMs);

  static int rivalBallStage(double ms) {
    if (ms < rivalReleaseAt) return -1;
    if (ms < rivalLandAt) return 0;
    if (ms < rivalLandAt + stageMs) return 1;
    if (ms < rivalLandAt + stageMs * 3) return 2;
    return -1;
  }

  static double rivalReveal(double ms) => _lin(ms, rivalEmergeAt, emergeMs);

  /// Opacidad de las placas de PS y suplentes.
  static double platesOpacity(double ms) => _lin(ms, platesAt, platesMs);

  static IntroPhase phaseAt(double ms) {
    if (ms >= rivalOutAt + rivalOutMs) return IntroPhase.done;
    if (ms < throwStart) return IntroPhase.trainersEnter;
    if (ms < releaseAt) return IntroPhase.throwing;
    if (ms < landAt) return IntroPhase.ballFlight;
    if (ms < emergeAt) return IntroPhase.ballOpens;
    return IntroPhase.pokemonEmerges;
  }
}

/// Hace "salir" a un Pokémon de su Poké Ball: aparece como silueta blanca
/// pequeña que crece y recupera su color. [progress] 0 = oculto, 1 = completo.
class IntroReveal extends StatelessWidget {
  final double progress;
  final Widget child;
  const IntroReveal({super.key, required this.progress, required this.child});

  @override
  Widget build(BuildContext context) {
    if (progress >= 1) return child;
    if (progress <= 0) return Opacity(opacity: 0, child: child);
    final e = 1 - math.pow(1 - progress, 2).toDouble();
    return Transform.scale(
      scale: 0.25 + 0.75 * e,
      alignment: Alignment.bottomCenter,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: (1 - progress).clamp(0.0, 1.0)), BlendMode.srcATop),
        child: child,
      ),
    );
  }
}

/// Capa con los entrenadores y las Poké Balls. Ocupa todo el viewport y no
/// intercepta toques.
class GbaIntroOverlay extends StatelessWidget {
  /// Milisegundos transcurridos desde el inicio de la intro.
  final double ms;
  final bool female;

  /// Dificultad del Bot: 0 fácil, 1 normal, 2 difícil (elige su entrenador).
  final int tier;

  /// Semilla estable para elegir al entrenador rival (p. ej. id del Pokémon).
  final int seed;
  const GbaIntroOverlay({
    super.key,
    required this.ms,
    required this.female,
    required this.tier,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _IntroPainter(ms: ms, female: female, tier: tier, seed: seed),
      ),
    );
  }
}

class _IntroPainter extends CustomPainter {
  final double ms;
  final bool female;
  final int tier;
  final int seed;
  _IntroPainter({required this.ms, required this.female, required this.tier, required this.seed});

  final Paint _sprite = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Centros de los Pokémon (misma geometría que _GbaFighter en el viewport).
    final playerTarget = Offset(10 + 47, h - 64 - 47 + 10);
    final rivalTarget = Offset(w - 20 - 36, 68 + 36 + 8);

    _drawPlayerSide(canvas, size, playerTarget);
    _drawRivalSide(canvas, size, rivalTarget);
  }

  void _drawPlayerSide(Canvas canvas, Size size, Offset target) {
    final h = size.height;
    final tSize = (h * 0.42).clamp(64.0, 120.0);
    final home = Offset(2, h - 56 - tSize);
    final off = IntroTimeline.trainerOffset(ms);
    final tx = home.dx - off * (tSize + 12);

    final sheet = GbaSprites.trainers;
    if (sheet != null && off < 1) {
      final src = GbaSprites.trainerBack(female: female, frame: IntroTimeline.throwFrame(ms));
      canvas.drawImageRect(sheet, src, Rect.fromLTWH(tx, home.dy, tSize, tSize), _sprite);
    }

    // Bola: sale de la mano del entrenador y cae sobre el sitio del Pokémon.
    final hand = Offset(home.dx + tSize * 0.82, home.dy + tSize * 0.30);
    _drawBall(
      canvas,
      from: hand,
      to: target,
      flight: IntroTimeline.ballFlight(ms),
      stage: IntroTimeline.ballStage(ms),
      flash: IntroTimeline.flash(ms),
      arc: h * 0.22,
    );
  }

  void _drawRivalSide(Canvas canvas, Size size, Offset target) {
    final w = size.width, h = size.height;
    final rSize = (h * 0.36).clamp(56.0, 96.0);
    final home = Offset(w - rSize - 6, 30);
    final off = IntroTimeline.rivalOffset(ms);
    final rx = home.dx + off * (rSize + 12);

    final sheet = GbaSprites.trainers;
    if (sheet != null && off < 1) {
      final src = GbaSprites.trainerFront(tier: tier, seed: seed);
      canvas.drawImageRect(sheet, src, Rect.fromLTWH(rx, home.dy, rSize, rSize), _sprite);
    }

    final hand = Offset(home.dx + rSize * 0.2, home.dy + rSize * 0.6);
    _drawBall(
      canvas,
      from: hand,
      to: target,
      flight: IntroTimeline.rivalBallFlight(ms),
      stage: IntroTimeline.rivalBallStage(ms),
      flash: IntroTimeline.flash(ms, rival: true),
      arc: h * 0.16,
    );
  }

  void _drawBall(
    Canvas canvas, {
    required Offset from,
    required Offset to,
    required double flight,
    required int stage,
    required double flash,
    required double arc,
  }) {
    if (stage >= 0) {
      final t = flight;
      final pos = stage == 0
          ? Offset.lerp(from, to, t)! + Offset(0, -math.sin(math.pi * t) * arc)
          : to; // abriéndose / abierta: ya está en el suelo
      final scale = stage == 0 ? 2.2 : 2.6;
      _ball(canvas, pos, stage, scale, spin: stage == 0 ? t * 6 * math.pi : 0);
    }
    if (flash > 0.01) {
      final p = Paint()..color = Colors.white.withValues(alpha: (flash * 0.85).clamp(0.0, 1.0));
      canvas.drawCircle(to, 12 + (1 - flash) * 46, p);
    }
  }

  void _ball(Canvas canvas, Offset center, int stage, double scale, {double spin = 0}) =>
      paintPokeBall(canvas, _sprite, center, stage, scale, spin: spin);

  @override
  bool shouldRepaint(covariant _IntroPainter old) =>
      old.ms != ms || old.female != female || old.tier != tier || old.seed != seed;
}

/// Dibuja una Poké Ball (fase 0 cerrada, 1 abriéndose, 2 abierta) centrada en
/// [center]; sin sprites usa una bola roja y blanca dibujada por código.
void paintPokeBall(Canvas canvas, Paint sprite, Offset center, int stage, double scale, {double spin = 0}) {
  final sheet = GbaSprites.balls;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  if (spin != 0) canvas.rotate(spin);
  if (sheet != null) {
    final src = GbaSprites.ball(stage: stage);
    final w = src.width * scale, h = src.height * scale;
    canvas.drawImageRect(sheet, src, Rect.fromLTWH(-w / 2, -h / 2, w, h), sprite);
  } else {
    final r = 6.0 * scale;
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), math.pi, math.pi, true, Paint()..color = const Color(0xFFE53935));
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), 0, math.pi, true, Paint()..color = Colors.white);
    canvas.drawCircle(Offset.zero, r * 0.28, Paint()..color = Colors.black54);
  }
  canvas.restore();
}

/// Efecto corto de "Poké Ball que se abre" sobre el sitio de un Pokémon que
/// entra a mitad del combate (cambio de luchador o relevo tras un KO), sin
/// entrenador. [t] va de 0 a 1.
class BallPop {
  BallPop._();

  /// Cuándo empieza a salir el Pokémon dentro del efecto (0..1).
  static const emergeFrom = 0.25;

  /// 0 = oculto, 1 = completo, según [t].
  static double reveal(double t) => ((t - emergeFrom) / 0.6).clamp(0.0, 1.0).toDouble();

  /// 0 cerrada→ 1 abriéndose, 2 abierta, -1 ya no se ve.
  static int stage(double t) {
    if (t < 0.25) return 1;
    if (t < 0.6) return 2;
    return -1;
  }

  static double flash(double t) => t < 0.2 ? 0 : (1 - (t - 0.2) / 0.6).clamp(0.0, 1.0).toDouble();
}

class GbaBallPopOverlay extends StatelessWidget {
  final double t;
  final bool rival;

  /// Centro del Pokémon que entra; si es null se usan los de la vista GBA.
  final Offset? center;
  const GbaBallPopOverlay({super.key, required this.t, required this.rival, this.center});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _PopPainter(t: t, rival: rival, center: center)));
  }
}

class _PopPainter extends CustomPainter {
  final double t;
  final bool rival;
  final Offset? center;
  _PopPainter({required this.t, required this.rival, this.center});

  final Paint _sprite = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Mismos centros que los Pokémon del viewport.
    final target = center ?? (rival ? Offset(w - 20 - 36, 68 + 36 + 8) : Offset(10 + 47, h - 64 - 47 + 10));
    final stage = BallPop.stage(t);
    if (stage >= 0) paintPokeBall(canvas, _sprite, target, stage, 2.6);
    final flash = BallPop.flash(t);
    if (flash > 0.01) {
      canvas.drawCircle(target, 12 + (1 - flash) * 40, Paint()..color = Colors.white.withValues(alpha: (flash * 0.85).clamp(0.0, 1.0)));
    }
  }

  @override
  bool shouldRepaint(covariant _PopPainter old) => old.t != t || old.rival != rival || old.center != center;
}
