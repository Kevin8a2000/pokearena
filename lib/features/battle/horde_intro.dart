import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gba/gba_intro.dart';
import 'gba/gba_sprites.dart';

/// Línea de tiempo (ms) de la entrada de la vista 2.5D.
///
/// El lado del jugador reutiliza [IntroTimeline] (entrenador, 5 cuadros de
/// lanzamiento, bola en arco, apertura y aparición del Pokémon). El rival
/// tiene un entrenador al fondo que lanza **una bola por Pokémon**, una tras
/// otra, y cada rival sale de la suya. Son funciones puras para poder
/// probarlas.
class HordeIntro {
  HordeIntro._();

  static const rivalInMs = 500;

  /// Cuándo suelta la primera bola el entrenador rival y cada cuánto la siguiente.
  static const firstReleaseAt = 900;
  static const releaseGapMs = 220;
  static const flightMs = 500;

  /// Cada fase de apertura de la bola (igual que en la vista GBA).
  static const stageMs = IntroTimeline.stageMs;
  static const emergeMs = IntroTimeline.emergeMs;
  static const rivalOutMs = 500;

  static double _lin(double ms, num start, num dur) => ((ms - start) / dur).clamp(0.0, 1.0).toDouble();
  static double _ease(double t) => 1 - (1 - t) * (1 - t);

  /// Cuándo suelta el entrenador rival la bola [k].
  static int releaseAt(int k) => firstReleaseAt + releaseGapMs * k;

  /// Cuándo cae la bola [k] sobre su sitio.
  static int landAt(int k) => releaseAt(k) + flightMs;

  /// Cuándo empieza a salir el Pokémon [k] de su bola.
  static int emergeAt(int k) => landAt(k) + stageMs;

  /// Cuándo empieza a irse el entrenador rival (después de lanzar la última).
  static int rivalOutAt(int n) => releaseAt(math.max(0, n - 1)) + 200;

  /// Duración total de la entrada (no baja de la de la vista GBA).
  static int total(int n) {
    final rivalEnd = emergeAt(math.max(0, n - 1)) + emergeMs;
    return math.max(IntroTimeline.total, rivalEnd + 600);
  }

  /// 0 = entrenador rival en su sitio, 1 = fuera de pantalla (arriba).
  static double rivalOffset(double ms, int n) {
    if (ms < rivalOutAt(n)) return 1 - _ease(_lin(ms, 0, rivalInMs));
    return _ease(_lin(ms, rivalOutAt(n), rivalOutMs));
  }

  /// Progreso del vuelo de la bola [k] (0 antes de soltarla, 1 al caer).
  static double ballFlight(double ms, int k) => _lin(ms, releaseAt(k), flightMs);

  /// 0 cerrada (en vuelo), 1 abriéndose, 2 abierta, -1 oculta o ya no se ve.
  static int ballStage(double ms, int k) {
    if (ms < releaseAt(k)) return -1;
    if (ms < landAt(k)) return 0;
    if (ms < landAt(k) + stageMs) return 1;
    if (ms < landAt(k) + stageMs * 3) return 2;
    return -1;
  }

  /// Destello blanco al abrirse la bola [k] (1 → 0).
  static double flash(double ms, int k) {
    final at = emergeAt(k);
    if (ms < at) return 0;
    return 1 - _lin(ms, at, 350);
  }

  /// 0 = Pokémon [k] oculto, 1 = ya completo.
  static double reveal(double ms, int k) => _lin(ms, emergeAt(k), emergeMs);

  /// Cuándo suena el grito del rival [k].
  static int cryAt(int k) => emergeAt(k) + 200;
}

/// Capa con los dos entrenadores y las Poké Balls de la entrada 2.5D. Ocupa
/// todo el escenario y no intercepta toques.
class HordeIntroOverlay extends StatelessWidget {
  final double ms;
  final bool female;

  /// 0 fácil, 1 normal, 2 difícil: elige al entrenador rival.
  final int tier;
  final int seed;

