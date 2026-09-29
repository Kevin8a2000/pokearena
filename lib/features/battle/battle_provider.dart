import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/models/pokemon.dart';
import '../../core/models/type_relations.dart';
import '../../core/services/pokeapi_service.dart';
import 'battle_calculator.dart';

enum BattlePhase { selecting, fighting, finished }

/// Estado del combate por turnos (Sprint 3).
/// Usa stats reales + efectividad de tipos vía PokeAPI.
class BattleProvider extends ChangeNotifier {
  final PokeApiService _api;
  final Random _random;

  BattleProvider(this._api, [Random? random]) : _random = random ?? Random();

  BattlePhase phase = BattlePhase.selecting;
  bool loadingEnemy = false;

  PokemonDetail? player;
  PokemonDetail? enemy;
  List<BattleMove> playerMoves = [];
  List<BattleMove> enemyMoves = [];

  int playerHp = 0;
  int enemyHp = 0;
  int playerMaxHp = 1;
  int enemyMaxHp = 1;

  bool busy = false;
  String? winner; // 'player' | 'enemy'
  final List<String> log = [];
  final Map<String, TypeRelations> _relations = {};

  // Para animaciones de la UI: quién atacó último, cuánto pegó,
  // con qué efectividad, si fue crítico y un contador que cambia cada golpe.
  String lastAttacker = '';
  int lastDamage = 0;
  double lastEffectiveness = 1.0;
  bool lastCrit = false;
  int attackSeq = 0;
  // Poder que se está viendo volar (para pintar el proyectil de su color).
  String lastMoveName = '';
  String lastMoveType = 'normal';

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

  /// Rival salvaje aleatorio (1-1025).
  Future<void> rollEnemy() async {
    loadingEnemy = true;
    notifyListeners();
    try {
      final id = _random.nextInt(1025) + 1;
      enemy = await _api.fetchPokemonDetail(id);
      enemyMaxHp = enemy!.stats['hp'] ?? 50;
      enemyHp = enemyMaxHp;
      enemyMoves = movesFor(enemy!);
      await _ensureRelations(enemy!.types);
    } catch (_) {
      enemy = null;
    } finally {
      loadingEnemy = false;
      notifyListeners();
    }
  }

  void selectPlayer(PokemonDetail p) {
    player = p;
    playerMaxHp = p.stats['hp'] ?? 50;
    playerHp = playerMaxHp;
    playerMoves = movesFor(p);
    notifyListeners();
  }

  bool get canStart => player != null && enemy != null && !loadingEnemy;

  Future<void> startBattle() async {
    if (!canStart) return;
    await _ensureRelations([...player!.types, ...enemy!.types]);
    phase = BattlePhase.fighting;
    winner = null;
    lastAttacker = '';
    lastDamage = 0;
    lastEffectiveness = 1.0;
    lastCrit = false;
    attackSeq = 0;
    lastMoveName = '';
    lastMoveType = 'normal';
    log
      ..clear()
      ..add('¡${prettyName(player!.name)} vs ${prettyName(enemy!.name)} salvaje!');
    // El más rápido ataca primero si el rival es más veloz: ataca el rival.
    final pSpeed = player!.stats['speed'] ?? 50;
    final eSpeed = enemy!.stats['speed'] ?? 50;
    notifyListeners();
    if (eSpeed > pSpeed) {
      await enemyTurn();
    }
  }

  Future<void> playerAttack(BattleMove move) async {
    if (phase != BattlePhase.fighting || busy || winner != null) return;
    busy = true;
    notifyListeners();

    final dmgBase = calculateDamage(
      attacker: player!,
      defender: enemy!,
      move: move,
      relations: _relations,
      randomFactor: 0.85 + _random.nextDouble() * 0.15,
    );
    // 10% de golpe crítico x1.5 para emoción.
    final crit = _random.nextDouble() < 0.10;
    final dmg = crit ? (dmgBase * 1.5).floor() : dmgBase;
    enemyHp = (enemyHp - dmg).clamp(0, enemyMaxHp);
    final eff = effectivenessFor(
      attackType: move.type,
      defenderTypes: enemy!.types,
      relations: _relations,
    );
    lastAttacker = 'player';
    lastDamage = dmg;
    lastEffectiveness = eff;
    lastCrit = crit;
    lastMoveName = move.name;
    lastMoveType = move.type;
    attackSeq++;
    log.add(
      '${prettyName(player!.name)} usa ${move.name} (-$dmg).${crit ? ' ¡Golpe crítico!' : ''} ${effectivenessText(eff)}',
    );
    notifyListeners();

    if (enemyHp <= 0) {
      winner = 'player';
      log.add('¡Rival debilitado!');
      // Pausa dramática: se ve el K.O. en la arena antes del resultado.
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 1500));
      phase = BattlePhase.finished;
      busy = false;
      notifyListeners();
      return;
    }
    await Future.delayed(const Duration(milliseconds: 650));
    await enemyTurn();
    busy = false;
    notifyListeners();
  }

  Future<void> enemyTurn() async {
    if (winner != null) return;
    final move = enemyMoves[_random.nextInt(enemyMoves.length)];
    final dmgBase = calculateDamage(
      attacker: enemy!,
      defender: player!,
      move: move,
      relations: _relations,
      randomFactor: 0.85 + _random.nextDouble() * 0.15,
    );
    final crit = _random.nextDouble() < 0.10;
    final dmg = crit ? (dmgBase * 1.5).floor() : dmgBase;
    playerHp = (playerHp - dmg).clamp(0, playerMaxHp);
    final eff = effectivenessFor(
      attackType: move.type,
      defenderTypes: player!.types,
      relations: _relations,
    );
    lastAttacker = 'enemy';
    lastDamage = dmg;
    lastEffectiveness = eff;
    lastCrit = crit;
    lastMoveName = move.name;
    lastMoveType = move.type;
    attackSeq++;
    log.add(
      '${prettyName(enemy!.name)} usa ${move.name} (-$dmg).${crit ? ' ¡Golpe crítico!' : ''} ${effectivenessText(eff)}',
    );
    if (playerHp <= 0) {
      winner = 'enemy';
      log.add('¡Tu Pokémon se debilitó!');
      // Pausa dramática del K.O. antes de mostrar el resultado.
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 1500));
      phase = BattlePhase.finished;
    }
    notifyListeners();
  }

  void backToSelect() {
    phase = BattlePhase.selecting;
    winner = null;
    log.clear();
    notifyListeners();
  }
}
