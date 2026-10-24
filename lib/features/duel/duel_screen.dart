import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/models/type_relations.dart';
import '../../core/services/score_history_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/type_colors.dart';
import '../../core/widgets/poke_image.dart';
import '../battle/arena_background.dart';
import '../battle/battle_fx.dart';
import '../battle/battle_fx_extra.dart';
import '../battle/battle_orientation.dart';
import '../battle/battle_provider.dart' show BotDifficulty;
import '../battle/battle_terrain.dart';
import '../settings/settings_provider.dart';
import '../wallet/wallet_provider.dart';
import '../wallet/wallet_rules.dart';
import 'duel_engine.dart';
import 'duel_hud.dart';
import 'duel_rig.dart';
import 'net/duel_link.dart';
import 'net/duel_snapshot.dart';

/// Pantalla del Duelo ONLINE: pelea 2D en tiempo real entre dos jugadores, en
/// horizontal y a pantalla completa, con analógico a la izquierda y botones a
/// la derecha. Combate al mejor de 3 rondas.
///
/// El ANFITRIÓN ([host]) ejecuta el combate y publica el estado; el INVITADO
/// ([guest]) envía sus controles y dibuja el estado recibido. Cada jugador se
/// ve siempre a la izquierda (el invitado ve la arena espejada).
class DuelScreen extends StatefulWidget {
  /// Luchador del anfitrión (en el motor es `player`) y del invitado (`enemy`).
  final PokemonDetail hostFighter;
  final PokemonDetail guestFighter;
  final String hostName;
  final String guestName;
  final BattleTerrain terrain;
  final Map<String, TypeRelations> relations;

  /// Extremo de red: exactamente uno de los dos.
  final DuelHostLink? host;
  final DuelGuestLink? guest;

  /// Duración de cada ronda (por defecto la de [DuelTuning.duration]).
  final double? roundDuration;

  /// Aleatoriedad inyectable (pruebas deterministas).
  final math.Random? rng;

  /// Anfitrión: el combate terminó (ganador 0/1 o null si empate).
  final void Function(int? winnerSlot, String reason)? onFinish;

  /// Se llama al salir de la pantalla; [fighting] = seguía peleando.
  final void Function(bool fighting)? onLeave;
  const DuelScreen({
    super.key,
    required this.hostFighter,
    required this.guestFighter,
    required this.terrain,
    this.hostName = 'Anfitrión',
    this.guestName = 'Invitado',
    this.relations = const {},
    this.host,
    this.guest,
    this.roundDuration,
    this.rng,
    this.onFinish,
    this.onLeave,
  }) : assert((host == null) != (guest == null), 'Se necesita exactamente un extremo de red: host o guest');

  @override
  State<DuelScreen> createState() => DuelScreenState();
}

enum _FxKind { burst, number, dust, sparks }

/// Efecto visual efímero (chispa, número de daño, polvo…).
class _Fx {
  final _FxKind kind;
  final double x; // unidades de arena
  final double y;
  final Color color;
  final String? text;
  final String type;
  final bool crit;
  final int sparks;
  double t = 0; // segundos
  _Fx(this.kind, this.x, this.y, this.color, {this.text, this.type = 'normal', this.crit = false, this.sparks = 6});
  static const life = 0.7;
}

class DuelScreenState extends State<DuelScreen> with SingleTickerProviderStateMixin {
  late DuelMatch _match;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final math.Random _fxRng = math.Random();

  bool get _isHost => widget.host != null;

  /// El invitado ve la arena espejada para verse siempre a la izquierda.
  bool get _mirror => !_isHost;

  DuelSide get _mySide => _isHost ? DuelSide.player : DuelSide.enemy;
  DuelFighter get _me => _match.engine.fighter(_mySide);
  DuelFighter get _rival => _match.engine.fighter(opposite(_mySide));
  PokemonDetail get _myMon => _isHost ? widget.hostFighter : widget.guestFighter;
  PokemonDetail get _rivalMon => _isHost ? widget.guestFighter : widget.hostFighter;
  String get _rivalName => _isHost ? widget.guestName : widget.hostName;
  int get _myCrowns => _isHost ? _match.playerWins : _match.enemyWins;
  int get _rivalCrowns => _isHost ? _match.enemyWins : _match.playerWins;

  /// Posición/orientación en pantalla (espejadas para el invitado).
  double _sx(double x) => _mirror ? 100 - x : x;
  double _sf(double facing) => _mirror ? -facing : facing;

