import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/theme/type_colors.dart';
import '../../core/widgets/poke_image.dart';
import '../settings/settings_provider.dart';
import 'battle_provider.dart';
import 'arena_background.dart';
import 'battle_fx.dart';
import 'battle_fx_extra.dart';
import 'battle_sound.dart';
import 'battle_terrain.dart';
import 'battle_tutorial.dart';
import 'gba/gba_intro.dart';
import 'horde_intro.dart';
import 'vs_intro.dart';

/// Posición de un miembro de la horda en la formación de arco.
/// [x] en -0.62..0.62 (alineación), [y] altura, [scale] por profundidad.
class HordeSlot {
  final double x;
  final double y;
  final double scale;
  const HordeSlot(this.x, this.y, this.scale);
}

/// Formación de arco para [n] rivales (centrado si es 1).
/// Función pura para poder probarla.
List<HordeSlot> hordeSlots(int n) {
  if (n <= 0) return const [];
  return [
    for (var i = 0; i < n; i++)
      () {
        final t = n == 1 ? 0.5 : i / (n - 1);
        return HordeSlot(
          -0.62 + 1.24 * t,
          -0.20 - math.sin(t * math.pi) * 0.24,
          0.52 + math.sin(t * math.pi) * 0.26,
        );
      }(),
  ];
}

/// Tamaño del rival del [slot] dentro de un escenario de [w] x [h].
double hordeEnemySize(HordeSlot slot, double w, double h) =>
    math.min(w * 0.24, h * 0.30) * (0.7 + slot.scale * 0.5);

/// Tamaño del Pokémon del jugador (primer plano, de espaldas).
double hordePlayerSize(double w, double h) => math.min(w * 0.40, h * 0.62);

/// Centro (en px del escenario) del rival [i] de [n]. `Align` resta el tamaño
/// del hijo, por eso se usa `(w - size) / 2` y no `w / 2`.
Offset hordeCenter(int i, int n, double w, double h) {
  final slot = hordeSlots(n)[i];
  final size = hordeEnemySize(slot, w, h);
  return Offset(w / 2 + slot.x * (w - size) / 2, h / 2 + slot.y * (h - size) / 2);
}

/// Centro del Pokémon del jugador: `left: 0.04w`, `bottom: 0.02h`.
Offset hordePlayerCenter(double w, double h) {
  final size = hordePlayerSize(w, h);
  return Offset(w * 0.04 + size / 2, h - h * 0.02 - size / 2);
}

/// Aclara ([amt] > 0) u oscurece ([amt] < 0) un color. Puro y testeable.
Color shade(Color c, double amt) {
  final t = amt.clamp(-1.0, 1.0);
  final base = t > 0 ? Colors.white : Colors.black;
  return Color.lerp(c, base, t.abs()) ?? c;
}

/// Opacidad de botones/placas sobre el escenario a pantalla completa:
/// mismo valor que kOverlayAlpha en gba_touch_menu.dart, para la misma
/// sensación "se ve el juego a través de los controles".
const double _kHordeOverlayAlpha = 0.62;

/// Ancho del cluster flotante de botones en apaisado, análogo a
/// kActionsWidth en gba_touch_menu.dart.
const double _kHordeActionsWidth = 280;

/// Vista de batalla Horda 2.5D estilo PokeMMO / Gen 5:
/// 1 jugador (de espaldas, pixel) vs hasta 5 rivales en plataforma.
/// Reusa el motor del [BattleProvider] (turnos, daño, PP, pociones).
/// Rendimiento: fondo estático en un solo CustomPainter (repaint solo
/// si cambia el terreno), sprites en caché, sin GIFs ni partículas.
class HordeFightView extends StatefulWidget {
  const HordeFightView({super.key});

  @override
  State<HordeFightView> createState() => _HordeFightViewState();
}

