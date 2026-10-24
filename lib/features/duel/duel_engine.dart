import 'dart:math' as math;

import '../../core/models/pokemon.dart';
import '../../core/models/type_relations.dart';
import '../battle/battle_calculator.dart';

/// Motor del modo Duelo (pelea 2D en tiempo real). Lógica pura, sin Flutter:
/// la pantalla solo lo avanza con `step(dt)` y dibuja su estado.
///
/// La arena mide [DuelTuning.arenaW] unidades de ancho; `x` es la posición del
/// centro de cada luchador y `y` su altura sobre el suelo (0 = en el suelo).

/// Todas las constantes de equilibrio en un solo sitio.
class DuelTuning {
  static const double arenaW = 100;
  static const double minX = 8;
  static const double maxX = 92;

  /// Duración de cada ronda en segundos.
  static const double duration = 90;

  /// Rondas del combate (mejor de 3 = gana quien llegue a 2).
  static const int roundsToWin = 2;
  static const int maxRounds = 5; // 3 + desempates

  /// PS = stat base × este factor (los golpes salen de `calculateDamage`).
  static const double hpFactor = 9.0;

  static const double walkSpeed = 34; // unidades/s
  static const double runMult = 1.7;
  static const double runDrain = 14; // stamina/s

  // Golpe cuerpo a cuerpo (ATAQUE BÁSICO).
  static const double meleeRange = 17;
  static const double meleeHitAt = 0.12; // s desde que se pulsa hasta el golpe
  static const double meleeCooldown = 0.45;

  // Poderes (3 por luchador).
  static const double projectileRadius = 5;

  // PODERES: una horda de disparos seguidos (botón principal de poderes).
  static const double hordeCost = 35;
  static const double hordeCooldown = 2.2;
  static const int hordeShots = 5;
  static const double hordeWindup = 0.15;
  static const double hordeInterval = 0.12;
  static const int hordePower = 26;
  static const double hordeSpeed = 95;

  // Esquivar (impulso con invulnerabilidad).
  static const double dodgeCost = 25;
  static const double dodgeTime = 0.3;
  static const double dodgeCooldown = 0.8;
  static const double dodgeSpeed = 95;

  // Deslizamiento: pasa por debajo de proyectiles (no del cuerpo a cuerpo).
  static const double slideCost = 10;
  static const double slideTime = 0.3;
  static const double slideSpeed = 80;
  static const double slideCooldown = 0.9;

  // Bloqueo (mantenido).
  static const double guardReduction = 0.75;
  static const double guardDrain = 10; // stamina/s
  static const double guardMinToRaise = 15; // tras romperse la guardia
  static const double guardHitDrain = 6;

  // Salto.
  static const double jumpCost = 10;
  static const double jumpSpeed = 90;
  static const double gravity = 260;

  /// Por encima de esta altura se evitan golpes cuerpo a cuerpo y proyectiles.
  static const double airborneY = 8;

  // Stamina.
  static const double staminaMax = 100;
  static const double staminaRegen = 20; // por segundo

  // ULTRA / FRENESÍ.
  static const double ultraMax = 100;
  static const double ultraGainDealt = 2.4; // % de barra por % de PS quitado
  static const double ultraGainTaken = 1.6;
  static const double ultraWindup = 0.45;
  static const double ultraTime = 1.0;
  static const double ultraRange = 70;
  static const int ultraPower = 100;

  // Apoyo.
  static const double supportCooldown = 12;
  static const double supportFireAt = 0.3;
  static const double supportStay = 1.0;
  static const int supportPower = 50;

  // Golpeado.
  static const double hitStun = 0.28;
  static const double knockback = 5;

  // Combo.
  static const double comboWindow = 1.5;
  static const double comboBonus = 0.10;
  static const double comboMaxMult = 1.5;

  static const double critChance = 0.08;
  static const double critMult = 1.5;
}

enum DuelSide { player, enemy }

DuelSide opposite(DuelSide s) => s == DuelSide.player ? DuelSide.enemy : DuelSide.player;

enum DuelState { idle, attack, skill, ultra, dodge, slide, hurt, ko }

/// Forma de cada poder: rápido, onda ancha o bomba lenta.
enum DuelSkillShape { fast, wave, bomb }

/// Un poder del luchador (el nombre sale del tipo).
class DuelSkill {
  final String name;
  final String type;
  final DuelSkillShape shape;
  final BattleMove move;
  final double cost;
  final double cooldown;
  final double windup;
  final double speed;
  final double radius;

  const DuelSkill({
    required this.name,
    required this.type,
    required this.shape,
    required this.move,
    required this.cost,
    required this.cooldown,
    required this.windup,
    required this.speed,
    required this.radius,
  });