  double _clock = 0;
  double _move = 0;
  bool _guard = false;
  bool _pAttack = false, _pHorde = false, _pUltra = false, _pDodge = false;
  final List<_Fx> _fx = [];
  final Map<DuelSide, double> _lastX = {};
  final Map<DuelSide, double> _speed = {};
  final Map<DuelSide, double> _vsign = {};
  final Map<DuelSide, FighterAnim> _anims = {for (final s in DuelSide.values) s: FighterAnim()};
  double _shake = 0;
  double _flash = 0;
  int _comboShown = 0;
  DuelSide _comboSide = DuelSide.player;
  double _comboT = 0;
  double _koSlow = 0;
  double _resultIn = 0;
  double _dustT = 0;

  String? _banner;
  double _bannerT = 0;
  bool _betweenRounds = false;

  /// Tutorial inicial: mientras está abierto el combate no empieza.
  bool _paused = false;

  /// Ayuda abierta a demanda: no detiene el combate (es online).
  bool _helpOpen = false;
  bool _showResult = false;
  bool _rewarded = false;
  bool _tutorialChecked = false;

  /// El rival se desconectó: gana el que sigue (anfitrión) o se acaba (invitado).
  bool _rivalGone = false;
  String? _shownWinner;
  String? _forfeitWinner;
  bool _finishedReported = false;

  @visibleForTesting
  DuelEngine get engine => _match.engine;

  @visibleForTesting
  DuelMatch get match => _match;

  void _newMatch() {
    _match = DuelMatch(
      playerMon: widget.hostFighter,
      enemyMon: widget.guestFighter,
      relations: widget.relations,
      rng: widget.rng,
      roundDuration: widget.roundDuration ?? DuelTuning.duration,
    );
    _resetRoundVisuals();
    _showResult = false;
    _rewarded = false;
    _betweenRounds = false;
    _rivalGone = false;
    _forfeitWinner = null;
    _finishedReported = false;
    _announce('RONDA 1', 1.4);
  }

  void _resetRoundVisuals() {
    _fx.clear();
    _move = 0;
    _guard = false;
    _shake = 0;
    _flash = 0;
    _comboShown = 0;
    _comboT = 0;
    _koSlow = 0;
    _resultIn = 0;
    _lastX.clear();
    _speed.clear();
    for (final s in DuelSide.values) {
      _anims[s] = FighterAnim();
    }
  }

  void _announce(String text, double seconds) {
    _banner = text;
    _bannerT = seconds;
  }

  @override
  void initState() {
    super.initState();
    BattleOrientation.lock();
    _newMatch();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tutorialChecked) return;
    _tutorialChecked = true;
    try {
      _paused = !context.read<SettingsProvider>().duelTutorialSeen;
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    BattleOrientation.release();
    widget.onLeave?.call(!_showResult);
    widget.host?.close();
    widget.guest?.close();
    super.dispose();
  }

  // ------------------------------------------------------------------- bucle

  /// ¿El anfitrión ya puede empezar? Su tutorial cerrado, el invitado
  /// conectado y con su tutorial cerrado.
  bool get _hostRunning {
    final h = widget.host;
    return h != null && !_paused && h.guestConnected && h.guestReady && !_showResult;
  }

  /// Texto de espera (null = ya se está jugando).
  String? get _waitingText {
    if (_paused || _showResult) return null;
    if (_isHost) {
      final h = widget.host!;
      if (!h.guestConnected) return 'Esperando a ${widget.guestName}…';
      if (!h.guestReady) return '${widget.guestName} está leyendo el tutorial…';
    } else if (!widget.guest!.connected) {
      return 'Conectando con ${widget.hostName}…';
    }
    return null;
  }

  /// Aviso de conexión inestable (el rival lleva rato sin dar señales).
  bool get _unstable {
    if (_showResult) return false;
    return _isHost ? widget.host!.guestStale : widget.guest!.hostStale;
  }

  DuelUiState _uiState() => DuelUiState(
        banner: _bannerT > 0 ? _banner : null,
        showResult: _showResult,
        winner: _winnerString(),
        matchOver: _match.over || _forfeitWinner != null,
      );

  String? _winnerString() {
    if (_forfeitWinner != null) return _forfeitWinner;
    if (!_match.over) return null;
    return switch (_match.winner) {
      DuelSide.player => 'player',
      DuelSide.enemy => 'enemy',
      null => 'draw',
    };
  }