class _HordeFightViewState extends State<HordeFightView>
    with TickerProviderStateMixin {
  late final AnimationController _attack;
  late final AnimationController _idle;
  // Entrada con entrenadores y relevo del jugador (terminados valen 1).
  late final AnimationController _intro;
  late final AnimationController _swap;
  bool _introRunning = false;
  int? _prevPlayerActive;
  int _prevSeq = 0;
  int _hapticSeq = 0;
  String _menu = 'none'; // none | fight | bag | mon

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _swap = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 600),
    );
    _attack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    // Movimiento propio continuo: aleteo/respiración (barato, 60 FPS).
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _attack.dispose();
    _idle.dispose();
    _intro.dispose();
    _swap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();

    // Entrada con entrenadores: arranca con `entering` y termina con él (si
    // se salta, el provider lo apaga y todo queda completo).
    final introActive = b.introRich && b.entering;
    if (introActive && !_introRunning) {
      _introRunning = true;
      _intro.duration = Duration(milliseconds: b.introTotalMs);
      _intro.forward(from: 0);
    } else if (!introActive && _introRunning) {
      _introRunning = false;
      _intro.value = 1;
    }
    // Relevo del jugador (KO o cambio manual): el nuevo sale de una Poké Ball.
    if (b.introRich && !introActive && _prevPlayerActive != null && _prevPlayerActive != b.playerActive) {
      _swap.forward(from: 0);
    }
    _prevPlayerActive = b.playerActive;

    if (b.attackSeq != _prevSeq) {
      _prevSeq = b.attackSeq;
      _attack.forward(from: 0);
      if (b.attackSeq != _hapticSeq) {
        _hapticSeq = b.attackSeq;
        if (b.lastMiss) {
          HapticFeedback.selectionClick();
        } else if (b.lastCrit || b.lastUltimate || b.lastEffectiveness >= 2) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      }
    }

    final compact = MediaQuery.widthOf(context) < 420;

    // Piezas compartidas por el diseño vertical y el apaisado.
    Widget plates() => Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < b.enemyTeam.length; i++)
                _HordePlate(
                  name: prettyName(b.enemyTeam[i].name),
                  hp: b.enemyTeamHp[i],
                  maxHp: b.enemyTeamMaxHp[i],
                  active: i == b.enemyActive,
                ),
            ],
          ),
        );
    final commentary = b.commentary.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '🎙️ ${b.commentary}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          );
    Widget panel({bool translucent = false}) => _MenuPanel(
          menu: _menu,
          onClose: () => setState(() => _menu = 'none'),
          translucent: translucent,
        );
    Widget menuButtons(bool isCompact, {bool dense = false, bool translucent = false}) => _HordeMenu(
          dense: dense,
          menu: _menu,
          compact: isCompact,
          translucent: translucent,
          onPick: (m) => setState(() => _menu = _menu == m ? 'none' : m),
        );
    Widget stage(bool isCompact, {bool fullscreen = false}) => _HordeStage(
          attack: _attack,
          idle: _idle,
          intro: _intro,
          swap: _swap,
          compact: isCompact,
          fullscreen: fullscreen,
        );

    final body = LayoutBuilder(
      builder: (context, cons) {
        // Horizontal (los combates se juegan apaisados): escenario a
        // pantalla completa, sin columna lateral — las tarjetas de HP
        // flotan sobre cada cabeza (dentro de `_HordeStage`) y los
        // botones flotan translúcidos abajo-derecha, igual que GBA.
        if (cons.maxWidth > cons.maxHeight * 1.15) {
          return SafeArea(
            minimum: EdgeInsets.zero,
            child: Stack(
              children: [
                Positioned.fill(child: stage(false, fullscreen: true)),
                if (commentary != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 56,
                    child: Center(child: commentary),
                  ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_menu != 'none') ...[
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: cons.maxHeight * 0.4),
                          child: SingleChildScrollView(
                            child: SizedBox(width: _kHordeActionsWidth, child: panel(translucent: true)),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(width: _kHordeActionsWidth, child: menuButtons(true, dense: true, translucent: true)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        // Vertical (pantallas altas): el diseño de siempre.
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                plates(),
                // Escenario 2.5D flexible.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: stage(compact),
                  ),
                ),
                ?commentary,
                // Panel contextual (movimientos / mochila / equipo).
                panel(),
                // Placa del jugador + menú principal.
                const Align(alignment: Alignment.centerRight, child: _PlayerPlate()),
                menuButtons(compact),
              ],
            ),
          ),
        );
      },
    );

    return Stack(
      children: [
        body,
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            minimum: EdgeInsets.zero,
            child: _HelpButton(onTap: () => showBattleTutorial(context)),
          ),
        ),
      ],
    );
  }
}

