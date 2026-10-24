import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/pokemon.dart';
import '../../../core/theme/type_colors.dart';
import '../../../core/widgets/poke_image.dart';
import '../battle_fx.dart';
import '../battle_hints.dart';
import '../battle_fx_extra.dart';
import '../battle_provider.dart';
import '../battle_terrain.dart';
import '../../settings/settings_provider.dart';
import '../vs_intro.dart';
import 'gba_intro.dart';
import 'gba_sprites.dart';
import 'gba_touch_menu.dart' show effectivenessColor;

/// Viewport GBA ampliado: escena del terreno elegido, placas HP siempre
/// visibles, proyectil según el tipo del poder + estallido al impactar.
/// Solo presenta estado del [BattleProvider]; la navegación vive en
/// [GbaEmulatorScreen]. Funciona igual en local y online porque el efecto
/// se deriva de la acción ya sincronizada (attackSeq/lastMoveType).
class GbaViewport extends StatefulWidget {
  final int menuCursor;
  final bool inMoves;
  final int moveCursor;
  final bool menuOpen;

  /// Pantalla completa con controles encima: el cuadro de diálogo es
  /// translúcido y deja [dialogueInset] px de diseño libres a la derecha.
  final bool overlay;
  final double dialogueInset;

  /// Oculta el cuadro de diálogo (cuando el menú táctil ocupa su lugar).
  final bool hideDialogue;

  /// Llave opcional de la placa HP del jugador, para que el tutorial de
  /// foco de luz encuentre su posición real en pantalla.
  final GlobalKey? playerHpKey;
  const GbaViewport({
    super.key,
    required this.menuCursor,
    required this.inMoves,
    required this.moveCursor,
    required this.menuOpen,
    this.overlay = false,
    this.dialogueInset = 0,
    this.hideDialogue = false,
    this.playerHpKey,
  });

  @override
  State<GbaViewport> createState() => _GbaViewportState();
}