  /// La bomba explota aunque el rival esté saltando.
  bool get ignoresAir => shape == DuelSkillShape.bomb;
}

/// Nombres de los 3 poderes por tipo: rápido, onda y bomba.
const Map<String, List<String>> duelSkillNames = {
  'normal': ['Ataque Rápido', 'Onda Cuerpo', 'Bomba Huevo'],
  'fire': ['Ascuas', 'Lanzallamas', 'Bomba Ígnea'],
  'water': ['Pistola Agua', 'Hidropulso', 'Bomba Burbuja'],
  'grass': ['Látigo Cepa', 'Hoja Afilada', 'Bomba Germen'],
  'electric': ['Impactrueno', 'Onda Trueno', 'Bomba Voltio'],
  'ice': ['Copo Gélido', 'Viento Hielo', 'Bomba Nieve'],
  'fighting': ['Onda Vacío', 'Esfera Aural', 'Bomba Puño'],
  'poison': ['Picotazo Veneno', 'Ácido', 'Bomba Lodo'],
  'ground': ['Disparo Lodo', 'Ola Sísmica', 'Bomba Arena'],
  'flying': ['Tornado', 'Aire Afilado', 'Bomba Viento'],
  'psychic': ['Confusión', 'Psíquico', 'Bomba Mental'],
  'bug': ['Zumbido', 'Pin Misil', 'Bomba Polen'],
  'rock': ['Lanzarrocas', 'Avalancha', 'Bomba Roca'],
  'ghost': ['Bola Sombra', 'Rayo Confuso', 'Bomba Espectro'],
  'dragon': ['Garra Dragón', 'Pulso Dragón', 'Bomba Dragón'],
  'dark': ['Mordisco', 'Pulso Umbrío', 'Bomba Noche'],
  'steel': ['Cañón Foco', 'Garra Metal', 'Bomba Acero'],
  'fairy': ['Viento Feérico', 'Brillo Mágico', 'Bomba Hada'],
};

/// Los 3 poderes de un Pokémon: rápido (tipo 1), onda (tipo 2 si lo tiene) y
/// bomba (tipo 1). No hay lista real de movimientos: se derivan del tipo.
List<DuelSkill> duelSkillsFor(PokemonDetail p) {
  final t1 = p.types.isNotEmpty ? p.types.first.toLowerCase() : 'normal';
  final t2 = p.types.length > 1 ? p.types[1].toLowerCase() : t1;
  String nameOf(String t, int i) => (duelSkillNames[t] ?? duelSkillNames['normal']!)[i];
  DuelSkill make(int i, String t, DuelSkillShape shape, int power, double cost, double cd, double windup, double speed, double radius) => DuelSkill(
        name: nameOf(t, i),
        type: t,
        shape: shape,
        move: BattleMove(name: nameOf(t, i), type: t, power: power, maxPp: 99, accuracy: 100),
        cost: cost,
        cooldown: cd,
        windup: windup,
        speed: speed,
        radius: radius,
      );
  return [
    make(0, t1, DuelSkillShape.fast, 30, 15, 0.5, 0.12, 110, 4),
    make(1, t2, DuelSkillShape.wave, 45, 25, 1.0, 0.2, 70, 7),
    make(2, t1, DuelSkillShape.bomb, 60, 40, 1.8, 0.3, 42, 12),
  ];
}

/// Entrada de un luchador en un instante. `move` y las teclas mantenidas
/// (`guard`, `run`) valen mientras estén pulsadas; el resto de botones valen
/// `true`/`>0` solo en el tick en el que se pulsan.
class DuelInput {
  final double move; // -1 izquierda, 1 derecha
  final bool attack;

  /// 0 = nada; 1, 2 o 3 = poder.
  final int skill;

  /// Horda de poderes: varios disparos seguidos del tipo del luchador.
  final bool horde;
  final bool ultra;
  final bool dodge;
  final bool jump;
  final bool slide;

  /// 0 = nada; 1 o 2 = compañero de apoyo.
  final int support;
  final bool guard;
  final bool run;
  const DuelInput({
    this.move = 0,
    this.attack = false,
    this.skill = 0,
    this.horde = false,
    this.ultra = false,
    this.dodge = false,
    this.jump = false,
    this.slide = false,
    this.support = 0,
    this.guard = false,
    this.run = false,
  });
  static const none = DuelInput();
}

enum DuelEventType { hit, skillHit, ultraHit, blocked, dodge, jump, slide, ko, combo, timeUp, denied, ultra, support }