  /// Centro (en px del escenario) del Pokémon del jugador y de cada rival.
  final Offset playerTarget;
  final List<Offset> enemyTargets;
  const HordeIntroOverlay({
    super.key,
    required this.ms,
    required this.female,
    required this.tier,
    required this.seed,
    required this.playerTarget,
    required this.enemyTargets,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HordeIntroPainter(
          ms: ms,
          female: female,
          tier: tier,
          seed: seed,
          playerTarget: playerTarget,
          enemyTargets: enemyTargets,
        ),
      ),
    );
  }
}

class _HordeIntroPainter extends CustomPainter {
  final double ms;
  final bool female;
  final int tier;
  final int seed;
  final Offset playerTarget;
  final List<Offset> enemyTargets;
  _HordeIntroPainter({
    required this.ms,
    required this.female,
    required this.tier,
    required this.seed,
    required this.playerTarget,
    required this.enemyTargets,
  });

  final Paint _sprite = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    _drawPlayerSide(canvas, size);
    _drawRivalSide(canvas, size);
  }

  void _drawPlayerSide(Canvas canvas, Size size) {
    final h = size.height;
    final tSize = (h * 0.40).clamp(64.0, 128.0);
    final home = Offset(2, h - h * 0.02 - tSize);
    final off = IntroTimeline.trainerOffset(ms);
    final tx = home.dx - off * (tSize + 12);

    final sheet = GbaSprites.trainers;
    if (sheet != null && off < 1) {
      final src = GbaSprites.trainerBack(female: female, frame: IntroTimeline.throwFrame(ms));
      canvas.drawImageRect(sheet, src, Rect.fromLTWH(tx, home.dy, tSize, tSize), _sprite);
    }

    final hand = Offset(home.dx + tSize * 0.82, home.dy + tSize * 0.30);
    _ball(
      canvas,
      from: hand,
      to: playerTarget,
      flight: IntroTimeline.ballFlight(ms),
      stage: IntroTimeline.ballStage(ms),
      flash: IntroTimeline.flash(ms),
      arc: h * 0.30,
    );
  }

  void _drawRivalSide(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final n = enemyTargets.length;
    if (n == 0) return;
    final rSize = (h * 0.30).clamp(56.0, 96.0);
    final home = Offset((w - rSize) / 2, 4);
    final off = HordeIntro.rivalOffset(ms, n);
    final ry = home.dy - off * (rSize + 8);

    final sheet = GbaSprites.trainers;
    if (sheet != null && off < 1) {
      final src = GbaSprites.trainerFront(tier: tier, seed: seed);
      canvas.drawImageRect(sheet, src, Rect.fromLTWH(home.dx, ry, rSize, rSize), _sprite);
    }

    for (var k = 0; k < n; k++) {
      // Cada bola sale de la mano del entrenador, algo más a un lado según su destino.
      final hand = Offset(home.dx + rSize * (0.5 + 0.18 * (k - (n - 1) / 2)), ry + rSize * 0.58);
      _ball(
        canvas,
        from: hand,
        to: enemyTargets[k],
        flight: HordeIntro.ballFlight(ms, k),
        stage: HordeIntro.ballStage(ms, k),
        flash: HordeIntro.flash(ms, k),
        arc: h * 0.10,
      );
    }
  }

  void _ball(
    Canvas canvas, {
    required Offset from,
    required Offset to,
    required double flight,
    required int stage,
    required double flash,
    required double arc,
  }) {
    if (stage >= 0) {
      final pos = stage == 0 ? Offset.lerp(from, to, flight)! + Offset(0, -math.sin(math.pi * flight) * arc) : to;
      paintPokeBall(canvas, _sprite, pos, stage, stage == 0 ? 2.0 : 2.4, spin: stage == 0 ? flight * 6 * math.pi : 0);
    }
    if (flash > 0.01) {
      canvas.drawCircle(to, 10 + (1 - flash) * 38, Paint()..color = Colors.white.withValues(alpha: (flash * 0.85).clamp(0.0, 1.0)));
    }
  }

  @override
  bool shouldRepaint(covariant _HordeIntroPainter old) =>
      old.ms != ms ||
      old.female != female ||
      old.tier != tier ||
      old.seed != seed ||
      old.playerTarget != playerTarget ||
      old.enemyTargets.length != enemyTargets.length;
}