  /// Quién ganó el combate según este dispositivo ('player', 'enemy', 'draw').
  String? get _resultWinner => _isHost ? _winnerString() : widget.guest!.ui.winner;

  bool get _iWon => _resultWinner == (_isHost ? 'player' : 'enemy');

  void _onTick(Duration now) {
    final raw = (now - _last).inMicroseconds / 1e6;
    _last = now;
    final dt = raw.clamp(0.0, 0.05).toDouble();
    _clock += dt;
    final en = _match.engine;

    if (_isHost) {
      final h = widget.host!;
      if (_hostRunning) {
        final slow = _koSlow > 0 ? 0.35 : 1.0;
        final input = DuelInput(move: _move, attack: _pAttack, horde: _pHorde, ultra: _pUltra, dodge: _pDodge, guard: _guard);
        final wasOver = en.over;
        final events = en.step(dt * slow, input, h.guestInput());
        h.addEvents(events);
        for (final e in events) {
          _onEvent(e);
        }
        if (!wasOver && en.over) _resultIn = en.ko ? 1.7 : 0.9;
        // El rival se fue: gano por retiro.
        if (h.guestLost) _rivalLeft();
      }
      _pAttack = _pHorde = _pUltra = _pDodge = false;
      h.maybePublish(dt, _match, _uiState());
    } else {
      final g = widget.guest!;
      g.setReady(!_paused);
      g.setMove(-_move); // el motor usa las coordenadas del anfitrión
      g.setGuard(_guard);
      if (_pAttack) g.pressAttack();
      if (_pHorde) g.pressHorde();
      if (_pUltra) g.pressUltra();
      if (_pDodge) g.pressDodge();
      _pAttack = _pHorde = _pUltra = _pDodge = false;
      final events = g.update(dt, _match);
      for (final e in events) {
        _onEvent(e);
      }
      // Lo que decide el anfitrión: avisos y resultado.
      final ui = g.ui;
      if (ui.banner != null && ui.banner != _banner) _announce(ui.banner!, 1.2);
      if (ui.showResult && !_showResult) {
        _showResult = true;
        _shownWinner = ui.winner;
        _award();
        setState(() {});
      } else if (ui.showResult && _showResult && ui.winner != _shownWinner) {
        _shownWinner = ui.winner; // el anfitrión corrigió el resultado
        setState(() {});
      } else if (!ui.showResult && _showResult && !_rivalGone) {
        _showResult = false; // revancha
        _rewarded = false;
        _resetRoundVisuals();
        setState(() {});
      }
      if (g.hostLost && !_showResult && g.connected) {
        _rivalGone = true;
        _showResult = true;
        setState(() {});
      }
    }

    // Polvo al correr (solo se ve en el anfitrión; el invitado no recibe `running`).
    _dustT -= dt;
    if (_dustT <= 0) {
      for (final f in [en.player, en.enemy]) {
        if (f.running) _fx.add(_Fx(_FxKind.dust, f.x - f.facing * 3, 0, Colors.brown.shade200));
      }
      _dustT = 0.11;
    }

    // Animación de los cuerpos: muelles que siguen la postura de cada acción.
    if (dt > 0) {
      for (final f in [en.player, en.enemy]) {
        final prev = _lastX[f.side];
        final v = prev == null ? 0.0 : ((f.x - prev) / dt).abs() / DuelTuning.walkSpeed;
        final sp = _speed[f.side] ?? 0;
        _speed[f.side] = sp + (v.clamp(0.0, 2.0) - sp) * math.min(1.0, dt * 12);
        if (prev != null && (f.x - prev).abs() > 1e-6) _vsign[f.side] = (f.x - prev).sign;
        _lastX[f.side] = f.x;
        _anims[f.side]!.step(
          poseFor(
            state: f.state,
            stateT: f.stateT,
            clock: _clock,
            speed: _speed[f.side] ?? 0,
            guarding: f.guarding,
            y: f.y,
            vy: f.vy,
            seed: f.side == DuelSide.player ? 0 : 1.7,
          ),
          dt,
          y: f.y,
          snappy: f.state != DuelState.idle,
        );
      }
    }

    // Efectos y temporizadores visuales.
    for (final f in _fx) {
      f.t += dt;
    }
    _fx.removeWhere((f) => f.t > _Fx.life);
    _shake = math.max(0, _shake - dt);
    _flash = math.max(0, _flash - dt);
    _comboT = math.max(0, _comboT - dt);
    _koSlow = math.max(0, _koSlow - dt);
    if (_bannerT > 0) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = null;
    }