/// Hecho ocurrido en un tick, para efectos y sonido de la pantalla.
class DuelEvent {
  final DuelEventType type;
  final DuelSide side; // quien lo provoca (o quien se queda sin PS en `ko`)
  final double x;
  final double y;
  final int damage;
  final double effectiveness;
  final bool crit;
  final int combo;
  final String moveType;
  const DuelEvent(
    this.type,
    this.side, {
    this.x = 0,
    this.y = 0,
    this.damage = 0,
    this.effectiveness = 1,
    this.crit = false,
    this.combo = 0,
    this.moveType = 'normal',
  });
}

/// Proyectil en vuelo (poder o disparo de un compañero de apoyo).
class DuelProjectile {
  final DuelSide owner;
  final String type;
  final DuelSkillShape shape;
  double x;
  final double startX;
  final double dir; // -1 o 1
  final double speed;
  final double radius;
  final int damage;
  final double effectiveness;
  final bool crit;
  final bool ignoresAir;
  final bool fromSupport;
  bool alive = true;
  DuelProjectile({
    required this.owner,
    required this.type,
    required this.shape,
    required this.x,
    required this.dir,
    required this.speed,
    required this.radius,
    required this.damage,
    required this.effectiveness,
    required this.crit,
    required this.ignoresAir,
    this.fromSupport = false,
  }) : startX = x;

  /// Altura dibujada (solo la bomba va en arco).
  double get arcY => shape == DuelSkillShape.bomb ? math.sin(math.min(1.0, (x - startX).abs() / 60) * math.pi) * 14 : 0;
}

/// Compañero de apoyo disponible para un luchador.
class DuelSupportSlot {
  final PokemonDetail pokemon;
  final BattleMove move;
  double cooldown = 0;
  DuelSupportSlot(this.pokemon)
      : move = BattleMove(
          name: 'Apoyo',
          type: pokemon.types.isNotEmpty ? pokemon.types.first.toLowerCase() : 'normal',
          power: DuelTuning.supportPower,
          maxPp: 99,
          accuracy: 100,
        );
  double get cooldownFraction => (cooldown / DuelTuning.supportCooldown).clamp(0.0, 1.0).toDouble();
  bool get ready => cooldown <= 0;
}

/// Compañero que ha entrado a pelear un momento.
class DuelSupportAct {
  final DuelSide side;
  final DuelSupportSlot slot;
  final double x;
  double t = 0;
  bool fired = false;
  DuelSupportAct(this.side, this.slot, this.x);
}

class DuelFighter {
  final DuelSide side;
  final PokemonDetail pokemon;
  final BattleMove basic;
  final List<DuelSkill> skills;
  final BattleMove ultraMove;
  final BattleMove hordeMove;
  final int maxHp;
  double hp;
  double x;
  double y = 0;
  double vy = 0;
  double stamina = DuelTuning.staminaMax;
  double ultra = 0; // 0..ultraMax (ULTRA del jugador, FRENESÍ del rival)
  double facing; // 1 = mira a la derecha
  DuelState state = DuelState.idle;
  double stateT = 0; // tiempo en el estado actual
  double attackCd = 0;
  final List<double> skillCd = [0, 0, 0];
  double hordeCd = 0;
  bool _horde = false;
  int _hordeFired = 0;
  double dodgeCd = 0;
  double slideCd = 0;
  double invulnerable = 0;
  double dodgeDir = 0; // sentido del impulso/deslizamiento (-1/1)
  bool guarding = false;
  bool running = false;
  bool _guardBroken = false;
  int combo = 0;
  double comboT = 0;
  bool _pendingMelee = false;
  int _pendingSkill = -1;
  bool _pendingUltra = false;

  DuelFighter({
    required this.side,
    required this.pokemon,
    required this.basic,
    required this.skills,
    required this.ultraMove,
    required this.hordeMove,
    required this.x,
    required this.facing,
  })  : maxHp = math.max(1, ((pokemon.stats['hp'] ?? 50) * DuelTuning.hpFactor).round()),
        hp = math.max(1, ((pokemon.stats['hp'] ?? 50) * DuelTuning.hpFactor).round()).toDouble();

  bool get airborne => y >= DuelTuning.airborneY;
  bool get alive => hp > 0;
  double get hpFraction => (hp / maxHp).clamp(0.0, 1.0).toDouble();
  double get staminaFraction => (stamina / DuelTuning.staminaMax).clamp(0.0, 1.0).toDouble();
  double get ultraFraction => (ultra / DuelTuning.ultraMax).clamp(0.0, 1.0).toDouble();
  bool get ultraReady => ultra >= DuelTuning.ultraMax;
  bool get sliding => state == DuelState.slide;
  bool get busy => state != DuelState.idle;
  bool canSkill(int i) => !busy && !guarding && i >= 0 && i < skills.length && skillCd[i] <= 0 && stamina >= skills[i].cost;
  bool get canDodge => (state == DuelState.idle || state == DuelState.attack || state == DuelState.skill) && dodgeCd <= 0 && stamina >= DuelTuning.dodgeCost;
  bool get canJump => !busy && y <= 0 && stamina >= DuelTuning.jumpCost;
  bool get canAttack => !busy && !guarding && attackCd <= 0;
  bool get canSlide => !busy && y <= 0 && slideCd <= 0 && stamina >= DuelTuning.slideCost;
  bool get canUltra => !busy && !guarding && ultraReady;
  bool get canHorde => !busy && !guarding && hordeCd <= 0 && stamina >= DuelTuning.hordeCost;

