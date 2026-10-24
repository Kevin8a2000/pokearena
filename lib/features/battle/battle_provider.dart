import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/pokemon.dart';
import '../../core/models/type_relations.dart';
import '../../core/services/pokeapi_service.dart';
import '../../core/services/cry_service.dart';
import '../../core/services/music_service.dart';
import '../../core/services/narrator_service.dart';
import '../../core/services/sound_service.dart';
import 'battle_calculator.dart';
import 'battle_orientation.dart';
import 'battle_commentary.dart';
import 'battle_hints.dart';
import 'battle_sound.dart';
import 'battle_terrain.dart';
import 'gba/gba_intro.dart';
import 'gba/gba_sprites.dart';
import 'gba/gba_terrains.dart';
import 'vs_intro.dart';

enum BattlePhase { selecting, fighting, finished }

enum BotDifficulty { easy, normal, hard }

String difficultyLabel(BotDifficulty d) {
  switch (d) {
    case BotDifficulty.easy:
      return 'Fácil';
    case BotDifficulty.normal:
      return 'Normal';
    case BotDifficulty.hard:
      return 'Difícil';
  }
}

/// Estado del combate por turnos (Sprint 3 + mejora Vs Bot por equipos).
/// - Batalla por equipos 3v3 contra el Bot (como el referente Angular).
/// - Bot con IA: en fácil pega al azar, en normal/difícil elige el mejor poder.
/// - Crítico y daño usan stats reales + STAB + efectividad 18 tipos.
class BattleProvider extends ChangeNotifier {
  final PokeApiService _api;
  final Random _random;

  /// Balance de duración: PS x3 y daño x0.5 → peleas de ~12-15 turnos
  /// en vez de KO en 2-3. No toca `battle_calculator.dart` (tests).
  static const double hpMultiplier = 3.0;
  static const double damageScale = 0.5;

  BattleProvider(this._api, [Random? random]) : _random = random ?? Random();

  BattlePhase phase = BattlePhase.selecting;
  bool loadingEnemy = false;

  // Equipo del jugador (hasta 3 para la batalla) y del bot.
  List<PokemonDetail> playerTeam = [];
  List<PokemonDetail> enemyTeam = [];
  List<int> playerTeamHp = [];
  List<int> playerTeamMaxHp = [];
  List<int> enemyTeamHp = [];
  List<int> enemyTeamMaxHp = [];
  int playerActive = 0;
  int enemyActive = 0;

  BotDifficulty difficulty = BotDifficulty.normal;
  bool botThinking = false;

  // Compat: luchador activo expuesto como antes para no romper la UI.
  PokemonDetail? get player =>
      playerTeam.isEmpty ? null : playerTeam[playerActive];
  PokemonDetail? get enemy =>
      enemyTeam.isEmpty ? null : enemyTeam[enemyActive];

  List<BattleMove> get playerMoves =>
      player == null ? const [] : movesFor(player!);
  List<BattleMove> get enemyMoves =>
      enemy == null ? const [] : movesFor(enemy!);

  int get playerHp =>
      playerTeamHp.isEmpty ? 0 : playerTeamHp[playerActive];
  int get enemyHp => enemyTeamHp.isEmpty ? 0 : enemyTeamHp[enemyActive];
  int get playerMaxHp =>
      playerTeamMaxHp.isEmpty ? 1 : playerTeamMaxHp[playerActive];
  int get enemyMaxHp =>
      enemyTeamMaxHp.isEmpty ? 1 : enemyTeamMaxHp[enemyActive];

  set playerHp(int v) {
    if (playerTeamHp.isNotEmpty) {
      playerTeamHp[playerActive] = v.clamp(0, playerTeamMaxHp[playerActive]);
    }
  }

  set enemyHp(int v) {
    if (enemyTeamHp.isNotEmpty) {
      enemyTeamHp[enemyActive] = v.clamp(0, enemyTeamMaxHp[enemyActive]);
    }
  }

  set playerMaxHp(int v) {
    if (playerTeamMaxHp.isNotEmpty) playerTeamMaxHp[playerActive] = v;
  }

  set enemyMaxHp(int v) {
    if (enemyTeamMaxHp.isNotEmpty) enemyTeamMaxHp[enemyActive] = v;
  }

  /// HP base con multiplicador de duración (peleas más largas).
  static int _battleHp(PokemonDetail p) =>
      (((p.stats['hp'] ?? 50) * hpMultiplier).round());

  // Setter de compat para código viejo que asignaba player/enemy directo.
  set player(PokemonDetail? p) {
    if (p == null) {
      playerTeam = [];
      playerTeamHp = [];
      playerTeamMaxHp = [];
      playerActive = 0;
    } else {
      playerTeam = [p];
      final hp = _battleHp(p);
      playerTeamHp = [hp];
      playerTeamMaxHp = [hp];
      playerActive = 0;
    }
  }