/// Botón circular flotante para reabrir el tutorial de combate.
class _HelpButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HelpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cómo se juega',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white38),
          ),
          child: const Icon(Icons.help_outline, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// Escenario con perspectiva: cielo del terreno, suelo inclinado por
/// bandas, plataforma rival y arco de primer plano. Estático (60 FPS).
class _HordeStage extends StatelessWidget {
  final AnimationController attack;
  final AnimationController idle;
  final AnimationController intro;
  final AnimationController swap;
  final bool compact;
  final bool fullscreen;
  const _HordeStage({
    required this.attack,
    required this.idle,
    required this.intro,
    required this.swap,
    required this.compact,
    this.fullscreen = false,
  });

  /// ¿Es Leaf (chica) el entrenador elegido en el perfil? Sin ajustes, Red.
  bool _trainerFemale(BuildContext context) {
    try {
      return context.read<SettingsProvider>().trainerFemale;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();
    final radius = fullscreen ? 0.0 : 14.0;
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final h = cons.maxHeight;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [b.terrain.skyTop, b.terrain.skyBottom],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: AnimatedBuilder(
              animation: Listenable.merge([attack, idle, intro, swap]),
              builder: (context, _) {
                final a = attack.value; // 0..1 por golpe
                // Entrada con entrenadores (ms desde que empezó) y relevo.
                final introActive = b.introRich && b.entering;
                final introMs = introActive
                    ? intro.value * b.introTotalMs
                    : double.infinity;
                final enemyN = b.enemyTeam.length;
                final swapping = !introActive && swap.isAnimating;
                final playerReveal = introActive
                    ? IntroTimeline.playerReveal(introMs)
                    : (swapping ? BallPop.reveal(swap.value) : 1.0);
                final playerCenter = hordePlayerCenter(w, h);
                // Sacudida de pantalla y banner según el golpe.
                final recvMaxHp = attackerOf(b) == 'player'
                    ? b.enemyMaxHp
                    : b.playerMaxHp;
                final screenShake = b.attackSeq > 0 && a < 1.0
                    ? ScreenShake.offset(
                        a,
                        ScreenShake.amplitude(
                          damage: b.lastDamage,
                          defenderMaxHp: recvMaxHp,
                          crit: b.lastCrit,
                          effectiveness: b.lastEffectiveness,
                          miss: b.lastMiss,
                        ),
                      )
                    : Offset.zero;
                final banner = effectivenessBanner(
                  effectiveness: b.lastEffectiveness,
                  miss: b.lastMiss,
                  crit: b.lastCrit,
                );
                // Movimiento propio continuo (fase-distinta por luchador).
                final idleT = idle.value * 2 * math.pi;
                final isRanged =
                    b.lastMoveType.toLowerCase() != 'normal';
                final playerHit =
                    b.attackSeq > 0 && attackerOf(b) == 'player';
                final enemyHit =
                    b.attackSeq > 0 && attackerOf(b) == 'enemy';
                // Gesto del jugador: embestida (físico) o salto (rango).
                final lunge = playerHit && a < 1.0
                    ? (isRanged ? 0.0 : _dash(a))
                    : 0.0;
                final hop = playerHit && isRanged && a < 1.0
                    ? math.sin((a / 0.55).clamp(0.0, 1.0) * math.pi) *
                        -14.0
                    : 0.0;
                // Sacudida del que RECIBE: rival tiembla si pega el
                // jugador, jugador tiembla si pega el rival.
                final enemyShake = playerHit && a > 0.5
                    ? 4.0 *
                        (1 - (a - 0.5) / 0.5) *
                        math.sin((a - 0.5) * 28)
                    : 0.0;
                final playerShake = enemyHit && a > 0.5
                    ? 4.0 *
                        (1 - (a - 0.5) / 0.5) *
                        math.sin((a - 0.5) * 28)
                    : 0.0;
                // Embestida del rival activo cuando ataca (espejo del dash).
                final enemyLunge = enemyHit && a < 1.0
                    ? (isRanged ? 0.0 : -_dash(a) * 0.5)
                    : 0.0;
                final enemyHop = enemyHit && isRanged && a < 1.0
                    ? math.sin((a / 0.55).clamp(0.0, 1.0) * math.pi) *
                        -10.0
                    : 0.0;
                final flash =
                    (b.attackSeq > 0 && a > 0.45 && a < 0.9)
                        ? 1 - (a - 0.45) / 0.45
                        : 0.0;
                final playerSize = hordePlayerSize(w, h);
                // Punto real del rival que recibe: su slot en la
                // formación (antes era un punto fijo al centro).
                final enemySlots =
                    hordeSlots(b.enemyTeam.length);
                final aimed = enemySlots.isEmpty
                    ? const Alignment(0.35, -0.45)
                    : (() {
                        final s = enemySlots[b.enemyActive
                            .clamp(0, enemySlots.length - 1)];
                        return Alignment(s.x, s.y);
                      })();
                return Transform.translate(
                  offset: screenShake,
                  child: Stack(
                  children: [
                    ArenaBackground(
                      terrain: b.terrain,
                      borderRadius: radius,
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _HordeStagePainter(
                          terrain: b.terrain,
                          enemyCount: b.enemyTeam.length,
                        ),
                      ),
                    ),
                    // Horda rival sobre la plataforma, con movimiento
                    // propio (los voladores/bichos aletean) + embestida
                    // del activo cuando ataca el rival.
                    for (var i = 0;
                        i < b.enemyTeam.length;
                        i++)
                      _hordeMember(
                        b: b,
                        i: i,
                        w: w,
                        h: h,
                        idleT: idleT,
                        shake:
                            i == b.enemyActive ? enemyShake : 0.0,
                        flash: i == b.enemyActive && playerHit
                            ? flash
                            : 0.0,
                        a: a,
                        lunge:
                            i == b.enemyActive ? enemyLunge : 0.0,
                        hop: i == b.enemyActive ? enemyHop : 0.0,
                        attacking:
                            i == b.enemyActive && enemyHit && a < 0.3,
                        reveal: introActive
                            ? HordeIntro.reveal(introMs, i)
                            : 1.0,
                      ),
                    // Jugador en primer plano, de espaldas (GIF animado),
                    // con respiración propia continua + sacudida si recibe.
                    Positioned(
                      left: w * 0.04,
                      bottom: h * 0.02,
                      child: IntroReveal(
                        progress: playerReveal,
                        child: Transform.translate(
                        offset: Offset(
                          lunge + playerShake,
                          hop + math.sin(idleT) * 2.0,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: playerSize * 0.85,
                              height: playerSize * 0.85,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colorForType(
                                            b.player!.types.first)
                                        .withValues(alpha: 0.55),
                                    blurRadius: 26,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            // Al recibir el golpe parpadea en silueta blanca.
                            _silhouetteBlink(
                              blink: enemyHit &&
                                  a > 0.45 &&
                                  a < 0.9 &&
                                  ((a - 0.45) * 16).floor().isEven,
                              strength: flash,
                              child: PokeImage(
                                id: b.player!.id,
                                kind: PokeSpriteKind.animatedBack,
                                width: playerSize,
                                height: playerSize,
                                placeholderColor: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                    // Proyectil rango → rival activo (con forma del tipo).
                    if (playerHit && isRanged && a <= 0.55)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.lerp(
                            const Alignment(-0.55, 0.55),
                            aimed,
                            (a / 0.55).clamp(0.0, 1.0),
                          )!,
                          child: MoveProjectile(
                            type: b.lastMoveType,
                            color:
                                colorForType(b.lastMoveType),
                            progress:
                                (a / 0.55).clamp(0.0, 1.0),
                          ),
                        ),
                      ),
                    // Proyectil rival → jugador (con forma del tipo).
                    if (enemyHit && isRanged && a <= 0.55)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.lerp(
                            aimed,
                            const Alignment(-0.55, 0.55),
                            (a / 0.55).clamp(0.0, 1.0),
                          )!,
                          child: MoveProjectile(
                            type: b.lastMoveType,
                            color:
                                colorForType(b.lastMoveType),
                            progress:
                                (a / 0.55).clamp(0.0, 1.0),
                          ),
                        ),
                      ),
                    // Estallido en el que recibe (ambos lados).
                    if (b.attackSeq > 0 && a > 0.5 && a < 0.9)
                      Positioned.fill(
                        child: Align(
                          alignment: playerHit
                              ? aimed
                              : const Alignment(-0.55, 0.55),
                          child: ImpactBurst(
                            color:
                                colorForType(b.lastMoveType),
                            t: (a - 0.5) / 0.4,
                          ),
                        ),
                      ),
                    // Sprites FRLG del tipo del movimiento al impactar, sobre
                    // el que recibe (rival activo o jugador).
                    if (b.attackSeq > 0 &&
                        a > 0.5 &&
                        a < 0.92 &&
                        !b.lastMiss &&
                        b.enemyTeam.isNotEmpty)
                      Builder(builder: (_) {
                        final c = playerHit
                            ? hordeCenter(
                                b.enemyActive.clamp(0, enemyN - 1),
                                enemyN,
                                w,
                                h,
                              )
                            : playerCenter;
                        const burstSize = 120.0;
                        return Positioned(
                          left: c.dx - burstSize / 2,
                          top: c.dy - burstSize / 2,
                          child: SpriteBurst(
                            type: b.lastMoveType,
                            t: ((a - 0.5) / 0.42).clamp(0.0, 1.0),
                            size: burstSize,
                            count: burstCount(
                              crit: b.lastCrit,
                              effectiveness: b.lastEffectiveness,
                            ),
                          ),
                        );
                      }),
                    // Banner de efectividad / crítico.
                    if (banner != null &&
                        b.attackSeq > 0 &&
                        a > 0.55 &&
                        a < 1.0)
                      Positioned(
                        top: h * 0.46,
                        left: 0,
                        right: 0,
                        child: Opacity(
                          opacity:
                              ((1.0 - a) / 0.35).clamp(0.0, 1.0),
                          child: Text(
                            banner,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: b.lastEffectiveness >= 2
                                  ? Colors.amberAccent
                                  : Colors.white,
                              shadows: const [
                                Shadow(
                                    color: Colors.black,
                                    blurRadius: 3),
                                Shadow(
                                    color: Colors.black,
                                    offset: Offset(1, 1)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Bocadillo del atacante sobre su cabeza.
                    if (b.attackSeq > 0 && a < 0.6)
                      Positioned(
                        left: playerHit ? w * 0.04 : w * 0.40,
                        bottom: playerHit
                            ? h * 0.30
                            : h * 0.62,
                        child: SpeechBubble(
                          text: '¡${b.lastMoveName}!',
                          color:
                              colorForType(b.lastMoveType),
                        ),
                      ),
                    // Reacción del que recibe.
                    if (b.attackSeq > 0 && a > 0.5 && a < 0.95)
                      Positioned(
                        left: playerHit ? w * 0.45 : w * 0.06,
                        bottom: playerHit
                            ? h * 0.60
                            : h * 0.34,
                        child: SpeechBubble(
                          text: defenderReaction(
                            miss: b.lastMiss,
                            crit: b.lastCrit,
                            effectiveness:
                                b.lastEffectiveness,
                          ),
                          color: Colors.red,
                        ),
                      ),
                    // Número de daño sobre el rival activo.
                    if (b.attackSeq > 0 &&
                        playerHit &&
                        a > 0.45)
                      Positioned(
                        left: w * 0.45,
                        top: h * 0.08 + (a - 0.45) * -40,
                        child: Opacity(
                          opacity:
                              ((1.0 - a) / 0.55).clamp(0.0, 1.0),
                          child: Text(
                            '-${b.lastDamage}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                    color: Colors.black,
                                    blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Número de daño sobre el jugador cuando pega el rival.
                    if (b.attackSeq > 0 && enemyHit && a > 0.45)
                      Positioned(
                        left: w * 0.08,
                        bottom: h * 0.30 + (a - 0.45) * 40,
                        child: Opacity(
                          opacity:
                              ((1.0 - a) / 0.55).clamp(0.0, 1.0),
                          child: Text(
                            '-${b.lastDamage}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.redAccent,
                              shadows: [
                                Shadow(
                                    color: Colors.white,
                                    blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Tarjetas de HP sobre la cabeza de cada rival de la
                    // horda y del jugador (solo en pantalla completa).
                    if (fullscreen) ...[
                      for (var i = 0; i < enemyN; i++)
                        Builder(builder: (_) {
                          final slot = enemySlots[i];
                          final c = hordeCenter(i, enemyN, w, h);
                          final size = hordeEnemySize(slot, w, h);
                          const plateW = 140.0, plateH = 34.0;
                          return Positioned(
                            left: (c.dx - plateW / 2).clamp(4.0, w - plateW - 4.0),
                            top: (c.dy - size / 2 - plateH - 6).clamp(4.0, h - plateH),
                            child: SizedBox(
                              width: plateW,
                              child: _HordePlate(
                                name: prettyName(b.enemyTeam[i].name),
                                hp: b.enemyTeamHp[i],
                                maxHp: b.enemyTeamMaxHp[i],
                                active: i == b.enemyActive,
                                translucent: true,
                              ),
                            ),
                          );
                        }),
                      Positioned(
                        left: (playerCenter.dx - 95).clamp(4.0, w - 194.0),
                        top: (playerCenter.dy - playerSize / 2 - 42).clamp(4.0, h - 42),
                        child: const SizedBox(width: 190, child: _PlayerPlate(translucent: true)),
                      ),
                    ],
                    // Entrada: entrenadores lanzando las Poké Balls.
                    if (introActive && enemyN > 0)
                      Positioned.fill(
                        child: HordeIntroOverlay(
                          ms: introMs,
                          female: _trainerFemale(context),
                          tier: b.difficulty.index,
                          seed: b.enemyTeam.first.id,
                          playerTarget: playerCenter,
                          enemyTargets: [
                            for (var i = 0; i < enemyN; i++)
                              hordeCenter(i, enemyN, w, h),
                          ],
                        ),
                      ),
                    // Relevo del jugador: la bola se abre sobre su sitio.
                    if (swapping)
                      Positioned.fill(
                        child: GbaBallPopOverlay(
                          t: swap.value,
                          rival: false,
                          center: playerCenter,
                        ),
                      ),
                    // Un toque salta la entrada con entrenadores.
                    if (introActive)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: b.skipIntro,
                        ),
                      ),
                    // Destello de color (pantalla VS) justo al empezar.
                    if (b.vsFlash)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: VsFlashOverlay(index: b.vsFlashIndex, onDone: b.clearVsFlash),
                        ),
                      ),
                  ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Parpadeo en silueta blanca con la forma real del Pokémon (en vez de un
  /// cuadrado o círculo plano). [strength] 0..1 intensifica el blanco.
  Widget _silhouetteBlink({
    required bool blink,
    required double strength,
    required Widget child,
  }) {
    if (!blink) return child;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.white.withValues(
            alpha: (0.55 + strength * 0.4).clamp(0.0, 0.95)),
        BlendMode.srcATop,
      ),
      child: child,
    );
  }

  String attackerOf(BattleProvider b) => b.lastAttacker;

  double _dash(double a) {
    if (a < 0.3) return 0.0;
    if (a < 0.55) {
      return 60 * math.sin((a - 0.3) / 0.25 * math.pi / 2);
    }
    final t = (a - 0.55) / 0.45;
    return 60 * (1 - t * t);
  }

  /// Miembro i de la horda en formación de arco (fondo = más chico),
  /// con aleteo si es volador/bicho y respiración en los demás.
  /// [lunge]/[hop]: embestida del activo cuando ataca el rival.
  /// [attacking]: anticipación visible (crece + aura).
  Widget _hordeMember({
    required BattleProvider b,
    required int i,
    required double w,
    required double h,
    required double idleT,
    required double shake,
    required double flash,
    required double a,
    double lunge = 0.0,
    double hop = 0.0,
    bool attacking = false,
    double reveal = 1.0,
  }) {
    final slots = hordeSlots(b.enemyTeam.length);
    final slot = slots[i];
    final types =
        b.enemyTeam[i].types.map((t) => t.toLowerCase()).toSet();
    final flying = types.contains('flying') || types.contains('bug');
    final phase = idleT + i * 0.85;
    // Aleteo rápido en voladores, flotación suave en el resto.
    final bob = flying
        ? math.sin(phase * 2) * 4.0
        : math.sin(phase) * 2.5;
    final flap = flying ? math.sin(phase * 2) * 0.07 : 0.0;
    final breathe = flying ? 1.0 : 1.0 + 0.02 * math.sin(phase);
    final size = hordeEnemySize(slot, w, h);
    final fainted = b.enemyTeamHp[i] <= 0;
    final isActive = i == b.enemyActive;
    return Positioned.fill(
      child: Align(
        alignment: Alignment(slot.x, slot.y),
        child: IntroReveal(
          progress: reveal,
          child: Opacity(
          opacity: fainted ? 0.35 : 1.0,
          child: Transform.translate(
            offset: Offset(shake + lunge, bob + hop),
            child: Transform.rotate(
              angle: flap,
              child: Transform.scale(
                scale: breathe * (attacking ? 1.12 : 1.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                if (attacking && !fainted)
                  Container(
                    width: size * 1.05,
                    height: size * 1.05,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorForType(b.lastMoveType)
                          .withValues(alpha: 0.30),
                      boxShadow: [
                        BoxShadow(
                          color: colorForType(b.lastMoveType)
                              .withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                // Al recibir el golpe el rival activo parpadea en silueta
                // blanca (con su forma real, no un círculo plano).
                _silhouetteBlink(
                  blink: flash > 0.05 &&
                      isActive &&
                      ((a - 0.45) * 16).floor().isEven,
                  strength: flash,
                  child: PokeImage(
                    id: b.enemyTeam[i].id,
                    kind: PokeSpriteKind.animatedFront,
                    width: size,
                    height: size,
                    placeholderColor: Colors.white70,
                  ),
                ),
              ],
            ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

/// Pinta el escenario: dunas con textura y plataformas de piedra.
/// Repaint solo si cambia el terreno o el conteo (60 FPS).
class _HordeStagePainter extends CustomPainter {
  final BattleTerrain terrain;
  final int enemyCount;
  const _HordeStagePainter({required this.terrain, this.enemyCount = 3});

  @override
  void paint(Canvas canvas, Size size) {
    // Dunas: bandas con línea de luz arriba y sombra abajo.
    for (var i = 0; i < 5; i++) {
      final t0 = 0.42 + i * 0.115;
      final band = Rect.fromLTWH(
          0, size.height * t0, size.width, size.height * 0.115);
      canvas.drawRect(
        band,
        Paint()
          ..color = (i.isEven
                  ? terrain.floor
                  : shade(terrain.floor, -0.18))
              .withValues(alpha: 0.9),
      );
      canvas.drawRect(
        Rect.fromLTWH(band.left, band.top, band.width, 2),
        Paint()
          ..color = shade(terrain.floor, 0.25).withValues(alpha: 0.7)
          ..isAntiAlias = false,
      );
    }
    // Textura: motas + matas de hierba deterministas.
    final speck = Paint()
      ..color = shade(terrain.floor, -0.35).withValues(alpha: 0.6)
      ..isAntiAlias = false;
    final tuft = Paint()
      ..color = shade(terrain.floor, -0.45).withValues(alpha: 0.8)
      ..isAntiAlias = false;
    for (var i = 0; i < 70; i++) {
      final x = (i * 97.0) % size.width;
      final y =
          size.height * (0.45 + ((i * 53.0) % 55) / 100);
      canvas.drawCircle(Offset(x, y), 1.6, speck);
      if (i % 4 == 0) {
        final tx = (i * 61.0) % size.width;
        final ty =
            size.height * (0.46 + ((i * 29.0) % 50) / 100);
        for (var k = -1; k <= 1; k++) {
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset(tx + k * 3, ty - 3),
                width: 2,
                height: 7 + (i + k).abs() % 4),
            tuft,
          );
        }
      }
    }
    // Plataforma de los rivales: bajo sus pies (los slots van de
    // y≈0.28h al centro a 0.40h en bordes, con pies en ~0.43-0.52h).
    // Ancho según rivales para que el aro los abrace a todos.
    final ringW =
        size.width * (0.30 + 0.16 * enemyCount.clamp(1, 5));
    _platform(
      canvas,
      center: Offset(size.width * 0.50, size.height * 0.52),
      width: ringW,
      height: size.height * 0.22,
    );
    // Arco de primer plano del jugador (abajo-izquierda).
    _platform(
      canvas,
      center: Offset(size.width * 0.22, size.height * 1.04),
      width: size.width * 0.85,
      height: size.height * 0.42,
    );
  }

  /// Plataforma de piedra: sombra, base, anillo claro y baldosas.
  void _platform(Canvas canvas,
      {required Offset center,
      required double width,
      required double height}) {
    final outer = Rect.fromCenter(
        center: center, width: width, height: height);
    canvas.drawOval(
      outer.shift(const Offset(0, 5)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    // Relleno oscuro + aro claro grueso como la referencia.
    canvas.drawOval(outer, Paint()..color = shade(terrain.stands, -0.45));
    canvas.drawOval(
      outer.deflate(width * 0.03),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.drawOval(
      outer.deflate(width * 0.09),
      Paint()..color = terrain.floor.withValues(alpha: 0.95),
    );
    // Baldosas: anillo interior + radios.
    final inner = outer.deflate(width * 0.09);
    final tile = Paint()
      ..color = shade(terrain.floor, -0.22).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(inner.deflate(width * 0.06), tile);
    for (var k = 0; k < 6; k++) {
      final ang = math.pi * k / 6;
      canvas.drawLine(
        Offset(inner.center.dx - math.cos(ang) * inner.width / 2,
            inner.center.dy - math.sin(ang) * inner.height / 2),
        Offset(inner.center.dx + math.cos(ang) * inner.width / 2,
            inner.center.dy + math.sin(ang) * inner.height / 2),
        tile,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HordeStagePainter old) =>
      old.terrain.id != terrain.id || old.enemyCount != enemyCount;
}

/// Placa retro de un rival: escudo, nombre, Nv. 50 y barra.
class _HordePlate extends StatelessWidget {
  final String name;
  final int hp;
  final int maxHp;
  final bool active;
  final bool translucent;
  const _HordePlate({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.active,
    this.translucent = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxHp <= 0 ? 0.0 : hp / maxHp;
    final color =
        pct > 0.5 ? Colors.green : pct > 0.2 ? Colors.orange : Colors.red;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: translucent
            ? scheme.surfaceContainerHighest.withValues(alpha: _kHordeOverlayAlpha)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? Colors.amber : scheme.outlineVariant,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield,
                  color: scheme.onSurfaceVariant, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$name  Nv. 50',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            width: 120,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placa del jugador: escudo, nombre, barra, iconos de tipo y PS.
class _PlayerPlate extends StatelessWidget {
  final bool translucent;
  const _PlayerPlate({this.translucent = false});

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();
    final p = b.player!;
    final pct =
        b.playerMaxHp <= 0 ? 0.0 : b.playerHp / b.playerMaxHp;
    final color =
        pct > 0.5 ? Colors.green : pct > 0.2 ? Colors.orange : Colors.red;
    final scheme = Theme.of(context).colorScheme;
    return Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: translucent
              ? scheme.surfaceContainerHighest.withValues(alpha: _kHordeOverlayAlpha)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield,
                    color: scheme.onSurfaceVariant, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${prettyName(p.name)}  Nv. 50',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Container(
              width: 160,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(5),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in p.types)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colorForType(t),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white70),
                    ),
                    child: Center(
                      child: Text(
                        t.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                Text(
                  '${b.playerHp} / ${b.playerMaxHp}',
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      );
  }
}

/// Menú 2x2 de colores estilo Gen 5: Luchar / Mochila / Pokémon / Huir.
class _HordeMenu extends StatelessWidget {
  final String menu;
  final bool compact;

  /// Botones más pequeños y sin subtítulo (columna derecha en horizontal).
  final bool dense;
  final bool translucent;
  final ValueChanged<String> onPick;
  const _HordeMenu(
      {required this.menu,
      required this.compact,
      required this.onPick,
      this.dense = false,
      this.translucent = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: dense ? 2.6 : (compact ? 2.5 : 2.9),
        children: [
          _menuBtn(context, 'fight', 'LUCHAR', 'Elige tu ataque.',
              const Color(0xFFD32F2F), Icons.bolt),
          _menuBtn(context, 'bag', 'MOCHILA', 'Usa un objeto.',
              const Color(0xFFF9A825), Icons.backpack),
          _menuBtn(context, 'mon', 'POKÉMON', 'Cambia de Pokémon.',
              const Color(0xFF388E3C), Icons.catching_pokemon),
          _menuBtn(context, 'run', 'HUIR', 'Escapa del combate.',
              const Color(0xFF1976D2), Icons.directions_run),
        ],
      ),
    );
  }

  Widget _menuBtn(BuildContext ctx, String id, String title, String sub,
      Color color, IconData icon) {
    final sel = menu == id;
    return GestureDetector(
      onTap: () {
        if (id == 'run') {
          _confirmRun(ctx);
          return;
        }
        onPick(id);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 10, vertical: dense ? 4 : 6),
        decoration: BoxDecoration(
          color: translucent
              ? color.withValues(alpha: _kHordeOverlayAlpha)
              : (sel ? color.withValues(alpha: 0.75) : color),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? Colors.white : Colors.black26,
            width: sel ? 2.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: dense ? 12 : 15,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 2),
                          ])),
                  if (!dense)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
            Icon(icon, color: Colors.white, size: dense ? 22 : 30),
          ],
        ),
      ),
    );
  }

  void _confirmRun(BuildContext context) {
    final b = context.read<BattleProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Huir del combate?'),
        content: const Text('La horda se quedará con el terreno.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Quedarse'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              b.backToSelect();
            },
            child: const Text('Huir'),
          ),
        ],
      ),
    );
  }
}

/// Panel contextual sobre el menú (movimientos con PP, poción, banca, Z).
class _MenuPanel extends StatelessWidget {
  final String menu;
  final VoidCallback onClose;
  final bool translucent;
  const _MenuPanel({required this.menu, required this.onClose, this.translucent = false});

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();
    if (menu == 'none') return const SizedBox.shrink();
    final busy = b.busy || b.botThinking || b.entering;
    Widget body;
    if (menu == 'fight') {
      body = Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < b.playerMoves.length; i++)
            Builder(builder: (context) {
              final m = b.playerMoves[i];
              final left = (b.playerPp.isNotEmpty &&
                      b.playerActive < b.playerPp.length &&
                      i < b.playerPp[b.playerActive].length)
                  ? b.playerPp[b.playerActive][i]
                  : m.maxPp;
              return FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: colorForType(m.type)
                      .withValues(alpha: left <= 0 ? 0.12 : 0.30),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                ),
                onPressed: busy || left <= 0
                    ? null
                    : () {
                        BattleSound.playSelect();
                        onClose();
                        b.playerAttack(m);
                      },
                child: Text('${m.name} (${m.power}) · $left',
                    style: const TextStyle(fontSize: 12)),
              );
            }),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: b.playerCharge >= 100
                  ? Colors.amber
                  : Colors.grey.shade700,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed:
                busy || b.playerCharge < 100 ? null : b.playerUltimate,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(
              b.playerCharge >= 100
                  ? '¡Z! (120)'
                  : 'Z ${b.playerCharge.round()}%',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      );
    } else if (menu == 'bag') {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonalIcon(
            onPressed: busy || b.playerPotions <= 0 ? null : b.usePotion,
            icon: const Icon(Icons.medication, size: 18),
            label: Text('Poción x${b.playerPotions} (cura 40%)'),
          ),
          if (b.playerPotions <= 0)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Sin pociones: se recargan en cada batalla.',
                style: TextStyle(fontSize: 11),
              ),
            ),
        ],
      );
    } else {
      body = Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < b.playerTeam.length; i++)
            ChoiceChip(
              label: Text(
                '${prettyName(b.playerTeam[i].name)} '
                '(${b.playerTeamHp[i]}/${b.playerTeamMaxHp[i]})',
                style: const TextStyle(fontSize: 11),
              ),
              selected: i == b.playerActive,
              onSelected: b.playerTeamHp[i] <= 0 ||
                      i == b.playerActive ||
                      busy
                  ? null
                  : (_) {
                      onClose();
                      b.switchPlayerFighter(i);
                    },
            ),
        ],
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: translucent ? _kHordeOverlayAlpha : 0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: body,
    );
  }
}