  void _enter(DuelState s) {
    state = s;
    stateT = 0;
  }
}

class DuelEngine {
  final DuelFighter player;
  final DuelFighter enemy;
  final Map<String, TypeRelations> relations;
  final math.Random rng;
  final List<DuelProjectile> projectiles = [];
  final List<DuelSupportSlot> playerSupports;
  final List<DuelSupportSlot> enemySupports;
  final List<DuelSupportAct> supportActs = [];

  double timeLeft;
  DuelSide? winnerSide;
  bool draw = false;
  bool over = false;
  bool ko = false;

  DuelEngine({
    required PokemonDetail player,
    required PokemonDetail enemy,
    this.relations = const {},
    double duration = DuelTuning.duration,
    math.Random? rng,
    List<PokemonDetail> playerSupports = const [],
    List<PokemonDetail> enemySupports = const [],
  })  : rng = rng ?? math.Random(),
        timeLeft = duration,
        playerSupports = [for (final p in playerSupports.take(2)) DuelSupportSlot(p)],
        enemySupports = [for (final p in enemySupports.take(2)) DuelSupportSlot(p)],
        player = _fighter(DuelSide.player, player, 25, 1),
        enemy = _fighter(DuelSide.enemy, enemy, 75, -1);

  static const _basicMove = BattleMove(name: 'Ataque Básico', type: 'normal', power: 40, maxPp: 99, accuracy: 100);

  static DuelFighter _fighter(DuelSide side, PokemonDetail p, double x, double facing) {
    final t1 = p.types.isNotEmpty ? p.types.first.toLowerCase() : 'normal';
    return DuelFighter(
      side: side,
      pokemon: p,
      basic: _basicMove,
      skills: duelSkillsFor(p),
      ultraMove: BattleMove(name: 'ULTRA', type: t1, power: DuelTuning.ultraPower, maxPp: 1, accuracy: 100, isUltimate: true),
      hordeMove: BattleMove(name: 'Horda', type: t1, power: DuelTuning.hordePower, maxPp: 99, accuracy: 100),
      x: x,
      facing: facing,
    );
  }

  DuelFighter fighter(DuelSide s) => s == DuelSide.player ? player : enemy;

  List<DuelSupportSlot> supportsOf(DuelSide s) => s == DuelSide.player ? playerSupports : enemySupports;

  /// Avanza [dt] segundos y devuelve lo ocurrido.
  List<DuelEvent> step(double dt, DuelInput playerInput, DuelInput enemyInput) {
    final events = <DuelEvent>[];
    if (over) return events;
    dt = dt.clamp(0.0, 0.1).toDouble();

    _updateFighter(player, enemy, playerInput, dt, events);
    _updateFighter(enemy, player, enemyInput, dt, events);
    _updateSupports(dt, playerInput.support, enemyInput.support, events);
    _updateProjectiles(dt, events);

    if (!over) {
      timeLeft -= dt;
      if (timeLeft <= 0) {
        timeLeft = 0;
        _finishByTime(events);
      }
    }
    return events;
  }

  // ------------------------------------------------------------------ luchador