    // Fin de ronda y paso a la siguiente (las decide el anfitrión).
    if (_isHost) {
      if (en.over && !_showResult && !_betweenRounds) {
        _resultIn -= dt;
        if (_resultIn <= 0) _endOfRound();
      }
      if (_betweenRounds && _bannerT <= 0) {
        _betweenRounds = false;
        _match.nextRound();
        _resetRoundVisuals();
        _announce('¡PELEA!', 0.9);
      }
    }
    _frame.value++;
  }

  void _endOfRound() {
    _match.settleRound();
    if (_match.over) {
      _showResult = true;
      _reportFinish(_match.winner == null ? null : (_match.winner == DuelSide.player ? 0 : 1), 'Fin del combate');
      _award();
      setState(() {});
    } else {
      _betweenRounds = true;
      _announce('RONDA ${_match.round + 1}', 1.6);
      setState(() {});
    }
  }

  /// El invitado dejó de dar señales: el anfitrión gana por retiro.
  void _rivalLeft() {
    if (_showResult) return;
    _rivalGone = true;
    _forfeitWinner = 'player';
    _showResult = true;
    _reportFinish(0, 'Retiro del rival');
    _award();
    setState(() {});
  }

  void _reportFinish(int? winnerSlot, String reason) {
    if (_finishedReported) return;
    _finishedReported = true;
    widget.onFinish?.call(winnerSlot, reason);
  }

  void _onEvent(DuelEvent e) {
    switch (e.type) {
      case DuelEventType.hit:
      case DuelEventType.skillHit:
      case DuelEventType.ultraHit:
        final color = e.effectiveness == 0 ? Colors.grey : colorForType(e.moveType);
        _fx.add(_Fx(_FxKind.burst, e.x, e.y, color));
        if (e.type != DuelEventType.hit && e.effectiveness != 0) {
          _fx.add(_Fx(_FxKind.sparks, e.x, e.y, color, type: e.moveType, sparks: e.type == DuelEventType.ultraHit ? 12 : 7));
        }
        final label = e.effectiveness == 0 ? 'Sin efecto' : e.crit ? '¡CRÍTICO! ${e.damage}' : '${e.damage}';
        _fx.add(_Fx(_FxKind.number, e.x + (_fxRng.nextDouble() - 0.5) * 6, e.y + 6, e.crit ? Colors.amberAccent : Colors.white, text: label, crit: e.crit));
        _shake = e.type == DuelEventType.ultraHit ? 0.55 : e.type == DuelEventType.skillHit || e.crit ? 0.3 : 0.15;
      case DuelEventType.blocked:
        _fx.add(_Fx(_FxKind.number, e.x, e.y + 6, Colors.lightBlueAccent, text: 'BLOQUEO ${e.damage}'));
        _shake = 0.08;
      case DuelEventType.combo:
        _comboShown = e.combo;
        _comboSide = e.side;
        _comboT = 1.2;
      case DuelEventType.ultra:
        _flash = 0.35;
        _shake = 0.25;
      case DuelEventType.dodge:
      case DuelEventType.slide:
      case DuelEventType.jump:
        _fx.add(_Fx(_FxKind.dust, e.x, 0, Colors.brown.shade200));
      case DuelEventType.ko:
        _koSlow = 1.2;
        _shake = 0.5;
        if (_isHost) _announce('¡KO!', 1.5);
      case DuelEventType.timeUp:
        if (_isHost) _announce('¡TIEMPO!', 1.2);
      default:
        break;
    }
  }

  Future<void> _award() async {
    if (_rewarded) return;
    _rewarded = true;
    final won = _iWon;
    won ? SoundService.win() : SoundService.lose();
    final score = won ? 100 + _myCrowns * 40 + 50 : 0;
    try {
      final history = context.read<ScoreHistoryService>();
      final wallet = context.read<WalletProvider>();
      await history.saveScore(gameName: 'Duelo online', score: score);
      if (won) await wallet.addCoins(WalletRules.coinsForClassicWin(BotDifficulty.normal));
    } catch (_) {}
  }

  void _closeTutorial() {
    setState(() {
      _paused = false;
      _helpOpen = false;
    });
    try {
      context.read<SettingsProvider>().markDuelTutorialSeen();
    } catch (_) {}
  }

  /// Revancha (solo el anfitrión): empieza un combate nuevo y el invitado lo ve.
  void _rematch() {
    if (!_isHost || _rivalGone) return;
    setState(_newMatch);
  }

  // ---------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, cons) {
          final k = (cons.maxHeight / 390).clamp(0.72, 1.0).toDouble();
          return Stack(
            fit: StackFit.expand,
            children: [
              ArenaBackground(terrain: widget.terrain, borderRadius: 0),
              // Tinte de suelo para que los luchadores se lean sobre la foto.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 110,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
                    ),
                  ),
                ),
              ),
              // Escena: brasas, luchadores, proyectiles y efectos (cada frame).
              Positioned.fill(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (context, _, _) => _scene(),
                  ),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(6),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _frame,
                        builder: (context, _, _) => _topBar(),
                      ),
                    ),
                    Positioned(
                      top: 74 * k,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _miniButton(Icons.help_outline, 'Tutorial', () => setState(() => _helpOpen = true)),
                            const SizedBox(width: 8),
                            _miniButton(Icons.close, 'Salir', () => Navigator.of(context).maybePop()),
                          ],
                        ),
                      ),
                    ),
                    _leftControls(k),
                    _rightControls(k),
                  ],
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, _) => _bannerView(),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, _) => _statusView(),
              ),
              if (_showResult) _resultOverlay(),
              if (_paused || _helpOpen) _howTo(),
            ],
          );
        },
      ),
    );
  }

  Widget _miniButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white38),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }

  Widget _topBar() {
    final en = _match.engine;
    // Yo siempre a la izquierda (ULTRA); el rival a la derecha (FRENESÍ).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DuelPlate(
            pokemon: _myMon,
            fighter: _me,
            right: false,
            crowns: _myCrowns,
          ),
        ),
        const SizedBox(width: 8),
        DuelTimer(seconds: en.timeLeft, terrain: widget.terrain.name),
        const SizedBox(width: 8),
        Expanded(
          child: DuelPlate(
            pokemon: _rivalMon,
            fighter: _rival,
            right: true,
            ultraLabel: 'FRENESÍ',
            ultraColor: kDuelPurple,
            crowns: _rivalCrowns,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- controles

  /// Analógico para moverse, abajo a la izquierda.
  Widget _leftControls(double k) {
    return Positioned(
      left: 8,
      bottom: 6,
      child: DuelJoystick(size: 132 * k, onMove: (v) => _move = v),
    );
  }

  /// Botonera de la derecha, solo lo importante: ATAQUE (puño), PODERES (horda
  /// de disparos), ¡ULTRA!, ESCUDO (se mantiene) y ESQUIVAR. Se dibuja en un
  /// lienzo fijo y se escala para que quepa en pantallas bajas.
  Widget _rightControls(double k) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: ValueListenableBuilder<int>(
        valueListenable: _frame,
        builder: (context, _, _) {
          final p = _me;
          double frac(double left, double total) => total <= 0 ? 0 : (left / total).clamp(0.0, 1.0).toDouble();
          return SizedBox(
            width: 300 * k,
            height: 200 * k,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
              child: SizedBox(
                width: 300,
                height: 200,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 206,
                      top: 6,
                      child: DuelActionButton(
                        label: '¡ULTRA!',
                        icon: Icons.local_fire_department,
                        color: kDuelOrange,
                        size: 66,
                        glow: p.ultraReady,
                        enabled: p.ultraReady,
                        onPress: () => _pUltra = true,
                      ),
                    ),
                    Positioned(
                      left: 200,
                      top: 100,
                      child: DuelActionButton(
                        label: 'PUÑO',
                        icon: Icons.sports_mma,
                        color: kDuelRed,
                        size: 82,
                        cooldown: frac(p.attackCd, DuelTuning.meleeCooldown),
                        onPress: () => _pAttack = true,
                      ),
                    ),
                    Positioned(
                      left: 112,
                      top: 112,
                      child: DuelActionButton(
                        label: 'PODERES',
                        icon: Icons.auto_awesome,
                        color: kDuelGreen,
                        size: 62,
                        cooldown: frac(p.hordeCd, DuelTuning.hordeCooldown),
                        enabled: p.stamina >= DuelTuning.hordeCost,
                        onPress: () => _pHorde = true,
                      ),
                    ),
                    Positioned(
                      left: 112,
                      top: 22,
                      child: DuelActionButton(
                        label: 'ESCUDO',
                        icon: Icons.shield,
                        color: kDuelBlue,
                        size: 56,
                        glow: p.guarding,
                        onPress: () => _guard = true,
                        onRelease: () => _guard = false,
                      ),
                    ),
                    Positioned(
                      left: 26,
                      top: 100,
                      child: DuelActionButton(
                        label: 'ESQUIVAR',
                        icon: Icons.fast_forward,
                        color: kDuelPurple,
                        size: 56,
                        cooldown: frac(p.dodgeCd, DuelTuning.dodgeCooldown),
                        enabled: p.stamina >= DuelTuning.dodgeCost,
                        onPress: () => _pDodge = true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------- escena

  Widget _scene() {
    final en = _match.engine;
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final h = cons.maxHeight;
        final groundY = h * 0.84;
        final s = h * 0.40; // tamaño del sprite
        double px(double x) => _sx(x) / 100 * w;
        double lift(double y) => y * h / 80;
        final a = _shake * 14;
        final shake = Offset(math.sin(_clock * 90) * a, math.cos(_clock * 73) * a);

        return Transform.translate(
          offset: shake,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: DuelEmbers(clock: _clock)),
              // Rayos del ULTRA.
              for (final f in [en.player, en.enemy])
                if (f.state == DuelState.ultra && f.stateT > DuelTuning.ultraWindup) _ultraBeam(f, en, px, w, groundY, s),
              _fighterView(en.player, widget.hostFighter, px(en.player.x), groundY, s, lift(en.player.y)),
              _fighterView(en.enemy, widget.guestFighter, px(en.enemy.x), groundY, s, lift(en.enemy.y)),
              for (final p in en.projectiles)
                Positioned(
                  left: px(p.x) - (14 + p.radius * 1.6),
                  top: groundY - s * 0.45 - lift(p.arcY) - (14 + p.radius * 1.6),
                  child: MoveProjectile(
                    type: p.type,
                    color: colorForType(p.type),
                    progress: (_clock * 3) % 1,
                    size: 28 + p.radius * 3.2,
                  ),
                ),
              for (final f in _fx) _fxView(f, px(f.x), groundY, s, lift(f.y)),
              if (_comboT > 0 && _comboShown >= 2) _comboView(en, w, h),
              if (_flash > 0) Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.white.withValues(alpha: (_flash / 0.35).clamp(0.0, 1.0) * 0.5)))),
            ],
          ),
        );
      },
    );
  }

  Widget _comboView(DuelEngine en, double w, double h) {
    // Se muestra sobre el que recibe los golpes.
    final victim = _comboSide == DuelSide.player ? en.enemy : en.player;
    final left = (_sx(victim.x) / 100 * w - 80).clamp(8.0, math.max(8.0, w - 190)).toDouble();
    return Positioned(
      top: h * 0.2,
      left: left,
      child: Opacity(opacity: (_comboT / 0.4).clamp(0.0, 1.0).toDouble(), child: ComboBubble(combo: _comboShown)),
    );
  }

  Widget _ultraBeam(DuelFighter f, DuelEngine en, double Function(double) px, double w, double groundY, double s) {
    final t = ((f.stateT - DuelTuning.ultraWindup) / (DuelTuning.ultraTime - DuelTuning.ultraWindup)).clamp(0.0, 1.0).toDouble();
    final color = colorForType(f.ultraMove.type);
    final len = DuelTuning.ultraRange / 100 * w;
    final facing = _sf(f.facing);
    final left = facing > 0 ? px(f.x) : px(f.x) - len;
    return Positioned(
      left: left,
      top: groundY - s * 0.62,
      width: len,
      height: s * 0.45,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1 - t).clamp(0.0, 1.0).toDouble(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(
                begin: facing > 0 ? Alignment.centerLeft : Alignment.centerRight,
                end: facing > 0 ? Alignment.centerRight : Alignment.centerLeft,
                colors: [Colors.white, color, color.withValues(alpha: 0)],
              ),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 24, spreadRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fxView(_Fx f, double x, double groundY, double s, double lift) {
    final t = (f.t / _Fx.life).clamp(0.0, 1.0).toDouble();
    final y = groundY - s * 0.5 - lift;
    switch (f.kind) {
      case _FxKind.burst:
        return Positioned(
          left: x - 36,
          top: y - 36,
          child: IgnorePointer(child: ImpactBurst(color: f.color, t: (t * 2).clamp(0.0, 1.0).toDouble(), size: 72)),
        );
      case _FxKind.sparks:
        return Positioned(
          left: x - 55,
          top: y - 55,
          child: SpriteBurst(type: f.type, t: (t * 1.6).clamp(0.0, 1.0).toDouble(), size: 110, count: f.sparks),
        );
      case _FxKind.dust:
        final r = 8 + 14 * t;
        return Positioned(
          left: x - r,
          top: groundY - r * 0.9 - 4,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - t) * 0.6,
              child: Container(width: r * 2, height: r * 1.4, decoration: BoxDecoration(color: f.color, borderRadius: BorderRadius.all(Radius.elliptical(r, r * 0.7)))),
            ),
          ),
        );
      case _FxKind.number:
        return Positioned(
          left: x - 70,
          top: y - 30 * t - 20,
          width: 140,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0).toDouble(),
              child: Text(
                f.text ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: f.color,
                  fontSize: f.crit ? 22 : 18,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4), Shadow(color: Colors.black, offset: Offset(1, 1))],
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _fighterView(DuelFighter f, PokemonDetail pk, double cx, double groundY, double s, double lift) {
    final st = f.state;
    final pose = _anims[f.side]!.pose;
    final facing = _sf(f.facing); // orientación en pantalla
    var rot = 0.0;
    var opacity = 1.0;
    if (st == DuelState.dodge) {
      opacity = 0.5;
    } else if (st == DuelState.ko) {
      rot = (facing > 0 ? -1 : 1) * math.min(f.stateT / 0.5, 1) * 1.2;
      opacity = (1 - (f.stateT - 0.8) / 1.2).clamp(0.25, 1.0).toDouble();
    }
    // Arte oficial en alta calidad (no el GIF pequeño), escalado suave. Los
    // sprites miran a la izquierda: se espejan al mirar a la derecha.
    Widget art() => Transform.flip(
          flipX: facing > 0,
          child: PokeImage(
            id: pk.id,
            kind: PokeSpriteKind.artwork,
            width: s,
            height: s,
            cacheWidth: 640,
            filterQuality: FilterQuality.high,
          ),
        );
    Widget sprite = FighterSprite(size: s, pose: pose, child: art());
    if (st == DuelState.hurt) {
      sprite = ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x88FF0000), BlendMode.srcATop), child: sprite);
    }
    // Estela (imágenes residuales) al esquivar, deslizar o correr deprisa.
    final trailing = st == DuelState.dodge || st == DuelState.slide || (f.running && (_speed[f.side] ?? 0) > 1.2);
    final engineTrail = (st == DuelState.dodge || st == DuelState.slide) ? -f.dodgeDir : -(_vsign[f.side] ?? 0.0);
    final trailDir = _mirror ? -engineTrail : engineTrail;
    final aura = st == DuelState.ultra || f.ultraReady;
    return Positioned(
      left: cx - s / 2,
      top: groundY - s - lift,
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sombra en el suelo (se encoge al saltar).
          Positioned(
            left: s * 0.2,
            right: s * 0.2,
            bottom: -6 + lift,
            height: 12,
            child: Opacity(
              opacity: (1 - lift / 120).clamp(0.2, 0.6).toDouble(),
              child: const DecoratedBox(decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.all(Radius.elliptical(60, 12)))),
            ),
          ),
          if (aura)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: st == DuelState.ultra ? 0.8 : 0.25 + 0.15 * math.sin(_clock * 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: colorForType(f.ultraMove.type), blurRadius: 30, spreadRadius: 6)],
                    ),
                  ),
                ),
              ),
            ),
          // Burbuja de bloqueo.
          if (f.guarding)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.lightBlueAccent.withValues(alpha: 0.18),
                    border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.8), width: 3),
                  ),
                ),
              ),
            ),
          if (trailing)
            for (var i = 2; i >= 1; i--)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.22 / i,
                    child: Transform.translate(
                      offset: Offset(trailDir * i * s * 0.12, 0),
                      child: ColorFiltered(colorFilter: ColorFilter.mode(colorForType(f.ultraMove.type), BlendMode.srcATop), child: FighterSprite(size: s, pose: pose, child: art())),
                    ),
                  ),
                ),
              ),
          Opacity(
            opacity: opacity,
            child: Transform.rotate(angle: rot, alignment: Alignment.bottomCenter, child: sprite),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- overlays

  Widget _bannerView() {
    final text = _banner;
    if (text == null) return const SizedBox.shrink();
    final t = (_bannerT / 0.3).clamp(0.0, 1.0).toDouble();
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: t,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 2,
                shadows: [Shadow(color: Colors.black, blurRadius: 8), Shadow(color: Colors.deepOrange, offset: Offset(3, 3))],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mensajes de estado sobre la escena: esperando al rival o conexión inestable.
  Widget _statusView() {
    final waiting = _waitingText;
    final unstable = _unstable;
    if (waiting == null && !unstable) return const SizedBox.shrink();
    if (waiting != null) {
      return Positioned.fill(
        child: ColoredBox(
          color: Colors.black45,
          child: Center(
            child: _Card(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(height: 10),
                  Text(waiting, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Tú: ${prettyName(_myMon.name)}  ·  Rival: ${prettyName(_rivalMon.name)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: Colors.orange.shade800.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(14)),
            child: Text('Conexión inestable con $_rivalName…', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _resultOverlay() {
    final w = _resultWinner;
    final draw = w == 'draw' || (w == null && !_rivalGone);
    final won = _iWon;
    final title = _rivalGone ? (_isHost ? '¡VICTORIA!' : 'SIN CONEXIÓN') : draw ? '¡EMPATE!' : won ? '¡VICTORIA!' : 'DERROTA';
    final color = _rivalGone && !_isHost ? Colors.orange : draw ? Colors.amber : won ? const Color(0xFF66BB6A) : Colors.redAccent;
    final why = _rivalGone
        ? (_isHost ? '$_rivalName se desconectó.' : 'Se perdió la conexión con $_rivalName.')
        : '$_myCrowns - $_rivalCrowns en rondas contra $_rivalName';
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: _Card(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 4),
                if (!_rivalGone)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < DuelTuning.roundsToWin; i++) Icon(Icons.workspace_premium, color: i < _myCrowns ? Colors.amber : Colors.white24),
                      const SizedBox(width: 10),
                      for (var i = 0; i < DuelTuning.roundsToWin; i++) Icon(Icons.workspace_premium, color: i < _rivalCrowns ? Colors.redAccent : Colors.white24),
                    ],
                  ),
                Text(why, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (won)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('+${WalletRules.coinsForClassicWin(BotDifficulty.normal)} monedas', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 12),
                if (!_isHost && !_rivalGone)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('El anfitrión puede pedir la revancha.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (_isHost && !_rivalGone) FilledButton.icon(onPressed: _rematch, icon: const Icon(Icons.replay), label: const Text('Revancha')),
                    OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Salir')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _howTo() {
    Widget row(IconData icon, Color color, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$title  ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                    TextSpan(text: text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
              ),
            ],
          ),
        );
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: _Card(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cómo se juega el Duelo', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                // Las líneas se desplazan si no caben; el botón siempre queda a la vista.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
row(Icons.open_with, Colors.lightBlue, 'ANALÓGICO', 'Arrástralo a los lados para moverte.'),                        row(Icons.sports_mma, kDuelRed, 'PUÑO', 'Golpe cuerpo a cuerpo. Encadena golpes para hacer COMBO.'),                        row(Icons.auto_awesome, kDuelGreen, 'PODERES', 'Lanza una horda de disparos de tu tipo. Gasta stamina y tarda en recargarse.'),                        row(Icons.local_fire_department, kDuelOrange, '¡ULTRA!', 'La barra naranja se llena al dar y recibir golpes. Con ella llena, lanza un ataque enorme (solo se evita esquivando).'),                        row(Icons.shield, kDuelBlue, 'ESCUDO', 'Mantenlo pulsado para recibir solo el 25 % del daño; gasta stamina.'),                        row(Icons.fast_forward, kDuelPurple, 'ESQUIVAR', 'Un impulso en el que no te pueden dañar: úsalo contra las hordas de poderes.'),
                        const SizedBox(height: 4),
                        const Text('Combate al mejor de 3 rondas: gana quien consiga 2 coronas. Cada ronda se gana dejando sin vida al rival o teniendo más vida al acabar el reloj.', style: TextStyle(color: Colors.amber, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _closeTutorial, child: const Text('¡Entendido!'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final double width;
  final Widget child;
  const _Card({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(context).height - 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2430).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: child,
      ),
    );
  }
}