class _GbaViewportState extends State<GbaViewport>
    with TickerProviderStateMixin {
  late final AnimationController _atk;
  late final AnimationController _idle;
  // Entrada con entrenadores (solo cuando el provider la pide).
  late final AnimationController _intro;
  bool _introRunning = false;
  // Pokémon que entra a mitad del combate (cambio o relevo tras un KO): sale
  // de una Poké Ball. Terminados valen 1 (= completo).
  late final AnimationController _swapP;
  late final AnimationController _swapE;
  int? _prevPlayerActive;
  int? _prevEnemyActive;
  int _prevSeq = 0;

  @override
  void initState() {
    super.initState();
    _swapP = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 600),
    );
    _swapE = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 600),
    );
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: IntroTimeline.total),
    );
    // Vuelo del proyectil rápido (~0.8s) como antes.
    _atk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Fondo vivo continuo (nubes, brasas, olas...).
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _atk.dispose();
    _idle.dispose();
    _intro.dispose();
    _swapP.dispose();
    _swapE.dispose();
    super.dispose();
  }

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
    // Re-dispara el vuelo del proyectil con cada golpe nuevo
    // (mismo patrón que la vista moderna).
    if (b.attackSeq != _prevSeq) {
      _prevSeq = b.attackSeq;
      if (b.attackSeq > 0) _atk.forward(from: 0);
    }
    final player = b.player!;
    final enemy = b.enemy!;
    final attackerIsPlayer = b.lastAttacker == 'player';
    final enemyFainted = b.enemyHp <= 0;
    final playerFainted = b.playerHp <= 0;
    final wave = _idle.value * 2 * math.pi;

    // Entrada con entrenadores: arranca con `entering` y termina con él (si
    // se salta, el provider apaga `entering` y todo queda completo).
    final introActive = b.introRich && b.entering;
    if (introActive && !_introRunning) {
      _introRunning = true;
      _intro.forward(from: 0);
    } else if (!introActive && _introRunning) {
      _introRunning = false;
      _intro.value = 1;
    }

    // Relevo a mitad del combate: el Pokémon nuevo sale de una Poké Ball.
    // Solo en la vista Normal con entrada de entrenadores (`introRich`): Online
    // y 2.5D no cambian.
    if (b.introRich && !introActive) {
      if (_prevPlayerActive != null && _prevPlayerActive != b.playerActive) {
        _swapP.forward(from: 0);
      }
      if (_prevEnemyActive != null && _prevEnemyActive != b.enemyActive) {
        _swapE.forward(from: 0);
      }
    }
    _prevPlayerActive = b.playerActive;
    _prevEnemyActive = b.enemyActive;

    return AnimatedBuilder(
      animation: Listenable.merge([_atk, _idle, _intro, _swapP, _swapE]),
      builder: (context, _) {
        final introMs = introActive
            ? _intro.value * IntroTimeline.total
            : double.infinity;
        final playerReveal = introActive
            ? IntroTimeline.playerReveal(introMs)
            : (_swapP.isAnimating ? BallPop.reveal(_swapP.value) : 1.0);
        final rivalReveal = introActive
            ? IntroTimeline.rivalReveal(introMs)
            : (_swapE.isAnimating ? BallPop.reveal(_swapE.value) : 1.0);
        final platesOpacity = introActive
            ? IntroTimeline.platesOpacity(introMs)
            : 1.0;
        // Sin golpes aún: animación en reposo (overlays ocultos).
        final a = b.attackSeq == 0 ? 1.0 : _atk.value;
        final attacking = b.attackSeq > 0 && a < 1.0;
        final hit = b.attackSeq > 0 && a > 0.5 && a < 0.92;
        final moveColor = colorForType(b.lastMoveType);
        final chatMine = b.chatText.isNotEmpty && b.chatSlot == b.chatMySlot;
        final chatOpp =
            b.chatText.isNotEmpty &&
            b.chatSlot != b.chatMySlot &&
            b.chatSlot >= 0;
        // Sacudida de pantalla proporcional al golpe (solo durante el impacto).
        final defenderMaxHp = attackerIsPlayer ? b.enemyMaxHp : b.playerMaxHp;
        final shake = attacking
            ? ScreenShake.offset(
                a,
                ScreenShake.amplitude(
                  damage: b.lastDamage,
                  defenderMaxHp: defenderMaxHp,
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
        return Transform.translate(
          offset: shake,
          child: Stack(
            children: [
              // Fondo vivo del terreno GBA elegido (lista propia de 10).
              Positioned.fill(
                child: CustomPaint(
                  painter: _GbaTerrainPainter(
                    terrain: b.gbaTerrain,
                    time: wave,
                  ),
                ),
              ),
              // Rival (derecha, sobre el montículo).
              Positioned(
                right: 20,
                top: 68,
                child: IntroReveal(
                  progress: rivalReveal,
                  child: _GbaFighter(
                    id: enemy.id,
                    kind: PokeSpriteKind.animatedFront,
                    size: 72,
                    isPlayerSide: false,
                    b: b,
                    fainted: enemyFainted,
                  ),
                ),
              ),
              // Jugador (izquierda, de espaldas).
              Positioned(
                left: 10,
                bottom: 64,
                child: IntroReveal(
                  progress: playerReveal,
                  child: _GbaFighter(
                    id: player.id,
                    kind: PokeSpriteKind.animatedBack,
                    size: 94,
                    isPlayerSide: true,
                    b: b,
                    fainted: playerFainted,
                  ),
                ),
              ),
              // Entrada: entrenadores lanzando las Poké Balls (sobre los Pokémon).
              if (introActive)
                Positioned.fill(
                  child: GbaIntroOverlay(
                    ms: introMs,
                    female: _trainerFemale(context),
                    tier: b.difficulty.index,
                    seed: b.enemyTeam.isEmpty ? 0 : b.enemyTeam.first.id,
                  ),
                ),
              // Bola que se abre sobre el Pokémon que entra a mitad del combate.
              if (!introActive && _swapP.isAnimating)
                Positioned.fill(
                  child: GbaBallPopOverlay(t: _swapP.value, rival: false),
                ),
              if (!introActive && _swapE.isAnimating)
                Positioned.fill(
                  child: GbaBallPopOverlay(t: _swapE.value, rival: true),
                ),
              // Placa HP rival sobre su cabeza (arriba-derecha).
              Positioned(
                right: 8,
                top: 6,
                child: Opacity(
                  opacity: platesOpacity,
                  child: _HpPlate(
                    name: prettyName(enemy.name),
                    hp: b.enemyHp,
                    maxHp: b.enemyMaxHp,
                  ),
                ),
              ),
              // Placa HP jugador sobre su cabeza (arriba-izquierda).
              Positioned(
                left: 8,
                top: 6,
                child: Opacity(
                  opacity: platesOpacity,
                  child: _HpPlate(
                    key: widget.playerHpKey,
                    name: prettyName(player.name),
                    hp: b.playerHp,
                    maxHp: b.playerMaxHp,
                    expFrac: (b.playerCharge / 100).clamp(0.0, 1.0),
                  ),
                ),
              ),
              // Suplentes del rival (hasta 3) bajo su placa HP.
              Positioned(
                right: 8,
                top: 42,
                child: Opacity(
                  opacity: platesOpacity,
                  child: _BenchRow(
                    team: b.enemyTeam,
                    hps: b.enemyTeamHp,
                    active: b.enemyActive,
                  ),
                ),
              ),
              // Suplentes propios (hasta 3) bajo nuestra placa HP.
              Positioned(
                left: 8,
                top: 42,
                child: Opacity(
                  opacity: platesOpacity,
                  child: _BenchRow(
                    team: b.playerTeam,
                    hps: b.playerTeamHp,
                    active: b.playerActive,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      b.gbaTerrain.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              // Chat del rival: bocadillo desde su boca (bajo su cinta).
              if (chatOpp)
                Positioned(
                  top: 74,
                  right: 8,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: SpeechBubble(
                      text: b.chatText,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              // Mi chat: bocadillo sobre mi avatar.
              if (chatMine)
                Positioned(
                  left: 8,
                  bottom: 186,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: SpeechBubble(text: b.chatText, color: Colors.green),
                  ),
                ),
              // Proyectil del poder volando atacante → defensor.
              if (attacking && a <= 0.5)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.lerp(
                      attackerIsPlayer
                          ? const Alignment(-0.7, 0.6)
                          : const Alignment(0.7, -0.6),
                      attackerIsPlayer
                          ? const Alignment(0.7, -0.6)
                          : const Alignment(-0.7, 0.6),
                      (a / 0.5).clamp(0.0, 1.0),
                    )!,
                    child: MoveProjectile(
                      type: b.lastMoveType,
                      color: moveColor,
                      progress: (a / 0.5).clamp(0.0, 1.0),
                      size: 40,
                    ),
                  ),
                ),
              // Destello blanco en el pico del impacto.
              if (hit && a < 0.68)
                Positioned.fill(
                  child: Opacity(
                    opacity: ((0.68 - a) / 0.18).clamp(0.0, 1.0) * 0.35,
                    child: Container(color: Colors.white),
                  ),
                ),
              // Estallido + daño en el que recibe.
              if (hit)
                Positioned.fill(
                  child: Align(
                    alignment: attackerIsPlayer
                        ? const Alignment(0.62, -0.5)
                        : const Alignment(-0.62, 0.4),
                    child: ImpactBurst(
                      color: moveColor,
                      t: (a - 0.5) / 0.4,
                      size: 84,
                    ),
                  ),
                ),
              // Sprites FRLG del tipo del movimiento esparcidos al impactar.
              if (hit && !b.lastMiss)
                Positioned.fill(
                  child: Align(
                    alignment: attackerIsPlayer
                        ? const Alignment(0.62, -0.5)
                        : const Alignment(-0.62, 0.4),
                    child: SpriteBurst(
                      type: b.lastMoveType,
                      t: ((a - 0.5) / 0.42).clamp(0.0, 1.0),
                      size: 110,
                      count: burstCount(
                        crit: b.lastCrit,
                        effectiveness: b.lastEffectiveness,
                      ),
                    ),
                  ),
                ),
              // Banner de efectividad / crítico.
              if (banner != null && attacking && a > 0.55)
                Positioned(
                  top: 92,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: ((1.0 - a) / 0.35).clamp(0.0, 1.0),
                    child: Text(
                      banner,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: b.lastEffectiveness >= 2
                            ? Colors.amberAccent
                            : Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 3),
                          Shadow(color: Colors.black, offset: Offset(1, 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (attacking && a > 0.42)
                Positioned(
                  top: attackerIsPlayer ? 100 : null,
                  bottom: attackerIsPlayer ? null : 160,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: ((1.0 - a) / 0.58).clamp(0.0, 1.0),
                    child: Text(
                      b.lastMiss ? '¡FALLO!' : '-${b.lastDamage}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20 + (1.0 - a) * 10,
                        fontWeight: FontWeight.w900,
                        color: b.lastEffectiveness >= 2.0
                            ? Colors.deepOrange
                            : Colors.red.shade700,
                        shadows: const [
                          Shadow(color: Colors.white, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              // (El menú vive en la capa flotante arrastrable de la pantalla.)
              // Cuadro de diálogo dentro de la pantalla.
              if (!widget.hideDialogue || introActive)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _DialogueBox(
                    overlay: widget.overlay,
                    rightInset: introActive ? 0 : widget.dialogueInset,
                    text: introActive
                        ? _introText(b, introMs)
                        : _dialogueFor(b, widget.menuOpen, widget.inMoves),
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
                  child: VsFlashOverlay(index: b.vsFlashIndex, onDone: b.clearVsFlash),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Texto del cuadro de diálogo mientras dura la entrada con entrenadores.
  String _introText(BattleProvider b, double ms) {
    if (ms < IntroTimeline.landAt) return '¡El Bot te desafía a un combate!';
    return '¡Adelante, ${prettyName(b.player!.name)}!';
  }

  String _dialogueFor(BattleProvider b, bool menuOpen, bool inMoves) {
    if (b.entering) return b.log.isNotEmpty ? b.log.last : '¡Que comience!';
    if (b.winner != null) {
      return b.log.isNotEmpty
          ? b.log.last
          : (b.winner == 'player' ? '¡Ganaste!' : 'Perdiste...');
    }
    if (b.busy || b.botThinking) {
      return b.log.isNotEmpty ? b.log.last : '...';
    }
    if (!menuOpen) return 'Pulsa START';
    if (inMoves) return '¡Elige un ataque!';
    return '¿Qué debe hacer ${prettyName(b.player!.name)}?';
  }
}

/// Luchador con embestida al atacar y sacudida+destello al recibir.
/// Se re-dispara con cada [BattleProvider.attackSeq].
/// Al debilitarse ([fainted]) se desvanece con parpadeo y se hunde.
/// Cinta del equipo (hasta 3 por lado): miniaturas de alta resolución
/// de todos, activo resaltado en ámbar y debilitado con ✖ roja.
/// Solo visual: el cambio se hace desde el menú POKÉMON.
class _BenchRow extends StatelessWidget {
  final List<PokemonDetail> team;
  final List<int> hps;
  final int active;
  const _BenchRow({
    required this.team,
    required this.hps,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final minis = <Widget>[];
    for (var i = 0; i < team.length && minis.length < 3; i++) {
      final isActive = i == active;
      final fainted = i >= hps.length || hps[i] <= 0;
      minis.add(
        Opacity(
          opacity: fainted && !isActive ? 0.45 : 1.0,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive
                    ? Colors.amber
                    : fainted
                    ? Colors.redAccent
                    : Colors.white70,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                PokeImage(
                  id: team[i].id,
                  kind: PokeSpriteKind.artwork,
                  width: 28,
                  height: 28,
                  cacheWidth: 96,
                  placeholderColor: Colors.white70,
                ),
                if (fainted)
                  const Icon(Icons.close, size: 20, color: Colors.redAccent),
              ],
            ),
          ),
        ),
      );
    }
    if (minis.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < minis.length; k++) ...[
          if (k > 0) const SizedBox(width: 4),
          minis[k],
        ],
      ],
    );
  }
}

class _GbaFighter extends StatelessWidget {
  final int id;
  final PokeSpriteKind kind;
  final double size;
  final bool isPlayerSide;
  final BattleProvider b;
  final bool fainted;
  const _GbaFighter({
    required this.id,
    required this.kind,
    required this.size,
    required this.isPlayerSide,
    required this.b,
    this.fainted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (fainted) {
      // KO: parpadea 3 veces mientras se hunde y se apaga.
      return TweenAnimationBuilder<double>(
        key: ValueKey('faint-$id'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, _) {
          final blink = (t * 6).floor().isEven ? 1.0 : 0.2;
          return Opacity(
            opacity: ((1 - t) * blink).clamp(0.05, 1.0),
            child: Transform.translate(
              offset: Offset(0, t * 30),
              child: PokeImage(
                id: id,
                kind: kind,
                width: size,
                height: size,
                placeholderColor: Colors.white70,
              ),
            ),
          );
        },
      );
    }
    final attacking =
        b.attackSeq > 0 && (b.lastAttacker == 'player') == isPlayerSide;
    final defending =
        b.attackSeq > 0 && (b.lastAttacker == 'player') != isPlayerSide;
    final dir = isPlayerSide ? 1.0 : -1.0;
    return TweenAnimationBuilder<double>(
      key: ValueKey('gba-$id-${b.attackSeq}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, t, _) {
        double dx = 0;
        double dy = 0;
        double flash = 0;
        if (attacking && t < 1.0) {
          dx = math.sin(t * math.pi) * 22 * dir;
          dy = -math.sin(t * math.pi) * 8;
        }
        if (defending && t > 0.35) {
          dx = math.sin((t - 0.35) * 40) * 6 * (1 - t);
          if (t > 0.35 && t < 0.85) flash = 1 - (t - 0.35) / 0.5;
        }
        // Al recibir el golpe parpadea en silueta blanca (con la forma real
        // del Pokémon, no un cuadrado) y retrocede un poco.
        final blinkWhite = flash > 0.05 && ((t - 0.35) * 14).floor().isEven;
        Widget sprite = PokeImage(
          id: id,
          kind: kind,
          width: size,
          height: size,
          placeholderColor: Colors.white70,
        );
        if (blinkWhite) {
          sprite = ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.white.withValues(
                alpha: (0.55 + flash * 0.4).clamp(0.0, 0.95),
              ),
              BlendMode.srcATop,
            ),
            child: sprite,
          );
        }
        return Transform.translate(offset: Offset(dx, dy), child: sprite);
      },
    );
  }
}

/// Placa HP crema estilo retro, compacta: nombre, barra por tramos y
/// cantidad numérica en ambos lados (+ barra EXP en el jugador).
class _HpPlate extends StatelessWidget {
  final String name;
  final int hp;
  final int maxHp;
  final double? expFrac;
  const _HpPlate({
    super.key,
    required this.name,
    required this.hp,
    required this.maxHp,
    this.expFrac,
  });

  @override
  Widget build(BuildContext context) {
    final frac = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
    final color = frac > 0.5
        ? const Color(0xFF58B368)
        : frac > 0.2
        ? const Color(0xFFE8C547)
        : const Color(0xFFD64545);
    return Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F0C8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black87, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Lv50',
                style: TextStyle(fontSize: 8, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Text(
                'HP',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.black87, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: frac,
                      backgroundColor: Colors.grey.shade300,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$hp/$maxHp',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              if (expFrac != null) ...[
                const Text(
                  'EXP',
                  style: TextStyle(fontSize: 7, color: Colors.black87),
                ),
                const SizedBox(width: 3),
                SizedBox(
                  width: 40,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: expFrac,
                      backgroundColor: Colors.grey.shade300,
                      color: const Color(0xFF4A90D9),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Panel moderno flotante de comandos: acciones, ataques (nombre + PP
/// + tipo), mochila y equipo con cursor. Lo dibuja la pantalla
/// ([GbaEmulatorScreen]) para poder arrastrarlo por toda la pantalla
/// sin recortes del viewport.
class GbaRetroMenu extends StatelessWidget {
  final BattleProvider b;
  final int menuCursor;
  final int mode; // 0 acciones, 1 ataques, 2 mochila, 3 pokémon
  final int subCursor;

  /// Toques directos (opcionales): acción 0..3, ataque i y "regresar".
  final ValueChanged<int>? onAction;
  final ValueChanged<int>? onMove;
  final VoidCallback? onBack;
  const GbaRetroMenu({
    super.key,
    required this.b,
    required this.menuCursor,
    required this.mode,
    required this.subCursor,
    this.onAction,
    this.onMove,
    this.onBack,
  });

  static final _actions = [
    ('LUCHAR', Icons.sports_mma),
    ('MOCHILA', Icons.backpack),
    ('POKÉMON', Icons.catching_pokemon),
    ('HUIR', Icons.logout),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2430),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
      ),
      child: switch (mode) {
        1 => _movesGrid(),
        2 => _bagGrid(),
        3 => _partyGrid(),
        _ => _actionsGrid(),
      },
    );
  }

  /// Cuadrícula principal: las 4 acciones con iconos.
  Widget _actionsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        mainAxisExtent: 38,
      ),
      itemCount: _actions.length,
      itemBuilder: (context, i) {
        final selected = i == menuCursor;
        final tile = Container(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3A4356) : const Color(0xFF2A3140),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? Colors.amber : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _actions[i].$2,
                size: 16,
                color: selected ? Colors.amber : Colors.white70,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _actions[i].$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        return onAction == null
            ? tile
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onAction!(i),
                child: tile,
              );
      },
    );
  }

  /// Cuadrícula de movimientos: nombre + PP + tipo, y REGRESAR.
  Widget _movesGrid() {
    final moves = b.playerMoves;
    final ultReady = b.playerCharge >= 100;
    final count = moves.length + (ultReady ? 1 : 0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            mainAxisExtent: 68,
          ),
          itemCount: count,
          itemBuilder: (context, i) {
            final selected = i == subCursor;
            if (i < moves.length) {
              final m = moves[i];
              return _moveCard(
                name: m.name,
                pp: _ppLabel(b, i),
                type: m.type,
                color: colorForType(m.type),
                selected: selected,
                eff: b.moveEffectiveness(m),
                star: b.recommendedPlayerMove == i,
                showHints: true,
                onTap: onMove == null ? null : () => onMove!(i),
              );
            }
            return _moveCard(
              name: '¡MOV. Z!',
              pp: 'Z 100%',
              type: 'stellar',
              color: Colors.amber,
              selected: selected,
              onTap: onMove == null ? null : () => onMove!(i),
            );
          },
        ),
        const SizedBox(height: 6),
        _backRow(),
      ],
    );
  }

  /// Mochila: poción disponible (cura 40% y cede el turno).
  Widget _bagGrid() {
    final selected = subCursor == 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3A4356) : const Color(0xFF2A3140),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Colors.amber : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.medication, size: 18, color: Colors.greenAccent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'POCIÓN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'x${b.playerPotions}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cura 40% y cede el turno',
          style: TextStyle(fontSize: 9, color: Colors.white54),
        ),
        const SizedBox(height: 6),
        _backRow(),
      ],
    );
  }

  /// Equipo: elige quién pelea (solo sanos y no activos).
  Widget _partyGrid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            mainAxisExtent: 54,
          ),
          itemCount: b.playerTeam.length,
          itemBuilder: (context, i) {
            final p = b.playerTeam[i];
            final hp = (i < b.playerTeamHp.length) ? b.playerTeamHp[i] : 0;
            final maxHp = (i < b.playerTeamMaxHp.length)
                ? b.playerTeamMaxHp[i]
                : 1;
            final selected = i == subCursor;
            final active = i == b.playerActive;
            final fainted = hp <= 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF3A4356)
                    : const Color(0xFF2A3140),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? Colors.greenAccent
                      : selected
                      ? Colors.amber
                      : Colors.white24,
                  width: (active || selected) ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    prettyName(p.name).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: fainted ? Colors.white38 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    active
                        ? 'EN BATALLA'
                        : fainted
                        ? 'DEBILITADO'
                        : 'PS $hp/$maxHp',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: active
                          ? Colors.greenAccent
                          : fainted
                          ? Colors.redAccent
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        _backRow(),
      ],
    );
  }

  /// Pie con REGRESAR (equivale a B).
  Widget _backRow() {
    final row = const Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.undo, size: 16, color: Colors.white70),
            SizedBox(width: 4),
            Text(
              'REGRESAR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
    return onBack == null
        ? row
        : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onBack, child: row);
  }

  Widget _moveCard({
    required String name,
    required String pp,
    required String type,
    required Color color,
    required bool selected,
    double eff = 1.0,
    bool star = false,
    bool showHints = false,
    VoidCallback? onTap,
  }) {
    final tier = effectivenessTier(eff);
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF3A4356) : const Color(0xFF2A3140),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: star
              ? Colors.amber
              : selected
                  ? Colors.amber
                  : Colors.white24,
          width: selected || star ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              if (star) const Icon(Icons.star, size: 12, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 1),
          Row(
            children: [
              Expanded(
                child: Text(
                  'PP: $pp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (showHints) ...[
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: effectivenessColor(tier),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                effectivenessLabel(eff),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null ? card : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }

  String _ppLabel(BattleProvider b, int i) {
    final m = b.playerMoves[i];
    var left = m.maxPp;
    if (b.playerPp.isNotEmpty &&
        b.playerActive < b.playerPp.length &&
        i < b.playerPp[b.playerActive].length) {
      left = b.playerPp[b.playerActive][i];
    }
    return '$left/${m.maxPp}';
  }
}

/// Cuadro de diálogo verde-azulado con borde naranja (dentro del juego).
class _DialogueBox extends StatelessWidget {
  final String text;
  final bool overlay;
  final double rightInset;
  const _DialogueBox({required this.text, this.overlay = false, this.rightInset = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: EdgeInsets.fromLTRB(10, 6, 10 + rightInset, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A525A).withValues(alpha: overlay ? 0.6 : 1),
        border: Border.all(
          color: const Color(0xFFE76343).withValues(alpha: overlay ? 0.75 : 1),
          width: 3,
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      ),
    );
  }
}

/// Fondo detallado del terreno con estética retro pero rica: cielo en
/// 3 bandas con sol/luna, cordilleras lejanas, decoración propia animada
/// (árboles, olas, brasas, rayos), suelo texturizado, sombras bajo cada
/// luchador y montículo sombreado del rival.
/// [time] avanza continuo para el movimiento natural del fondo.
/// Reutiliza [BattleTerrain] para que local y online vean lo mismo.
class _GbaTerrainPainter extends CustomPainter {
  final BattleTerrain terrain;
  final double time;
  const _GbaTerrainPainter({required this.terrain, this.time = 0});

  static final Paint _platformPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    _sky(canvas, size);
    _mountains(canvas, size);
    // Decoración propia de cada terreno (todo por código).
    switch (terrain.id) {
      case 'grass':
        _trees(canvas, size);
      case 'beach':
        _waves(canvas, size);
      case 'volcano':
        _embers(canvas, size);
      case 'electric':
        _sparks(canvas, size);
      case 'gba-playa':
        _waves(canvas, size);
      case 'gba-bosque':
        _trees(canvas, size);
      case 'gba-noche':
        _fireflies(canvas, size);
      case 'gba-volcan':
        _embers(canvas, size);
      case 'gba-nieve':
        _snowfall(canvas, size);
      case 'gba-desierto':
        _sand(canvas, size);
      case 'gba-jungla':
        _trees(canvas, size);
        _fireflies(canvas, size);
      case 'gba-montana':
        _trees(canvas, size);
        _snowfall(canvas, size);
      case 'gba-atardecer':
        _birds(canvas, size);
      case 'gba-tormenta':
        _rain(canvas, size);
    }
    _ground(canvas, size);
  }

  /// Cielo en 3 bandas + sol con resplandor o luna con cráteres.
  void _sky(Canvas canvas, Size size) {
    final mid = Color.lerp(terrain.skyTop, terrain.skyBottom, 0.5)!;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [terrain.skyTop, mid, terrain.skyBottom],
        stops: const [0.0, 0.45, 0.75],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    if (terrain.night) {
      // Luna con cráteres arriba-izquierda.
      final moon = Offset(size.width * 0.2, size.height * 0.14);
      canvas.drawCircle(
        moon,
        16,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
      canvas.drawCircle(moon, 12, Paint()..color = const Color(0xFFF4F1DE));
      canvas.drawCircle(
        Offset(moon.dx - 4, moon.dy - 3),
        3,
        Paint()..color = const Color(0xFFD8D3C0),
      );
      canvas.drawCircle(
        Offset(moon.dx + 4, moon.dy + 4),
        2.2,
        Paint()..color = const Color(0xFFD8D3C0),
      );
      // Estrellas titilantes.
      for (var i = 0; i < 26; i++) {
        final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(time * 2 + i * 1.7));
        canvas.drawCircle(
          Offset((i * 53.0) % size.width, (i * 29.0) % (size.height * 0.4)),
          1.4,
          Paint()..color = Colors.white.withValues(alpha: tw * 0.8),
        );
      }
    } else {
      // Sol con resplandor arriba-derecha.
      final sun = Offset(size.width * 0.82, size.height * 0.13);
      canvas.drawCircle(
        sun,
        22,
        Paint()..color = Colors.yellow.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        sun,
        14,
        Paint()..color = Colors.yellow.withValues(alpha: 0.85),
      );
      canvas.drawCircle(sun, 10, Paint()..color = const Color(0xFFFFF3B0));
      // Nubes a la deriva (doble óvalo cada una).
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.75);
      for (var i = 0; i < 3; i++) {
        final cx =
            ((i * 0.37 + time * 0.02 * (1 + i * 0.3)) % 1.3 - 0.15) *
            size.width;
        final cy = size.height * (0.08 + (i % 2) * 0.06);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: 46, height: 12),
          cloud,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + 10, cy - 5),
            width: 26,
            height: 10,
          ),
          cloud,
        );
      }
    }
  }

  /// Dos cordilleras en silueta para dar profundidad.
  void _mountains(Canvas canvas, Size size) {
    final base = size.height * 0.62;
    final far = Paint()..color = terrain.skyBottom.withValues(alpha: 0.75);
    final fp = Path()..moveTo(0, base);
    for (var i = 0; i <= 6; i++) {
      fp.lineTo(
        size.width * i / 6,
        base - size.height * (0.10 + ((i * 37) % 10) / 100),
      );
      fp.lineTo(size.width * (i + 0.5) / 6, base - size.height * 0.02);
    }
    fp.lineTo(size.width, base);
    fp.close();
    canvas.drawPath(fp, far);
    final near = Paint()..color = terrain.stands.withValues(alpha: 0.55);
    final np = Path()..moveTo(0, base + 8);
    for (var i = 0; i <= 4; i++) {
      np.lineTo(
        size.width * i / 4,
        base + 8 - size.height * (0.05 + ((i * 53) % 7) / 100),
      );
      np.lineTo(size.width * (i + 0.5) / 4, base + 8);
    }
    np.lineTo(size.width, base + 8);
    np.close();
    canvas.drawPath(np, near);
  }

  /// Suelo texturizado + sombras de los luchadores + montículo sombreado.
  void _ground(Canvas canvas, Size size) {
    final sheet = GbaSprites.platforms;
    final src = GbaPlatforms.forTerrain(terrain.id);

    final ground = Offset(size.width / 2, size.height * 0.78);
    // Piso general: wash de color plano, terreno normal (sin sprite aquí;
    // es demasiado ancho para que una plataforma se vea bien estirada).
    canvas.drawOval(
      Rect.fromCenter(
        center: ground,
        width: size.width * 1.1,
        height: size.height * 0.55,
      ),
      Paint()..color = terrain.floor,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ground.dx - size.width * 0.06, ground.dy - 6),
        width: size.width * 0.8,
        height: size.height * 0.38,
      ),
      Paint()..color = terrain.floor.withValues(alpha: 0.7),
    );
    // Plataforma redonda del jugador: mismo centro que su sombra (abajo-
    // izquierda, justo bajo su Pokémon) y tamaño de plataforma, no de piso.
    final playerPad = Offset(size.width * 0.22, size.height * 0.78);
    final playerPadOuter = Rect.fromCenter(
      center: playerPad,
      width: size.width * 0.46,
      height: size.height * 0.20,
    );
    if (sheet != null && src != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(playerPadOuter));
      canvas.drawImageRect(sheet, src, playerPadOuter, _platformPaint);
      canvas.restore();
    } else {
      canvas.drawOval(playerPadOuter, Paint()..color = terrain.stands.withValues(alpha: 0.85));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(playerPad.dx - 6, playerPad.dy - 4),
          width: size.width * 0.34,
          height: size.height * 0.14,
        ),
        Paint()..color = terrain.stands.withValues(alpha: 0.6),
      );
    }
    // Montículo del rival con dos tonos (luz/sombra).
    final mound = Offset(size.width * 0.72, size.height * 0.52);
    final moundOuter = Rect.fromCenter(
      center: mound,
      width: size.width * 0.42,
      height: size.height * 0.20,
    );
    if (sheet != null && src != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(moundOuter));
      canvas.drawImageRect(sheet, src, moundOuter, _platformPaint);
      canvas.restore();
    } else {
      canvas.drawOval(moundOuter, Paint()..color = terrain.stands.withValues(alpha: 0.85));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(mound.dx - 6, mound.dy - 4),
          width: size.width * 0.32,
          height: size.height * 0.14,
        ),
        Paint()..color = terrain.stands.withValues(alpha: 0.6),
      );
    }
    // Sombras bajo cada luchador (el rival sobre el montículo,
    // el jugador sobre el suelo).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.74, size.height * 0.56),
        width: 64,
        height: 12,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.22, size.height * 0.78),
        width: 78,
        height: 14,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    // Textura: motas + briznas.
    final speck = Paint()..color = terrain.stands.withValues(alpha: 0.6);
    for (var i = 0; i < 24; i++) {
      canvas.drawCircle(
        Offset(
          (i * 67.0) % size.width,
          size.height * (0.60 + ((i * 37.0) % 35) / 100),
        ),
        1.8,
        speck,
      );
    }
    if (terrain.id == 'grass') {
      final blade = Paint()
        ..color = const Color(0xFF2F7A3D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      for (var i = 0; i < 12; i++) {
        final x = (i * 89.0) % size.width;
        final y = size.height * (0.68 + ((i * 41.0) % 22) / 100);
        canvas.drawLine(Offset(x, y), Offset(x + 2, y - 6), blade);
        canvas.drawLine(Offset(x + 4, y), Offset(x + 6, y - 5), blade);
      }
    }
  }

  /// Arboleda con balanceo + flores (hierba).
  void _trees(Canvas canvas, Size size) {
    for (var i = 0; i < 2; i++) {
      final bx = size.width * (0.06 + i * 0.11);
      final by = size.height * 0.60;
      final sway = math.sin(time + i * 1.4) * 3;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(bx, by), width: 7, height: 30),
        Paint()..color = const Color(0xFF6B4A2B),
      );
      final leaf = Paint()..color = const Color(0xFF3E8E4D);
      final leafHi = Paint()..color = const Color(0xFF55A868);
      canvas.drawCircle(Offset(bx + sway, by - 22), 15, leaf);
      canvas.drawCircle(Offset(bx + sway - 9, by - 14), 10, leaf);
      canvas.drawCircle(Offset(bx + sway + 9, by - 14), 10, leaf);
      canvas.drawCircle(Offset(bx + sway - 4, by - 26), 6, leafHi);
    }
    // Flores.
    for (var i = 0; i < 6; i++) {
      final fx = (i * 131.0) % size.width;
      final fy = size.height * (0.66 + ((i * 47.0) % 20) / 100);
      final petal = Paint()
        ..color = i.isEven ? Colors.white : const Color(0xFFFF9EBB);
      for (var k = 0; k < 4; k++) {
        canvas.drawCircle(
          Offset(fx + 3 * math.cos(k * 1.57), fy + 3 * math.sin(k * 1.57)),
          2.2,
          petal,
        );
      }
      canvas.drawCircle(
        Offset(fx, fy),
        2,
        Paint()..color = const Color(0xFFFFD93D),
      );
    }
  }

  /// Olas animadas + espuma en la orilla (playa).
  void _waves(Canvas canvas, Size size) {
    final wave = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (var r = 0; r < 2; r++) {
      final y = size.height * (0.60 + r * 0.08);
      final p = Path();
      for (var x = 0.0; x <= size.width; x += 8) {
        final yy = y + math.sin(x / 26 + time * 1.6 + r * 2) * 3;
        if (x == 0) {
          p.moveTo(x, yy);
        } else {
          p.lineTo(x, yy);
        }
      }
      canvas.drawPath(p, wave);
    }
    // Orilla de espuma.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.70),
        width: size.width * 0.95,
        height: 10,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  /// Brasas ascendentes + grietas de lava (volcán).
  void _embers(Canvas canvas, Size size) {
    for (var i = 0; i < 14; i++) {
      final h = size.height * 0.55;
      final y = size.height * 0.58 - ((i * 37.0 + time * 26) % h);
      final x = (i * 71.0) % size.width;
      final fade = (y / (size.height * 0.58)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        2.4,
        Paint()..color = Colors.orangeAccent.withValues(alpha: fade),
      );
      canvas.drawCircle(
        Offset(x, y),
        1.1,
        Paint()..color = Colors.yellow.withValues(alpha: fade),
      );
    }
    // Grietas de lava en el suelo.
    final lava = Paint()
      ..color = const Color(0xFFFF6B35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.74 + i * 0.05);
      final p = Path()
        ..moveTo(size.width * (0.1 + i * 0.25), y)
        ..lineTo(size.width * (0.2 + i * 0.25), y - 5)
        ..lineTo(size.width * (0.3 + i * 0.25), y + 2);
      canvas.drawPath(p, lava);
    }
  }

  /// Destellos eléctricos + baldosas (gimnasio).
  void _sparks(Canvas canvas, Size size) {
    // Baldosas del piso.
    final tile = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(size.width * (0.15 + i * 0.2), size.height * 0.66),
        Offset(size.width * (0.05 + i * 0.2), size.height * 0.95),
        tile,
      );
    }
    for (var i = 0; i < 5; i++) {
      final on = math.sin(time * 5 + i * 2.3) > 0.55;
      if (!on) continue;
      final x = (i * 89.0) % size.width;
      final y = size.height * (0.1 + (i % 3) * 0.12);
      final p = Path()
        ..moveTo(x, y)
        ..lineTo(x - 5, y + 10)
        ..lineTo(x + 1, y + 10)
        ..lineTo(x - 4, y + 22);
      canvas.drawPath(
        p,
        Paint()
          ..color = const Color(0xFFFFE14D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(x - 2, y + 11),
        6,
        Paint()..color = const Color(0xFFFFE14D).withValues(alpha: 0.3),
      );
    }
  }

  /// Nieve cayendo con vaivén (terreno nieve/montaña).
  void _snowfall(Canvas canvas, Size size) {
    final flake = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < 22; i++) {
      final h = size.height * 0.75;
      final y = (i * 53.0 + time * (14 + (i % 4) * 5)) % h;
      final x =
          ((i * 97.0 + math.sin(time + i) * 8) % size.width + size.width) %
          size.width;
      canvas.drawCircle(Offset(x, y), 1.6 + (i % 3) * 0.6, flake);
    }
  }

  /// Luciérnagas pulsantes a la deriva (noche/jungla).
  void _fireflies(Canvas canvas, Size size) {
    for (var i = 0; i < 10; i++) {
      final glow = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(time * 2.2 + i * 2.1));
      final x = (i * 113.0 + time * 6) % size.width;
      final y =
          size.height * 0.45 +
          math.sin(time * 0.9 + i * 1.3) * size.height * 0.12;
      canvas.drawCircle(
        Offset(x, y),
        3.2,
        Paint()..color = const Color(0xFFD8F36B).withValues(alpha: 0.25 * glow),
      );
      canvas.drawCircle(
        Offset(x, y),
        1.4,
        Paint()..color = const Color(0xFFFFFFB0).withValues(alpha: glow),
      );
    }
  }

  /// Arena del desierto barriendo el suelo (desierto).
  void _sand(Canvas canvas, Size size) {
    final grain = Paint()
      ..color = const Color(0xFFFFE8C1).withValues(alpha: 0.7);
    for (var i = 0; i < 16; i++) {
      final y = size.height * (0.62 + ((i * 41.0) % 25) / 100);
      final x = (i * 67.0 + time * (30 + (i % 3) * 14)) % size.width;
      canvas.drawCircle(Offset(x, y), 1.5, grain);
    }
  }

  /// Pájaros en vuelo lento (atardecer).
  void _birds(Canvas canvas, Size size) {
    final bird = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = ((i * 0.4 + time * 0.015) % 1.3 - 0.15) * size.width;
      final y = size.height * (0.12 + i * 0.05);
      final flap = math.sin(time * 3 + i * 2) * 2.5;
      final p = Path()
        ..moveTo(x - 7, y)
        ..quadraticBezierTo(x - 3, y - 4 - flap, x, y)
        ..quadraticBezierTo(x + 3, y - 4 - flap, x + 7, y);
      canvas.drawPath(p, bird);
    }
  }

  /// Lluvia diagonal intensa (tormenta).
  void _rain(Canvas canvas, Size size) {
    final drop = Paint()
      ..color = const Color(0xFF9ED7F5).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 30; i++) {
      final h = size.height;
      final y = (i * 61.0 + time * 160) % h;
      final x = ((i * 83.0 + y * 0.25) % (size.width + 20)) - 10;
      canvas.drawLine(Offset(x, y), Offset(x - 4, y + 10), drop);
    }
  }

  @override
  bool shouldRepaint(covariant _GbaTerrainPainter old) =>
      old.terrain.id != terrain.id || old.time != time;
}