  void _updateFighter(DuelFighter f, DuelFighter foe, DuelInput input, double dt, List<DuelEvent> events) {
    if (f.state == DuelState.ko) return;

    // Tiempos y recuperación.
    f.stateT += dt;
    f.attackCd = math.max(0, f.attackCd - dt);
    for (var i = 0; i < f.skillCd.length; i++) {
      f.skillCd[i] = math.max(0, f.skillCd[i] - dt);
    }
    f.dodgeCd = math.max(0, f.dodgeCd - dt);
    f.hordeCd = math.max(0, f.hordeCd - dt);
    f.slideCd = math.max(0, f.slideCd - dt);
    f.invulnerable = math.max(0, f.invulnerable - dt);
    if (f.combo > 0) {
      f.comboT -= dt;
      if (f.comboT <= 0) f.combo = 0;
    }

    // Siempre mira al rival (estilo juego de pelea) salvo en los impulsos.
    if (f.state != DuelState.dodge && f.state != DuelState.slide) {
      final dx = foe.x - f.x;
      if (dx.abs() > 0.5) f.facing = dx > 0 ? 1 : -1;
    }

    // Salto / gravedad.
    if (f.y > 0 || f.vy > 0) {
      f.vy -= DuelTuning.gravity * dt;
      f.y += f.vy * dt;
      if (f.y <= 0) {
        f.y = 0;
        f.vy = 0;
      }
    }

    // Estados con duración.
    switch (f.state) {
      case DuelState.hurt:
        if (f.stateT >= DuelTuning.hitStun) f._enter(DuelState.idle);
      case DuelState.dodge:
        f.x = _clampX(f.x + f.dodgeDir * DuelTuning.dodgeSpeed * dt);
        if (f.stateT >= DuelTuning.dodgeTime) f._enter(DuelState.idle);
      case DuelState.slide:
        f.x = _clampX(f.x + f.dodgeDir * DuelTuning.slideSpeed * dt);
        if (f.stateT >= DuelTuning.slideTime) f._enter(DuelState.idle);
      case DuelState.attack:
        if (f._pendingMelee && f.stateT >= DuelTuning.meleeHitAt) {
          f._pendingMelee = false;
          _resolveMelee(f, foe, events);
        }
        if (f.stateT >= DuelTuning.meleeCooldown) f._enter(DuelState.idle);
      case DuelState.skill:
        if (f._horde) {
          // Horda: un disparo cada `hordeInterval` tras la preparación.
          final due = ((f.stateT - DuelTuning.hordeWindup) / DuelTuning.hordeInterval).floor() + 1;
          while (f._hordeFired < DuelTuning.hordeShots && f._hordeFired < due) {
            f._hordeFired++;
            _spawnHordeShot(f, foe);
          }
          final end = DuelTuning.hordeWindup + DuelTuning.hordeShots * DuelTuning.hordeInterval + 0.12;
          if (f._hordeFired >= DuelTuning.hordeShots && f.stateT >= end) {
            f._horde = false;
            f._enter(DuelState.idle);
          }
          break;
        }
        final skill = f._pendingSkill >= 0 ? f.skills[f._pendingSkill] : null;
        if (skill != null && f.stateT >= skill.windup) {
          f._pendingSkill = -1;
          _spawnSkill(f, foe, skill);
        }
        if (f.stateT >= (skill?.windup ?? 0.2) + 0.2 && f._pendingSkill < 0) f._enter(DuelState.idle);
      case DuelState.ultra:
        if (f._pendingUltra && f.stateT >= DuelTuning.ultraWindup) {
          f._pendingUltra = false;
          _resolveUltra(f, foe, events);
        }
        if (f.stateT >= DuelTuning.ultraTime) f._enter(DuelState.idle);
      default:
        break;
    }
    if (over) return;

    // Guardia (mantenida): drena stamina y se rompe si se agota.
    if (f._guardBroken && f.stamina >= DuelTuning.guardMinToRaise) f._guardBroken = false;
    f.guarding = input.guard && f.state == DuelState.idle && f.y <= 0 && !f._guardBroken && f.stamina > 0;
    if (f.guarding) {
      f.stamina = math.max(0, f.stamina - DuelTuning.guardDrain * dt);
      if (f.stamina <= 0) {
        f._guardBroken = true;
        f.guarding = false;
      }
    }

    // Acciones nuevas (no se pueden encadenar con estados ocupados).
    if (input.dodge) {
      if (f.canDodge) {
        f.stamina -= DuelTuning.dodgeCost;
        f.dodgeCd = DuelTuning.dodgeCooldown;
        f.invulnerable = DuelTuning.dodgeTime;
        f._pendingMelee = false;
        f._pendingSkill = -1;
        f._horde = false;
        f._pendingUltra = false;
        f.guarding = false;
        f.dodgeDir = input.move == 0 ? -f.facing : input.move.sign;
        f._enter(DuelState.dodge);
        events.add(DuelEvent(DuelEventType.dodge, f.side, x: f.x, y: f.y));
      } else if (f.state != DuelState.dodge) {
        events.add(DuelEvent(DuelEventType.denied, f.side));
      }
    }
    if (input.slide) {
      if (f.canSlide) {
        f.stamina -= DuelTuning.slideCost;
        f.slideCd = DuelTuning.slideCooldown;
        f.guarding = false;
        f.dodgeDir = input.move == 0 ? f.facing : input.move.sign;
        f._enter(DuelState.slide);
        events.add(DuelEvent(DuelEventType.slide, f.side, x: f.x));
      } else if (f.state != DuelState.slide) {
        events.add(DuelEvent(DuelEventType.denied, f.side));
      }
    }
    if (input.jump) {
      if (f.canJump) {
        f.stamina -= DuelTuning.jumpCost;
        f.vy = DuelTuning.jumpSpeed;
        f.y = 0.01;
        f.guarding = false;
        events.add(DuelEvent(DuelEventType.jump, f.side, x: f.x));
      } else if (f.y <= 0) {
        events.add(DuelEvent(DuelEventType.denied, f.side));
      }
    }
    if (input.ultra) {
      if (f.canUltra) {
        f.ultra = 0;
        f._pendingUltra = true;
        f._enter(DuelState.ultra);
        events.add(DuelEvent(DuelEventType.ultra, f.side, x: f.x, moveType: f.ultraMove.type));
      } else {
        events.add(DuelEvent(DuelEventType.denied, f.side));
      }
    } else if (input.horde) {
      if (f.canHorde) {
        f.stamina -= DuelTuning.hordeCost;
        f.hordeCd = DuelTuning.hordeCooldown;
        f._horde = true;
        f._hordeFired = 0;
        f._enter(DuelState.skill);
      } else {
        events.add(DuelEvent(DuelEventType.denied, f.side));
      }
    } else if (input.skill > 0) {
      final i = input.skill - 1;
      if (f.canSkill(i)) {
        f.stamina -= f.skills[i].cost;
        f.skillCd[i] = f.skills[i].cooldown;
        f._pendingSkill = i;
        f._enter(DuelState.skill);
      } else {
        events.add(DuelEvent(DuelEventType.denied, f.side));
      }
    } else if (input.attack) {
      if (f.canAttack) {
        f.attackCd = DuelTuning.meleeCooldown;
        f._pendingMelee = true;
        f._enter(DuelState.attack);
      }
    }

    // Movimiento (no al atacar, esquivar, bloquear ni estar aturdido).
    f.running = false;
    if (f.state == DuelState.idle && !f.guarding && input.move != 0) {
      var speed = DuelTuning.walkSpeed;
      if (input.run && f.stamina > 0.5) {
        f.running = true;
        speed *= DuelTuning.runMult;
        f.stamina = math.max(0, f.stamina - DuelTuning.runDrain * dt);
      }
      f.x = _clampX(f.x + input.move.clamp(-1.0, 1.0) * speed * dt);
    }

    // Regeneración de stamina: no mientras corre ni bloquea.
    if (!f.running && !f.guarding) {
      f.stamina = math.min(DuelTuning.staminaMax, f.stamina + DuelTuning.staminaRegen * dt);
    }
  }