  set enemy(PokemonDetail? e) {
    if (e == null) {
      enemyTeam = [];
      enemyTeamHp = [];
      enemyTeamMaxHp = [];
      enemyActive = 0;
    } else {
      enemyTeam = [e];
      final hp = _battleHp(e);
      enemyTeamHp = [hp];
      enemyTeamMaxHp = [hp];
      enemyActive = 0;
    }
  }

  bool busy = false;
  String? winner; // 'player' | 'enemy'
  final List<String> log = [];
  final Map<String, TypeRelations> _relations = {};

  String lastAttacker = '';
  int lastDamage = 0;
  double lastEffectiveness = 1.0;
  bool lastCrit = false;
  bool lastMiss = false;
  bool lastUltimate = false;
  int attackSeq = 0;
  String lastMoveName = '';
  String lastMoveType = 'normal';

  // --- Mejoras: PP, pociones, carga ultimate, entrada VS ---
  List<List<int>> playerPp = []; // [miembro][moveIdx] PP restantes
  List<List<int>> enemyPp = [];
  int playerPotions = 2;
  int enemyPotions = 1;
  double playerCharge = 0.0; // 0..100, al 100 libera el Movimiento Z
  double enemyCharge = 0.0; // Igual para el rival online (el bot lo ignora).
  bool entering = false; // overlay VS al iniciar

  /// Destello de color (estilo pantalla VS) al empezar el combate, en
  /// cualquier modo. Se apaga solo cuando `VsFlashOverlay` termina su
  /// animación (ver `clearVsFlash`).
  bool vsFlash = false;
  int vsFlashIndex = 0;

  void clearVsFlash() {
    vsFlash = false;
    notifyListeners();
  }

  /// Entrada con entrenadores y Poké Balls (vista GBA Normal y 2.5D;
  /// Online y la vista moderna siguen con la entrada corta de siempre).
  bool introRich = false;

  /// Duración de la entrada con entrenadores (GBA o 2.5D según la vista).
  int introTotalMs = IntroTimeline.total;
  bool _introSkipped = false;
  bool _orientationHeld = false; // este provider mantiene el bloqueo horizontal

  /// Salta la entrada con entrenadores (toque en pantalla o botón A).
  void skipIntro() {
    if (entering && introRich) _introSkipped = true;
  }

  Future<void> _waitIntro(int ms) async {
    var waited = 0;
    while (waited < ms && !_introSkipped) {
      await Future.delayed(const Duration(milliseconds: 50));
      waited += 50;
    }
  }

  // --- Comentarista con voz ---
  String commentary = '';
  int commentarySeq = 0;
  bool voiceEnabled = true;
  bool _lowHpWarned = false;

  // --- Chat online (solo OnlineBattleProvider lo conecta a Firestore;
  // en local es silencio: el viewport lo muestra si hay texto) ---
  String chatText = '';
  int chatSlot = -1;
  int chatSeq = 0;

  /// Slot propio para ubicar el bocadillo (-1 en local: sin chat).
  int get chatMySlot => -1;

  Future<void> sendChat(String text) async {}

  /// Gritos de los personajes en batalla (default ON, volumen bajo).
  /// En Pokédex/detalle el sonido sigue activo (usa CryService directo).
  bool battleCriesEnabled = true;

  void setBattleCries(bool v) {
    battleCriesEnabled = v;
    if (!v) CryService.stop();
    notifyListeners();
  }

  /// Grito solo si el usuario activó gritos en batalla + sonido global.
  void _cry(int id, {double rate = 1.0}) {
    if (!battleCriesEnabled || !SoundService.enabled) return;
    CryService.playCry(id, rate: rate);
  }

  // --- Terreno elegido (cosmético, persiste) ---
  static const _terrainKey = 'pokearena_battle_terrain';
  static const _gbaTerrainKey = 'pokearena_gba_terrain';
  String terrainId = 'grass';
  BattleTerrain get terrain => terrainById(terrainId);

  // --- Modo GBA: consola retro en vez de la vista moderna ---
  bool gbaMode = true;

  void setGbaMode(bool v) {
    gbaMode = v;
    notifyListeners();
  }

  // --- Tamaños de equipo elegibles (1-3 por lado) ---
  int playerCount = 3;
  int enemyCount = 3;

  void setPlayerCount(int v) {
    playerCount = v.clamp(1, 3);
    notifyListeners();
  }

  void setEnemyCount(int v) {
    enemyCount = v.clamp(1, 3);
    notifyListeners();
  }