  double _clampX(double x) => x.clamp(DuelTuning.minX, DuelTuning.maxX).toDouble();

  // ------------------------------------------------------------------- golpes

  double _effectiveness(BattleMove m, DuelFighter defender) => effectivenessFor(
        attackType: m.type,
        defenderTypes: defender.pokemon.types,
        relations: relations,
      );

  /// Daño ya con efectividad, STAB, crítico y combo del atacante.
  (int, bool, double) _damage(DuelFighter atk, DuelFighter def, BattleMove move, {bool combo = true}) {
    var dmg = calculateDamage(attacker: atk.pokemon, defender: def.pokemon, move: move, relations: relations).toDouble();
    final eff = _effectiveness(move, def);
    final crit = rng.nextDouble() < DuelTuning.critChance;
    if (crit) dmg *= DuelTuning.critMult;
    if (combo) {
      dmg *= math.min(DuelTuning.comboMaxMult, 1 + DuelTuning.comboBonus * math.max(0, atk.combo));
    }
    final out = eff == 0 ? 0 : math.max(1, dmg.round());
    return (out, crit, eff);
  }

  void _resolveMelee(DuelFighter atk, DuelFighter def, List<DuelEvent> events) {
    final dx = (def.x - atk.x);
    final inFront = dx * atk.facing >= -1;
    if (!def.alive || dx.abs() > DuelTuning.meleeRange || !inFront) return;
    if (def.invulnerable > 0 || def.airborne) return;
    final (dmg, crit, eff) = _damage(atk, def, atk.basic);
    _applyHit(atk, def, dmg, crit, eff, DuelEventType.hit, atk.basic.type, events);
  }

  void _spawnHordeShot(DuelFighter atk, DuelFighter def) {
    final (dmg, crit, eff) = _damage(atk, def, atk.hordeMove);
    projectiles.add(DuelProjectile(
      owner: atk.side,
      type: atk.hordeMove.type,
      shape: DuelSkillShape.fast,
      x: atk.x + atk.facing * 6,
      dir: atk.facing,
      speed: DuelTuning.hordeSpeed,
      radius: DuelTuning.projectileRadius,
      damage: dmg,
      effectiveness: eff,
      crit: crit,
      ignoresAir: false,
    ));
  }

  void _spawnSkill(DuelFighter atk, DuelFighter def, DuelSkill s) {
    final (dmg, crit, eff) = _damage(atk, def, s.move);
    projectiles.add(DuelProjectile(
      owner: atk.side,
      type: s.type,
      shape: s.shape,
      x: atk.x + atk.facing * 6,
      dir: atk.facing,
      speed: s.speed,
      radius: s.radius,
      damage: dmg,
      effectiveness: eff,
      crit: crit,
      ignoresAir: s.ignoresAir,
    ));
  }

  void _resolveUltra(DuelFighter atk, DuelFighter def, List<DuelEvent> events) {
    final dx = def.x - atk.x;
    if (!def.alive || dx * atk.facing < -1 || dx.abs() > DuelTuning.ultraRange) return;
    if (def.invulnerable > 0) return; // solo la esquiva la evita
    final (dmg, crit, eff) = _damage(atk, def, atk.ultraMove);
    _applyHit(atk, def, dmg, crit, eff, DuelEventType.ultraHit, atk.ultraMove.type, events);
  }

  // ------------------------------------------------------------------- apoyos

  void _updateSupports(double dt, int playerSupport, int enemySupport, List<DuelEvent> events) {
    for (final side in DuelSide.values) {
      final slots = supportsOf(side);
      for (final s in slots) {
        s.cooldown = math.max(0, s.cooldown - dt);
      }
      final pressed = side == DuelSide.player ? playerSupport : enemySupport;
      final f = fighter(side);
      if (pressed > 0 && f.alive) {
        final i = pressed - 1;
        if (i < slots.length && slots[i].ready) {
          slots[i].cooldown = DuelTuning.supportCooldown;
          supportActs.add(DuelSupportAct(side, slots[i], _clampX(f.x - f.facing * 12)));
          events.add(DuelEvent(DuelEventType.support, side, x: f.x - f.facing * 12, moveType: slots[i].move.type));
        } else {
          events.add(DuelEvent(DuelEventType.denied, side));
        }
      }
    }
    for (final a in supportActs) {
      a.t += dt;
      if (!a.fired && a.t >= DuelTuning.supportFireAt && !over) {
        a.fired = true;
        final owner = fighter(a.side);
        final foe = fighter(opposite(a.side));
        final dmg = calculateDamage(attacker: a.slot.pokemon, defender: foe.pokemon, move: a.slot.move, relations: relations);
        final eff = _effectiveness(a.slot.move, foe);
        projectiles.add(DuelProjectile(
          owner: a.side,
          type: a.slot.move.type,
          shape: DuelSkillShape.wave,
          x: a.x + owner.facing * 4,
          dir: owner.facing,
          speed: 85,
          radius: 7,
          damage: eff == 0 ? 0 : math.max(1, dmg),
          effectiveness: eff,
          crit: false,
          ignoresAir: false,
          fromSupport: true,
        ));
      }
    }
    supportActs.removeWhere((a) => a.t >= DuelTuning.supportStay);
  }

  // --------------------------------------------------------------- proyectiles

  void _updateProjectiles(double dt, List<DuelEvent> events) {
    for (final p in projectiles) {
      if (!p.alive) continue;
      p.x += p.dir * p.speed * dt;
      final owner = fighter(p.owner);
      final target = fighter(opposite(p.owner));
      if (p.x < -5 || p.x > DuelTuning.arenaW + 5 || !target.alive) {
        p.alive = false;
        continue;
      }
      if ((p.x - target.x).abs() <= p.radius + 4) {
        // Esquiva, deslizamiento o salto: el proyectil pasa de largo.
        if (target.invulnerable > 0) continue;
        if (target.sliding && p.shape != DuelSkillShape.bomb) continue;
        if (target.airborne && !p.ignoresAir) continue;
        p.alive = false;
        _applyHit(owner, target, p.damage, p.crit, p.effectiveness, DuelEventType.skillHit, p.type, events, countsForCombo: !p.fromSupport);
        if (over) break;
      }
    }
    projectiles.removeWhere((p) => !p.alive);
  }