  /// Recorta los equipos al formato elegido (1v1, 2v2 o 3v3).
  void _sliceTeams() {
    final pCount = playerCount;
    final eCount = enemyCount;
    playerTeam = playerTeam.take(pCount).toList();
    playerTeamHp = playerTeamHp.take(pCount).toList();
    playerTeamMaxHp = playerTeamMaxHp.take(pCount).toList();
    enemyTeam = enemyTeam.take(eCount).toList();
    enemyTeamHp = enemyTeamHp.take(eCount).toList();
    enemyTeamMaxHp = enemyTeamMaxHp.take(eCount).toList();
    playerActive = 0;
    enemyActive = 0;
  }

  Future<void> loadSavedTerrain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_terrainKey);
      if (saved != null && battleTerrains.any((t) => t.id == saved)) {
        terrainId = saved;
        notifyListeners();
      }
      final savedGba = prefs.getString(_gbaTerrainKey);
      if (savedGba != null &&
          gbaTerrains.any((t) => t.id == savedGba)) {
        gbaTerrainId = savedGba;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setTerrain(String id) async {
    if (!battleTerrains.any((t) => t.id == id)) return;
    terrainId = id;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_terrainKey, id);
    } catch (_) {}
  }

  /// Terreno del modo Normal (vista GBA): lista propia de 10, con su
  /// propio guardado para no interferir con los 18 del 2.5D.
  String gbaTerrainId = 'gba-playa';
  BattleTerrain get gbaTerrain => gbaTerrainById(gbaTerrainId);

  Future<void> setGbaTerrain(String id) async {
    if (!gbaTerrains.any((t) => t.id == id)) return;
    gbaTerrainId = id;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_gbaTerrainKey, id);
    } catch (_) {}
  }

  /// Muestra el bocadillo del comentarista y, si [voice], lo dice en voz alta.
  void _say(
    BattleEvent event, {
    String attacker = '',
    String move = '',
    String incoming = '',
    bool voice = false,
  }) {
    commentary = commentaryFor(
      event,
      attacker: attacker,
      move: move,
      incoming: incoming,
      random: _random,
    );
    commentarySeq++;
    notifyListeners();
    if (voice && voiceEnabled && SoundService.enabled) {
      NarratorService.speak(commentary);
    }
  }

  void setVoice(bool v) {
    voiceEnabled = v;
    if (!v) NarratorService.stop();
    notifyListeners();
  }

  static const _taunts = [
    '🤖 Bot: "¿Eso fue un ataque?"',
    '🤖 Bot: "Mi abuela pega más fuerte."',
    '🤖 Bot: "Calculé tu derrota hace 3 turnos."',
    '🤖 Bot: "¡Buen intento!"',
    '🤖 Bot: "Ahora verás mi verdadero poder..."',
  ];

  void _resetBattleResources() {
    playerPp = [
      for (final p in playerTeam)
        [for (final m in movesFor(p)) m.maxPp],
    ];
    enemyPp = [
      for (final p in enemyTeam)
        [for (final m in movesFor(p)) m.maxPp],
    ];
    playerPotions = 2;
    enemyPotions = difficulty == BotDifficulty.easy ? 0 : 1;
    playerCharge = 0.0;
    enemyCharge = 0.0;
    lastMiss = false;
    lastUltimate = false;
  }

  /// PP que le quedan a mi movimiento [moveIdx] (los máximos si aún no empezó).
  int playerPpLeft(int moveIdx) {
    final moves = playerMoves;
    if (moveIdx < 0 || moveIdx >= moves.length) return 0;
    if (playerActive < playerPp.length && moveIdx < playerPp[playerActive].length) {
      return playerPp[playerActive][moveIdx];
    }
    return moves[moveIdx].maxPp;
  }

  /// Efectividad de uno de mis movimientos contra el rival activo (1.0 si
  /// todavía no hay datos de tipos cargados).
  double moveEffectiveness(BattleMove m) {
    final e = enemy;
    if (e == null) return 1.0;
    return effectivenessFor(
      attackType: m.type,
      defenderTypes: e.types,
      relations: _relations,
    );
  }

  /// Índice de mi movimiento más recomendable contra el rival (o null).
  int? get recommendedPlayerMove {
    final p = player;
    if (p == null) return null;
    final moves = playerMoves;
    return recommendedMove(
      moves: moves,
      ppLeft: [for (var i = 0; i < moves.length; i++) playerPpLeft(i)],
      effectiveness: [for (final m in moves) moveEffectiveness(m)],
      attackerTypes: p.types,
    );
  }

  int _ppLeft(bool isPlayer, int member, int moveIdx) {
    final table = isPlayer ? playerPp : enemyPp;
    if (member < 0 || member >= table.length) return 0;
    if (moveIdx < 0 || moveIdx >= table[member].length) return 0;
    return table[member][moveIdx];
  }

  double get _critChance {
    switch (difficulty) {
      case BotDifficulty.easy:
        return 0.05;
      case BotDifficulty.normal:
        return 0.10;
      case BotDifficulty.hard:
        return 0.15;
    }
  }

  Future<TypeRelations> _rel(String type) async {
    final lower = type.toLowerCase();
    if (_relations.containsKey(lower)) return _relations[lower]!;
    final r = await _api.fetchTypeRelations(lower);
    _relations[lower] = r;
    return r;
  }

  Future<void> _ensureRelations(List<String> types) async {
    await Future.wait(types.map(_rel));
  }

  void setDifficulty(BotDifficulty d) {
    difficulty = d;
    notifyListeners();
  }

  /// Define el equipo del jugador (se toman hasta 3).
  void setPlayerTeam(List<PokemonDetail> team) {
    playerTeam = team.take(3).toList();
    playerTeamHp = [for (final p in playerTeam) _battleHp(p)];
    playerTeamMaxHp = List.of(playerTeamHp);
    playerActive = 0;
    _resetBattleResources();
    notifyListeners();
  }

  /// Compat con la UI vieja de 1 luchador.
  void selectPlayer(PokemonDetail p) {
    // Si ya hay equipo, solo cambia el activo si está incluido;
    // si no, lo reemplaza por equipo de 1.
    final idx = playerTeam.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      playerActive = idx;
    } else {
      setPlayerTeam([p]);
    }
    notifyListeners();
  }

  /// Rival salvaje aleatorio (1-1025). Compat: equipo de 1.
  Future<void> rollEnemy() => rollEnemyTeam(size: 1);

  /// Equipo aleatorio del Bot (3 distintos, 1-1025), como el referente.
  Future<void> rollEnemyTeam({int size = 3}) async {
    loadingEnemy = true;
    notifyListeners();
    try {
      final ids = <int>{};
      while (ids.length < size) {
        ids.add(_random.nextInt(1025) + 1);
      }
      final details = await Future.wait(
        ids.map((id) => _api.fetchPokemonDetail(id)),
      );
      enemyTeam = details;
      enemyTeamHp = [for (final p in details) _battleHp(p)];
      enemyTeamMaxHp = List.of(enemyTeamHp);
      enemyActive = 0;
      await _ensureRelations(
        [for (final p in details) ...p.types],
      );
      _resetBattleResources();
    } catch (_) {
      enemyTeam = [];
      enemyTeamHp = [];
      enemyTeamMaxHp = [];
    } finally {
      loadingEnemy = false;
      notifyListeners();
    }
  }

  bool get canStart =>
      playerTeam.isNotEmpty && enemyTeam.isNotEmpty && !loadingEnemy;

  /// Empieza el combate. Gira la pantalla a horizontal **antes** de cargar
  /// (así la rotación ocurre mientras se prepara y no se pisa con la entrada)
  /// y la restaura si el combate no llega a arrancar.
  Future<void> startBattle() async {
    if (!canStart) return;
    if (!_orientationHeld) {
      _orientationHeld = true;
      BattleOrientation.lock();
    }
    try {
      await _startBattle();
    } catch (_) {
      _releaseOrientation();
      rethrow;
    }
    if (phase == BattlePhase.selecting) _releaseOrientation();
  }

  /// Suelta el bloqueo horizontal una sola vez, aunque se llame varias.
  void _releaseOrientation() {
    if (!_orientationHeld) return;
    _orientationHeld = false;
    BattleOrientation.release();
  }

  Future<void> _startBattle() async {
    if (!canStart) return;
    // Sin música de fondo en batalla (ya vendrá la suya propia).
    await MusicService.pauseBattle();
    await GbaSprites.load(); // entrenadores y Poké Balls (no lanza: si falla, se dibuja sin ellos)
    await VsFlashAssets.load(); // franjas del destello VS (igual, degrada sin romper nada)
    _sliceTeams();
    await _ensureRelations(
      [...player!.types, ...enemy!.types],
    );
    // Restaura PS al iniciar.
    playerTeamHp = List.of(playerTeamMaxHp);
    enemyTeamHp = List.of(enemyTeamMaxHp);
    playerActive = _firstAlive(playerTeamHp);
    enemyActive = _firstAlive(enemyTeamHp);
    phase = BattlePhase.fighting;
    winner = null;
    botThinking = false;
    lastAttacker = '';
    lastDamage = 0;
    lastEffectiveness = 1.0;
    lastCrit = false;
    lastMiss = false;
    lastUltimate = false;
    attackSeq = 0;
    lastMoveName = '';
    lastMoveType = 'normal';
    _resetBattleResources();
    _lowHpWarned = false;
    commentary = '';
    log
      ..clear()
      ..add(
        '¡Batalla ${playerTeam.length}v${enemyTeam.length} vs Bot (${difficultyLabel(difficulty)})!',
      )
      ..add(
        '¡${prettyName(player!.name)} vs ${prettyName(enemy!.name)}!',
      );
    // Entrada VS: la UI muestra overlay 1.4s con los 2 luchadores.
    // El finally garantiza que `entering` se apague aunque algo falle:
    // si quedara en true, los botones morirían con el menú visible.
    // Entrada con entrenadores en la vista GBA Normal y en la 2.5D; la vista
    // moderna (sin GBA ni horda) y Online conservan su entrada corta.
    introRich = gbaMode;
    introTotalMs = IntroTimeline.total;
    _introSkipped = false;
    entering = true;
    vsFlash = true;
    vsFlashIndex = _random.nextInt(VsFlashAssets.bands.length);
    try {
      _say(
        BattleEvent.start,
        attacker: prettyName(player!.name),
        incoming: prettyName(enemy!.name),
        voice: true,
      );
      // Grito de cada luchador al aparecer (solo si está activado). Con la
      // entrada de entrenadores suena cuando cada Pokémon sale de su bola.
      final playerId = player!.id;
      final enemyId = enemy!.id;
      var playerCried = false, enemyCried = false;
      void cryPlayer() {
        if (playerCried) return;
        playerCried = true;
        _cry(playerId);
      }

      void cryEnemy() {
        if (enemyCried || phase != BattlePhase.fighting || winner != null) return;
        enemyCried = true;
        _cry(enemyId);
      }

      if (introRich) {
        Future.delayed(const Duration(milliseconds: IntroTimeline.playerCryAt), cryPlayer);
        Future.delayed(
          const Duration(milliseconds: IntroTimeline.rivalCryAt),
          cryEnemy,
        );
      } else {
        cryPlayer();
        Future.delayed(const Duration(milliseconds: 700), cryEnemy);
      }
      notifyListeners();
      await (introRich ? _waitIntro(introTotalMs) : Future.delayed(const Duration(milliseconds: 1400)));
      if (introRich) {
        // Si se saltó la entrada, los gritos no se pierden.
        cryPlayer();
        Future.delayed(const Duration(milliseconds: 350), cryEnemy);
      }
    } finally {
      entering = false;
      notifyListeners();
    }
  }

  int _firstAlive(List<int> hps) {
    for (var i = 0; i < hps.length; i++) {
      if (hps[i] > 0) return i;
    }
    return 0;
  }

  bool get playerTeamAlive => playerTeamHp.any((hp) => hp > 0);
  bool get enemyTeamAlive => enemyTeamHp.any((hp) => hp > 0);

  List<int> get playerAliveIndices => [
        for (var i = 0; i < playerTeamHp.length; i++)
          if (playerTeamHp[i] > 0) i,
      ];

  /// Baja las banderas de turno y avisa. Se usa en `finally` para que
  /// un error nunca deje la batalla congelada (botones muertos).
  void _unlock() {
    busy = false;
    botThinking = false;
    notifyListeners();
  }

  /// Cambiar de luchador cuesta el turno: el Bot ataca enseguida.
  Future<void> switchPlayerFighter(int index) async {
    if (phase != BattlePhase.fighting ||
        busy ||
        botThinking ||
        entering ||
        winner != null) {
      return;
    }
    if (index == playerActive) return;
    if (index < 0 || index >= playerTeam.length) return;
    if (playerTeamHp[index] <= 0) return;
    busy = true;
    notifyListeners();
    try {
      playerActive = index;
      _lowHpWarned = false;
      log.add('¡Adelante, ${prettyName(player!.name)}!');
      _cry(player!.id);
      _say(
        BattleEvent.playerSwitch,
        incoming: prettyName(player!.name),
        voice: true,
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      await enemyTurn();
    } finally {
      _unlock();
    }
  }

  /// IA del Bot: fácil = azar; normal = 60% mejor; difícil = siempre mejor.
  /// Respeta PP restantes (no elige movimientos agotados).
  ({BattleMove move, int index}) _chooseBotMove() {
    final moves = enemyMoves;
    if (moves.isEmpty) {
      return (
        move: const BattleMove(name: 'Placaje', type: 'normal', power: 40),
        index: 0
      );
    }
    final avail = [
      for (var i = 0; i < moves.length; i++)
        if (_ppLeft(false, enemyActive, i) > 0) i,
    ];
    final pool = avail.isEmpty
        ? [for (var i = 0; i < moves.length; i++) i]
        : avail;
    if (pool.length == 1 || difficulty == BotDifficulty.easy) {
      final idx = pool[_random.nextInt(pool.length)];
      return (move: moves[idx], index: idx);
    }
    var bestIdx = pool.first;
    var bestScore = -1;
    for (final i in pool) {
      final dmg = calculateDamage(
        attacker: enemy!,
        defender: player!,
        move: moves[i],
        relations: _relations,
        randomFactor: 1.0,
      );
      if (dmg > bestScore) {
        bestScore = dmg;
        bestIdx = i;
      }
    }
    if (difficulty == BotDifficulty.hard) {
      return (move: moves[bestIdx], index: bestIdx);
    }
    final idx = _random.nextDouble() < 0.6
        ? bestIdx
        : pool[_random.nextInt(pool.length)];
    return (move: moves[idx], index: idx);
  }

  /// Ejecuta un golpe con PP, fallo, crítico y carga ultimate.
  /// Devuelve true si el defensor se debilitó.
  Future<bool> _execHit({
    required bool byPlayer,
    required BattleMove move,
    required int moveIdx,
  }) async {
    final atk = byPlayer ? player! : enemy!;
    final def = byPlayer ? enemy! : player!;
    // Consume PP (el ultimate consume la carga, no PP).
    if (!move.isUltimate) {
      final table = byPlayer ? playerPp : enemyPp;
      final member = byPlayer ? playerActive : enemyActive;
      if (member < table.length &&
          moveIdx >= 0 &&
          moveIdx < table[member].length &&
          table[member][moveIdx] > 0) {
        table[member][moveIdx]--;
      }
    }
    // ¿Falla? (precisión del movimiento).
    final missRoll = _random.nextDouble() * 100;
    final missed = missRoll > move.accuracy;
    lastAttacker = byPlayer ? 'player' : 'enemy';
    lastMoveName = move.name;
    lastMoveType = move.type;
    lastUltimate = move.isUltimate;
    lastMiss = missed;
    lastCrit = false;
    lastEffectiveness = 1.0;
    lastDamage = 0;
    attackSeq++;
    if (missed) {
      log.add(
        '💨 ¡${prettyName(atk.name)} falló ${move.name}! '
        '(prec. ${move.accuracy}%)',
      );
      BattleSound.playMiss();
      _say(BattleEvent.miss, voice: true);
      return false;
    }
    final dmgBase = calculateDamage(
      attacker: atk,
      defender: def,
      move: move,
      relations: _relations,
      randomFactor: 0.85 + _random.nextDouble() * 0.15,
    );
    final crit = _random.nextDouble() < _critChance;
    final raw = crit
        ? (dmgBase * (move.isUltimate ? 1.25 : 1.5)).floor()
        : dmgBase;
    // Escala de duración: el golpe quita menos para alargar la pelea.
    final dmg = (raw * damageScale).round().clamp(1, 9999);
    if (byPlayer) {
      enemyHp = (enemyHp - dmg).clamp(0, enemyMaxHp);
      playerCharge = (playerCharge + 20).clamp(0, 100);
      // En online el rival también carga su medidor (el bot lo ignora).
      enemyCharge =
          (enemyCharge + (dmg * 60 / enemyMaxHp)).clamp(0, 100);
    } else {
      playerHp = (playerHp - dmg).clamp(0, playerMaxHp);
      // Recibir daño también carga tu medidor (remontadas).
      playerCharge =
          (playerCharge + (dmg * 60 / playerMaxHp)).clamp(0, 100);
      enemyCharge = (enemyCharge + 20).clamp(0, 100);
    }
    final eff = effectivenessFor(
      attackType: move.type,
      defenderTypes: def.types,
      relations: _relations,
    );
    lastDamage = dmg;
    lastEffectiveness = eff;
    lastCrit = crit;
    log.add(
      '${move.isUltimate ? '🌟 ' : ''}${prettyName(atk.name)} usa '
      '${move.name} (-$dmg).${crit ? ' ¡Golpe crítico!' : ''} '
      '${effectivenessText(eff)}',
    );
    BattleSound.playHit(eff, crit, move.isUltimate,
        moveType: move.type, power: move.power);
    // Comentarista: lo especial con voz, lo normal solo en bocadillo.
    final atkName = prettyName(atk.name);
    if (move.isUltimate) {
      _say(BattleEvent.ultimate, attacker: atkName, voice: true);
    } else if (crit) {
      _say(BattleEvent.critical, attacker: atkName, voice: true);
    } else if (eff == 0.0) {
      _say(BattleEvent.noEffect, voice: true);
    } else if (eff >= 2.0) {
      _say(BattleEvent.superEffective, attacker: atkName, voice: true);
    } else if (eff < 1.0) {
      _say(BattleEvent.notVeryEffective, voice: false);
    } else {
      _say(
        BattleEvent.normalHit,
        attacker: atkName,
        move: move.name,
        voice: false,
      );
    }
    // Aviso de PS bajos una vez por luchador.
    if (!byPlayer &&
        playerHp > 0 &&
        !_lowHpWarned &&
        playerHp * 4 < playerMaxHp) {
      _lowHpWarned = true;
      _say(
        BattleEvent.playerLowHp,
        attacker: prettyName(player!.name),
        voice: true,
      );
    }
    // Taunt ocasional del Bot en difícil/normal.
    if (!byPlayer &&
        difficulty != BotDifficulty.easy &&
        _random.nextDouble() < 0.25) {
      log.add(_taunts[_random.nextInt(_taunts.length)]);
    }
    notifyListeners();
    return byPlayer ? enemyHp <= 0 : playerHp <= 0;
  }

  /// Ganchos públicos para la batalla online (reusan el motor local).
  /// El turno online resuelve con RNG compartido: ambos clientes ejecutan
  /// la misma secuencia y llegan al mismo resultado sin servidor de juego.
  Future<bool> execHit({
    required bool byPlayer,
    required BattleMove move,
    required int moveIdx,
  }) =>
      _execHit(byPlayer: byPlayer, move: move, moveIdx: moveIdx);

  Future<bool> handleFaint({required bool faintedEnemy}) =>
      _handleFaint(faintedEnemy: faintedEnemy);

  void resetBattleResources() => _resetBattleResources();

  int ppLeft(bool isPlayer, int member, int moveIdx) =>
      _ppLeft(isPlayer, member, moveIdx);

  Future<bool> _handleFaint({required bool faintedEnemy}) async {
    if (faintedEnemy) {
      log.add('💀 ¡${prettyName(enemy!.name)} rival cayó!');
      _cry(enemy!.id, rate: 0.6);
      _say(
        BattleEvent.enemyFaint,
        attacker: prettyName(enemy!.name),
        voice: true,
      );
      if (!enemyTeamAlive) {
        winner = 'player';
        log.add('¡Equipo rival debilitado! +${playerCharge.round()} carga final');
        BattleSound.playKo();
        _say(BattleEvent.victory, voice: true);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 1500));
        phase = BattlePhase.finished;
        // Terminó la batalla: vuelve la música de fondo.
        await MusicService.resumeBattle();
        notifyListeners();
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 900));
      enemyActive = _firstAlive(enemyTeamHp);
      log.add('¡El Bot envía a ${prettyName(enemy!.name)}!');
      _cry(enemy!.id);
      _say(
        BattleEvent.enemySwitch,
        incoming: prettyName(enemy!.name),
        voice: false,
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 650));
      return false;
    } else {
      log.add('💀 ¡${prettyName(player!.name)} se debilitó!');
      _cry(player!.id, rate: 0.6);
      _say(
        BattleEvent.playerFaint,
        attacker: prettyName(player!.name),
        voice: true,
      );
      if (!playerTeamAlive) {
        winner = 'enemy';
        log.add('¡Tu equipo cayó!');
        BattleSound.playKo();
        _say(BattleEvent.defeat, voice: true);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 1500));
        phase = BattlePhase.finished;
        // Terminó la batalla: vuelve la música de fondo.
        await MusicService.resumeBattle();
        notifyListeners();
        return true;
      }
      playerActive = _firstAlive(playerTeamHp);
      _lowHpWarned = false;
      log.add('¡Adelante, ${prettyName(player!.name)}!');
      _cry(player!.id);
      _say(
        BattleEvent.playerSwitch,
        incoming: prettyName(player!.name),
        voice: false,
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 650));
      return false;
    }
  }

  /// Ataque del jugador con orden por velocidad: el más rápido pega primero.
  Future<void> playerAttack(BattleMove move) async {
    if (phase != BattlePhase.fighting ||
        busy ||
        botThinking ||
        entering ||
        winner != null) {
      return;
    }
    final idx = playerMoves.indexWhere(
      (m) => m.name == move.name && m.type == move.type,
    );
    if (idx >= 0 && _ppLeft(true, playerActive, idx) <= 0) {
      log.add('⛔ ¡${move.name} sin PP! Elige otro.');
      notifyListeners();
      return;
    }
    busy = true;
    botThinking = true;
    notifyListeners();
    try {
      await Future.delayed(const Duration(milliseconds: 450));
      botThinking = false;

      final bot = _chooseBotMove();
      final pSpeed = player!.stats['speed'] ?? 50;
      final eSpeed = enemy!.stats['speed'] ?? 50;
      final playerFirst =
          pSpeed > eSpeed || (pSpeed == eSpeed && _random.nextBool());

      Future<void> botStrike() async {
        // Poción del Bot: si está bajo y le queda, 50% de curarse en vez de pegar.
        if (enemyHp > 0 &&
            enemyHp * 2 < enemyMaxHp &&
            enemyPotions > 0 &&
            _random.nextDouble() < 0.5) {
          enemyPotions--;
          final heal = (enemyMaxHp * 0.4).round();
          enemyHp = (enemyHp + heal).clamp(0, enemyMaxHp);
          log.add('🧪 ¡El Bot usa poción! +$heal PS.');
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 650));
          return;
        }
        final fainted = await _execHit(
          byPlayer: false,
          move: bot.move,
          moveIdx: bot.index,
        );
        await Future.delayed(const Duration(milliseconds: 650));
        if (fainted) await _handleFaint(faintedEnemy: false);
      }

      if (playerFirst) {
        final fainted = await _execHit(
          byPlayer: true,
          move: move,
          moveIdx: idx,
        );
        await Future.delayed(const Duration(milliseconds: 650));
        if (fainted) {
          final over = await _handleFaint(faintedEnemy: true);
          if (!over) await botStrike();
          return;
        }
        await botStrike();
      } else {
        log.add(
            '⚡ ¡${prettyName(enemy!.name)} es más rápido y golpea primero!');
        notifyListeners();
        await botStrike();
        if (winner != null || !enemyTeamAlive || !playerTeamAlive) {
          return;
        }
        if (playerHp > 0) {
          final fainted = await _execHit(
            byPlayer: true,
            move: move,
            moveIdx: idx,
          );
          await Future.delayed(const Duration(milliseconds: 650));
          if (fainted) await _handleFaint(faintedEnemy: true);
        }
      }
    } finally {
      _unlock();
    }
  }

  /// Poción del jugador: cura 40% y cede el turno al Bot.
  Future<void> usePotion() async {
    if (phase != BattlePhase.fighting ||
        busy ||
        botThinking ||
        entering ||
        winner != null ||
        playerPotions <= 0) {
      return;
    }
    if (playerHp >= playerMaxHp) {
      log.add('💊 ¡PS al máximo, guarda la poción!');
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      playerPotions--;
      final heal = (playerMaxHp * 0.4).round();
      playerHp = (playerHp + heal).clamp(0, playerMaxHp);
      log.add(
          '💊 ¡Poción! ${prettyName(player!.name)} recupera +$heal PS.');
      BattleSound.playPotion();
      _say(
        BattleEvent.potion,
        attacker: prettyName(player!.name),
        voice: true,
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 650));
      await enemyTurn();
    } finally {
      _unlock();
    }
  }

  /// Movimiento Z: requiere carga 100. No gasta PP, siempre acierta.
  Future<void> playerUltimate() async {
    if (phase != BattlePhase.fighting ||
        busy ||
        botThinking ||
        entering ||
        winner != null ||
        playerCharge < 100) {
      return;
    }
    busy = true;
    notifyListeners();
    try {
      playerCharge = 0;
      final ult = ultimateFor(player!);
      final fainted = await _execHit(
        byPlayer: true,
        move: ult,
        moveIdx: -1,
      );
      await Future.delayed(const Duration(milliseconds: 750));
      if (fainted) {
        await _handleFaint(faintedEnemy: true);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      await enemyTurn();
    } finally {
      _unlock();
    }
  }

  Future<void> enemyTurn() async {
    if (winner != null || phase != BattlePhase.fighting) return;
    botThinking = true;
    notifyListeners();
    try {
      await Future.delayed(const Duration(milliseconds: 700));
      botThinking = false;
      final bot = _chooseBotMove();
      final fainted = await _execHit(
        byPlayer: false,
        move: bot.move,
        moveIdx: bot.index,
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (fainted) await _handleFaint(faintedEnemy: false);
    } finally {
      botThinking = false;
      notifyListeners();
    }
  }

  void backToSelect() {
    _releaseOrientation(); // vuelve la orientación libre y las barras del sistema
    phase = BattlePhase.selecting;
    winner = null;
    botThinking = false;
    commentary = '';
    log.clear();
    NarratorService.stop();
    CryService.stop();
    MusicService.resumeBattle();
    notifyListeners();
  }

  /// Limpia equipos y estado (cambio de usuario en el login).
  void resetTeams() {
    _releaseOrientation();
    playerTeam = [];
    enemyTeam = [];
    playerTeamHp = [];
    playerTeamMaxHp = [];
    enemyTeamHp = [];
    enemyTeamMaxHp = [];
    playerActive = 0;
    enemyActive = 0;
    phase = BattlePhase.selecting;
    winner = null;
    busy = false;
    botThinking = false;
    entering = false;
    log.clear();
    commentary = '';
    playerCharge = 0.0;
    enemyCharge = 0.0;
    playerPotions = 2;
    enemyPotions = 1;
    playerPp = [];
    enemyPp = [];
    notifyListeners();
  }
}