  void _applyHit(
    DuelFighter atk,
    DuelFighter def,
    int dmgIn,
    bool crit,
    double eff,
    DuelEventType type,
    String moveType,
    List<DuelEvent> events, {
    bool countsForCombo = true,
  }) {
    var dmg = dmgIn;
    final blocked = def.guarding && dmg > 0;
    if (blocked) {
      dmg = math.max(1, (dmg * (1 - DuelTuning.guardReduction)).round());
      def.stamina = math.max(0, def.stamina - DuelTuning.guardHitDrain);
      if (def.stamina <= 0) {
        def._guardBroken = true;
        def.guarding = false;
      }
    }
    def.hp = math.max(0, def.hp - dmg);
    final share = def.maxHp <= 0 ? 0.0 : dmg / def.maxHp * 100;
    final gain = blocked ? 0.5 : 1.0;
    atk.ultra = math.min(DuelTuning.ultraMax, atk.ultra + share * DuelTuning.ultraGainDealt * gain);
    def.ultra = math.min(DuelTuning.ultraMax, def.ultra + share * DuelTuning.ultraGainTaken * gain);

    if (blocked) {
      def.x = _clampX(def.x + (def.x - atk.x).sign * 1.5);
      events.add(DuelEvent(DuelEventType.blocked, atk.side, x: def.x, y: def.y, damage: dmg, effectiveness: eff, moveType: moveType));
    } else {
      def.combo = 0; // recibir un golpe rompe su combo
      def._pendingMelee = false;
      def._pendingSkill = -1;
      def._horde = false;
      def._pendingUltra = false;
      final knock = (def.x - atk.x).sign;
      def.x = _clampX(def.x + (knock == 0 ? atk.facing : knock) * DuelTuning.knockback);
      if (countsForCombo) {
        atk.combo += 1;
        atk.comboT = DuelTuning.comboWindow;
      }
      events.add(DuelEvent(type, atk.side, x: def.x, y: def.y, damage: dmg, effectiveness: eff, crit: crit, combo: atk.combo, moveType: moveType));
      if (countsForCombo && atk.combo >= 2) {
        events.add(DuelEvent(DuelEventType.combo, atk.side, x: atk.x, combo: atk.combo));
      }
    }
    if (def.hp <= 0) {
      def._enter(DuelState.ko);
      def.y = 0;
      def.vy = 0;
      def.guarding = false;
      over = true;
      ko = true;
      winnerSide = atk.side;
      events.add(DuelEvent(DuelEventType.ko, def.side, x: def.x));
    } else if (!blocked && (eff != 0 || dmg > 0)) {
      def._enter(DuelState.hurt);
    }
  }

  void _finishByTime(List<DuelEvent> events) {
    over = true;
    final p = player.hp / player.maxHp;
    final e = enemy.hp / enemy.maxHp;
    if ((p - e).abs() < 0.005) {
      draw = true;
    } else {
      winnerSide = p > e ? DuelSide.player : DuelSide.enemy;
    }
    events.add(const DuelEvent(DuelEventType.timeUp, DuelSide.player));
  }
}

/// Combate completo: mejor de 3 rondas (con desempates hasta 5). Cada ronda es
/// un [DuelEngine] nuevo con PS, stamina, ULTRA y apoyos reiniciados.
class DuelMatch {
  final PokemonDetail playerMon;
  final PokemonDetail enemyMon;
  final Map<String, TypeRelations> relations;
  final math.Random? rng;
  final List<PokemonDetail> playerSupports;
  final List<PokemonDetail> enemySupports;
  final double roundDuration;

  int round = 1;
  int playerWins = 0;
  int enemyWins = 0;
  bool _counted = false;
  late DuelEngine engine;

  DuelMatch({
    required this.playerMon,
    required this.enemyMon,
    this.relations = const {},
    this.rng,
    this.playerSupports = const [],
    this.enemySupports = const [],
    this.roundDuration = DuelTuning.duration,
  }) {
    engine = _newEngine();
  }

  DuelEngine _newEngine() => DuelEngine(
        player: playerMon,
        enemy: enemyMon,
        relations: relations,
        rng: rng,
        duration: roundDuration,
        playerSupports: playerSupports,
        enemySupports: enemySupports,
      );

  /// Anota el resultado de la ronda cuando acaba (una sola vez).
  void settleRound() {
    if (!engine.over || _counted) return;
    _counted = true;
    if (engine.winnerSide == DuelSide.player) playerWins++;
    if (engine.winnerSide == DuelSide.enemy) enemyWins++;
  }

  bool get roundOver => engine.over;

  /// Fin del combate: alguien llegó a 2 rondas, o se jugaron las 3 y hay un
  /// líder; con empate se juega una ronda de desempate (hasta 5).
  bool get over {
    if (!_counted) return false;
    if (playerWins >= DuelTuning.roundsToWin || enemyWins >= DuelTuning.roundsToWin) return true;
    if (round >= 3 && playerWins != enemyWins) return true;
    return round >= DuelTuning.maxRounds;
  }

  /// Ganador del combate (null = empate o aún en juego).
  DuelSide? get winner {
    if (!over) return null;
    if (playerWins == enemyWins) return null;
    return playerWins > enemyWins ? DuelSide.player : DuelSide.enemy;
  }

  /// Empieza la siguiente ronda (si el combate sigue).
  void nextRound() {
    if (over || !_counted) return;
    round++;
    _counted = false;
    engine = _newEngine();
  }
}
