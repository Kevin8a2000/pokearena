import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/models/type_relations.dart';
import 'package:pokearena/features/duel/duel_engine.dart';

PokemonDetail _mon(List<String> types, {int hp = 50, int atk = 50, int def = 50}) => PokemonDetail(
      id: 1,
      name: 'test',
      height: 10,
      weight: 100,
      types: types,
      stats: {'hp': hp, 'attack': atk, 'defense': def, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

/// Random que nunca da crítico (siempre ≈ 1).
class _NoCrit implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
}

DuelEngine _engine({
  List<String> p = const ['normal'],
  List<String> e = const ['normal'],
  Map<String, TypeRelations> relations = const {},
  double duration = DuelTuning.duration,
  List<PokemonDetail> supports = const [],
}) =>
    DuelEngine(player: _mon(p), enemy: _mon(e), relations: relations, duration: duration, rng: _NoCrit(), playerSupports: supports);

/// Avanza [seconds] en pasos de 10 ms; [first] solo vale en el primer tick.
List<DuelEvent> _run(
  DuelEngine en,
  double seconds, {
  DuelInput first = DuelInput.none,
  DuelInput enemyFirst = DuelInput.none,
  DuelInput hold = DuelInput.none,
  DuelInput enemyHold = DuelInput.none,
}) {
  final events = <DuelEvent>[];
  final ticks = (seconds / 0.01).round();
  for (var i = 0; i < ticks; i++) {
    events.addAll(en.step(0.01, i == 0 ? first : hold, i == 0 ? enemyFirst : enemyHold));
  }
  return events;
}

const _attack = DuelInput(attack: true);
const _fast = DuelInput(skill: 1);
const _wave = DuelInput(skill: 2);
const _bomb = DuelInput(skill: 3);
const _ultra = DuelInput(ultra: true);
const _dodge = DuelInput(dodge: true);
const _jump = DuelInput(jump: true);
const _slide = DuelInput(slide: true);
const _guardHold = DuelInput(guard: true);

void _place(DuelEngine en, double px, double ex) {
  en.player.x = px;
  en.enemy.x = ex;
}

void main() {
  group('movimiento', () {
    test('caminar mueve y respeta los límites de la arena', () {
      final en = _engine();
      final x0 = en.player.x;
      _run(en, 0.5, hold: const DuelInput(move: 1));
      expect(en.player.x, greaterThan(x0));
      _run(en, 5, hold: const DuelInput(move: -1));
      expect(en.player.x, DuelTuning.minX);
      _run(en, 10, hold: const DuelInput(move: 1));
      expect(en.player.x, DuelTuning.maxX);
    });

    test('los luchadores siempre se miran', () {
      final en = _engine();
      _run(en, 0.05);
      expect(en.player.facing, 1);
      expect(en.enemy.facing, -1);
      en.player.x = 90; // pasa por detrás del rival
      en.enemy.x = 40;
      _run(en, 0.05);
      expect(en.player.facing, -1);
      expect(en.enemy.facing, 1);
    });

    test('correr va más rápido pero gasta stamina; sin correr se regenera', () {
      final walk = _engine();
      final run = _engine();
      _run(walk, 0.5, hold: const DuelInput(move: 1));
      _run(run, 0.5, hold: const DuelInput(move: 1, run: true));
      expect(run.player.x - 25, closeTo((walk.player.x - 25) * DuelTuning.runMult, 0.5));
      expect(run.player.running, isTrue);
      expect(run.player.stamina, lessThan(DuelTuning.staminaMax - 3));
      expect(walk.player.stamina, DuelTuning.staminaMax);
    });

    test('correr se corta al quedarse sin stamina', () {
      final en = _engine();
      en.player.stamina = 0;
      _run(en, 0.2, hold: const DuelInput(move: 1, run: true));
      expect(en.player.running, isFalse);
    });
  });

  group('ataque básico', () {
    test('golpea en alcance tras el tiempo de preparación', () {
      final en = _engine();
      _place(en, 50, 60);
      final ev = _run(en, 0.3, first: _attack);
      expect(en.enemy.hp, lessThan(en.enemy.maxHp));
      expect(ev.where((e) => e.type == DuelEventType.hit).length, 1);
      expect(ev.firstWhere((e) => e.type == DuelEventType.hit).side, DuelSide.player);
    });

    test('no golpea fuera de alcance', () {
      final en = _engine();
      _place(en, 20, 80);
      _run(en, 0.5, first: _attack);
      expect(en.enemy.hp, en.enemy.maxHp);
    });

    test('el enfriamiento impide encadenar golpes instantáneos', () {
      final en = _engine();
      _place(en, 50, 58);
      _run(en, 0.2, first: _attack);
      final afterFirst = en.enemy.hp;
      _run(en, 0.1, first: _attack);
      expect(en.enemy.hp, afterFirst);
      _run(en, 0.4);
      _place(en, 50, 58);
      _run(en, 0.3, first: _attack);
      expect(en.enemy.hp, lessThan(afterFirst));
    });

    test('el golpe empuja al rival y lo aturde', () {
      final en = _engine();
      _place(en, 50, 58);
      _run(en, 0.15, first: _attack);
      expect(en.enemy.x, greaterThan(58));
      expect(en.enemy.state, DuelState.hurt);
    });
  });

  group('poderes', () {
    test('cada luchador tiene 3 poderes con nombre por tipo y formas distintas', () {
      final skills = _engine(p: const ['grass']).player.skills;
      expect(skills.map((s) => s.name), ['Látigo Cepa', 'Hoja Afilada', 'Bomba Germen']);
      expect(skills.map((s) => s.shape), [DuelSkillShape.fast, DuelSkillShape.wave, DuelSkillShape.bomb]);
      expect(skills[0].cost, lessThan(skills[1].cost));
      expect(skills[1].cost, lessThan(skills[2].cost));
      expect(skills[2].move.power, greaterThan(skills[0].move.power));
    });

    test('un Pokémon de dos tipos usa el segundo en el poder de onda', () {
      final skills = _engine(p: const ['fire', 'flying']).player.skills;
      expect(skills[0].type, 'fire');
      expect(skills[1].type, 'flying');
      expect(skills[2].type, 'fire');
    });

    test('todos los tipos tienen nombres', () {
      for (final t in ['normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy']) {
        expect(duelSkillNames[t], hasLength(3), reason: t);
      }
    });

    test('cuestan stamina, viajan y golpean', () {
      for (final input in [_fast, _wave, _bomb]) {
        final en = _engine(p: const ['fire']);
        _place(en, 20, 70);
        final i = input.skill - 1;
        final cost = en.player.skills[i].cost;
        _run(en, 0.35, first: input);
        expect(en.player.stamina, lessThan(DuelTuning.staminaMax - cost + DuelTuning.staminaRegen * 0.35 + 0.5), reason: 'poder ${input.skill}');
        final ev = _run(en, 2.5);
        expect(ev.any((e) => e.type == DuelEventType.skillHit), isTrue, reason: 'poder ${input.skill}');
        expect(en.enemy.hp, lessThan(en.enemy.maxHp));
      }
    });

    test('sin stamina suficiente se deniega y no sale nada', () {
      final en = _engine();
      en.player.stamina = 10;
      final ev = _run(en, 0.4, first: _wave);
      expect(ev.any((e) => e.type == DuelEventType.denied), isTrue);
      expect(en.projectiles, isEmpty);
      expect(en.player.state, isNot(DuelState.skill));
    });

    test('cada poder tiene su propio enfriamiento', () {
      final en = _engine();
      _place(en, 20, 90);
      _run(en, 0.5, first: _fast);
      expect(en.player.skillCd[0], greaterThan(0));
      expect(en.player.skillCd[1], 0);
      final ev = _run(en, 0.45, first: _wave);
      expect(ev.any((e) => e.type == DuelEventType.denied), isFalse, reason: 'el segundo poder está listo');
    });

    test('saltar o esquivar evita el poder de onda', () {
      final a = _engine(p: const ['fire']);
      _place(a, 20, 60);
      _run(a, 0.2, first: _wave);
      _run(a, 0.3);
      _run(a, 0.4, enemyFirst: _dodge);
      expect(a.enemy.hp, a.enemy.maxHp);

      final b = _engine(p: const ['fire']);
      _place(b, 20, 50);
      _run(b, 0.2, first: _wave);
      _run(b, 0.2, enemyFirst: _jump);
      _run(b, 0.6);
      expect(b.enemy.hp, b.enemy.maxHp, reason: 'el proyectil pasa por debajo');
    });

    test('la bomba explota aunque el rival esté en el aire', () {
      final en = _engine(p: const ['fire']);
      _place(en, 20, 50);
      en.enemy.y = 30; // en el aire
      en.enemy.vy = 0;
      en.enemy.stamina = 0;
      _run(en, 0.35, first: _bomb);
      en.enemy.y = 12;
      _run(en, 1.5);
      expect(en.enemy.hp, lessThan(en.enemy.maxHp));
    });

    test('un proyectil que no acierta desaparece al salir de la arena', () {
      final en = _engine(p: const ['fire']);
      _place(en, 20, 20.5);
      en.enemy.x = 10;
      _run(en, 0.25, first: _wave);
      en.enemy.x = 10;
      en.enemy.y = 20;
      _run(en, 3);
      expect(en.projectiles, isEmpty);
    });
  });

  group('horda de poderes', () {
    const horde = DuelInput(horde: true);

    test('lanza varios disparos seguidos del tipo del luchador', () {
      final en = _engine(p: const ['fire']);
      _place(en, 10, 95);
      _run(en, DuelTuning.hordeWindup + 0.02, first: horde);
      expect(en.projectiles, hasLength(1), reason: 'sale el primero tras la preparación');
      _run(en, DuelTuning.hordeInterval * 2);
      expect(en.projectiles.length, greaterThanOrEqualTo(3));
      expect(en.projectiles.every((p) => p.type == 'fire' && p.owner == DuelSide.player), isTrue);
      var shots = en.projectiles.length;
      for (var i = 0; i < 40; i++) {
        _run(en, 0.05);
        shots = math.max(shots, en.projectiles.length);
      }
      expect(shots, lessThanOrEqualTo(DuelTuning.hordeShots));
      _run(en, 3);
      expect(en.projectiles, isEmpty);
    });

    test('cada disparo del enemigo parado acierta: la horda quita más que un poder suelto', () {
      final h = _engine(p: const ['fire']);
      _place(h, 20, 60);
      _run(h, 3, first: horde);
      final hordeLost = h.enemy.maxHp - h.enemy.hp;

      final s = _engine(p: const ['fire']);
      _place(s, 20, 60);
      _run(s, 3, first: _fast);
      final single = s.enemy.maxHp - s.enemy.hp;
      expect(hordeLost, greaterThan(single * 2));
    });

    test('cuesta stamina, tiene enfriamiento y se deniega sin stamina', () {
      final en = _engine();
      _place(en, 10, 95);
      final s0 = en.player.stamina;
      _run(en, 0.1, first: horde);
      expect(en.player.stamina, lessThan(s0 - 20));
      expect(en.player.hordeCd, greaterThan(0));

      final again = _run(en, 0.6, first: horde);
      expect(again.any((e) => e.type == DuelEventType.denied), isTrue, reason: 'aún en enfriamiento');

      final low = _engine();
      low.player.stamina = 10;
      final ev = _run(low, 0.3, first: horde);
      expect(ev.any((e) => e.type == DuelEventType.denied), isTrue);
      expect(low.projectiles, isEmpty);
    });

    test('esquivar justo a tiempo evita parte de la horda, y el escudo la reduce', () {
      final dodge = _engine(p: const ['fire']);
      _place(dodge, 20, 55);
      _run(dodge, 0.35, first: horde);
      _run(dodge, 0.3, enemyFirst: _dodge);
      _run(dodge, 3);
      final dodged = dodge.enemy.maxHp - dodge.enemy.hp;

      final open = _engine(p: const ['fire']);
      _place(open, 20, 55);
      _run(open, 3.6, first: horde);
      final full = open.enemy.maxHp - open.enemy.hp;
      expect(dodged, lessThan(full));

      final guarded = _engine(p: const ['fire']);
      _place(guarded, 20, 55);
      guarded.enemy.stamina = 100;
      _run(guarded, 3.6, first: horde, enemyHold: _guardHold);
      final blocked = guarded.enemy.maxHp - guarded.enemy.hp;
      expect(blocked, lessThan(full * 0.6));
    });

    test('recibir un golpe corta la horda', () {
      final en = _engine(p: const ['fire']);
      _place(en, 50, 58);
      _run(en, DuelTuning.hordeWindup + 0.01, first: horde);
      _run(en, 0.3, enemyFirst: _attack);
      _run(en, 2);
      expect(en.projectiles, isEmpty);
      expect(en.player.state, isNot(DuelState.skill));
    });
  });

  group('esquivar, deslizar y saltar', () {
    test('esquivar da invulnerabilidad al golpe y gasta stamina', () {
      final en = _engine();
      _place(en, 50, 58);
      final s0 = en.player.stamina;
      _run(en, 0.3, first: _dodge, enemyFirst: _attack);
      expect(en.player.hp, en.player.maxHp);
      expect(en.player.stamina, lessThan(s0));
    });

    test('esquivar tiene enfriamiento', () {
      final en = _engine();
      _run(en, 0.05, first: _dodge);
      _run(en, 0.5);
      final ev = _run(en, 0.05, first: _dodge);
      expect(ev.any((e) => e.type == DuelEventType.dodge), isFalse);
    });

    test('deslizar pasa bajo los proyectiles pero no evita el cuerpo a cuerpo', () {
      final a = _engine(p: const ['fire']);
      _place(a, 20, 60);
      _run(a, 0.2, first: _fast);
      // El rival se desliza sin salir de la trayectoria del proyectil.
      a.enemy.dodgeDir = 0;
      _run(a, 0.1, enemyFirst: const DuelInput(slide: true, move: 0.001));
      expect(a.enemy.state, DuelState.slide);

      final b = _engine();
      _place(b, 50, 58);
      _run(b, 0.3, first: _slide, enemyFirst: _attack);
      expect(b.player.hp, lessThan(b.player.maxHp), reason: 'el golpe cuerpo a cuerpo sí pega');
    });

    test('deslizar gasta stamina y tiene enfriamiento', () {
      final en = _engine();
      final ev = _run(en, 0.05, first: _slide);
      expect(ev.any((e) => e.type == DuelEventType.slide), isTrue);
      expect(en.player.stamina, lessThan(DuelTuning.staminaMax));
      _run(en, 0.4);
      final again = _run(en, 0.05, first: _slide);
      expect(again.any((e) => e.type == DuelEventType.slide), isFalse);
    });

    test('saltar evita el golpe cuerpo a cuerpo', () {
      final en = _engine();
      _place(en, 50, 58);
      _run(en, 0.3, first: _jump, enemyFirst: _attack);
      expect(en.player.hp, en.player.maxHp);
    });

    test('el salto sube, cae al suelo y no se encadena en el aire', () {
      final en = _engine();
      final ev = _run(en, 0.1, first: _jump);
      expect(en.player.y, greaterThan(0));
      expect(ev.any((e) => e.type == DuelEventType.jump), isTrue);
      final again = _run(en, 0.05, first: _jump);
      expect(again.any((e) => e.type == DuelEventType.jump), isFalse, reason: 'sin doble salto');
      _run(en, 1.2);
      expect(en.player.y, 0);
    });
  });

  group('bloqueo', () {
    test('reduce el daño un 75 % y gasta stamina', () {
      final open = _engine();
      _place(open, 50, 58);
      _run(open, 0.3, enemyFirst: _attack);
      final lost = open.player.maxHp - open.player.hp;

      final guarded = _engine();
      _place(guarded, 50, 58);
      _run(guarded, 0.05, hold: _guardHold); // levanta la guardia
      final s0 = guarded.player.stamina;
      final ev = _run(guarded, 0.3, enemyFirst: _attack, hold: _guardHold);
      final lostG = guarded.player.maxHp - guarded.player.hp;
      expect(lostG, closeTo(lost * (1 - DuelTuning.guardReduction), 2));
      expect(ev.any((e) => e.type == DuelEventType.blocked), isTrue);
      expect(guarded.player.stamina, lessThan(s0));
      expect(guarded.player.state, isNot(DuelState.hurt), reason: 'bloquear no aturde');
    });

    test('mientras bloqueas no te mueves ni atacas', () {
      final en = _engine();
      _place(en, 50, 58);
      _run(en, 0.05, hold: _guardHold);
      expect(en.player.guarding, isTrue);
      final x0 = en.player.x;
      _run(en, 0.3, hold: const DuelInput(guard: true, move: 1));
      expect(en.player.x, x0);
      _run(en, 0.3, first: const DuelInput(guard: true, attack: true), hold: _guardHold);
      expect(en.enemy.hp, en.enemy.maxHp);
    });

    test('un golpe bloqueado no suma combo al atacante', () {
      final en = _engine();
      _place(en, 50, 58);
      _run(en, 0.05, hold: _guardHold);
      _run(en, 0.3, enemyFirst: _attack, hold: _guardHold);
      expect(en.enemy.combo, 0);
    });

    test('la guardia se rompe al quedarse sin stamina y tarda en volver', () {
      final en = _engine();
      en.player.stamina = 1;
      _run(en, 0.3, hold: _guardHold);
      expect(en.player.guarding, isFalse);
      _run(en, 0.1, hold: _guardHold);
      expect(en.player.guarding, isFalse, reason: 'aún sin stamina suficiente');
      _run(en, 1.2); // regenera
      _run(en, 0.05, hold: _guardHold);
      expect(en.player.guarding, isTrue);
    });
  });

  group('ULTRA / FRENESÍ', () {
    test('se carga al dar y al recibir daño', () {
      final en = _engine();
      _place(en, 50, 56);
      _run(en, 0.3, first: _attack);
      expect(en.player.ultra, greaterThan(0), reason: 'cargó al dar');
      expect(en.enemy.ultra, greaterThan(0), reason: 'cargó al recibir');
      expect(en.player.ultra, greaterThan(en.enemy.ultra));
    });

    test('sin la barra llena se deniega', () {
      final en = _engine();
      final ev = _run(en, 0.3, first: _ultra);
      expect(ev.any((e) => e.type == DuelEventType.denied), isTrue);
      expect(en.player.state, isNot(DuelState.ultra));
    });

    test('con la barra llena pega fuerte y la vacía', () {
      final en = _engine();
      _place(en, 50, 70);
      en.player.ultra = DuelTuning.ultraMax;
      final ev = _run(en, 1.2, first: _ultra);
      expect(ev.any((e) => e.type == DuelEventType.ultra), isTrue);
      final hit = ev.firstWhere((e) => e.type == DuelEventType.ultraHit);
      final basic = _engine();
      _place(basic, 50, 58);
      final b = _run(basic, 0.3, first: _attack).firstWhere((e) => e.type == DuelEventType.hit);
      expect(hit.damage, greaterThan(b.damage * 2));
      expect(en.player.ultra, lessThan(DuelTuning.ultraMax), reason: "se vació; solo queda lo cargado por el propio golpe");
    });

    test('solo la esquiva la evita (saltar no basta)', () {
      final dodge = _engine();
      _place(dodge, 50, 70);
      dodge.player.ultra = DuelTuning.ultraMax;
      _run(dodge, 0.4, first: _ultra);
      _run(dodge, 0.2, enemyFirst: _dodge);
      expect(dodge.enemy.hp, dodge.enemy.maxHp);

      final jump = _engine();
      _place(jump, 50, 70);
      jump.player.ultra = DuelTuning.ultraMax;
      _run(jump, 0.3, first: _ultra);
      _run(jump, 1, enemyFirst: _jump);
      expect(jump.enemy.hp, lessThan(jump.enemy.maxHp));
    });

    test('el rival también la carga (FRENESÍ) y la usa', () {
      final en = _engine();
      _place(en, 30, 60);
      en.enemy.ultra = DuelTuning.ultraMax;
      final ev = _run(en, 1.2, enemyFirst: _ultra);
      expect(ev.any((e) => e.type == DuelEventType.ultraHit && e.side == DuelSide.enemy), isTrue);
    });
  });

  group('apoyo', () {
    final ally = _mon(const ['water']);

    test('el compañero entra, lanza su poder y desaparece', () {
      final en = _engine(supports: [ally]);
      _place(en, 20, 70);
      final ev = _run(en, 0.05, first: const DuelInput(support: 1));
      expect(ev.any((e) => e.type == DuelEventType.support), isTrue);
      expect(en.supportActs, hasLength(1));
      _run(en, 0.4);
      expect(en.projectiles.where((p) => p.fromSupport), hasLength(1));
      _run(en, 1.5);
      expect(en.enemy.hp, lessThan(en.enemy.maxHp));
      expect(en.supportActs, isEmpty);
    });

    test('tiene enfriamiento largo y no sube el combo', () {
      final en = _engine(supports: [ally]);
      _place(en, 20, 60);
      _run(en, 0.05, first: const DuelInput(support: 1));
      expect(en.playerSupports.first.cooldown, closeTo(DuelTuning.supportCooldown, 0.1));
      _run(en, 1.8);
      expect(en.player.combo, 0, reason: 'el apoyo no cuenta para el combo');
      final ev = _run(en, 0.05, first: const DuelInput(support: 1));
      expect(ev.any((e) => e.type == DuelEventType.denied), isTrue);
      expect(en.supportActs, isEmpty);
    });

    test('sin compañero en esa ranura no pasa nada', () {
      final en = _engine();
      final ev = _run(en, 0.1, first: const DuelInput(support: 2));
      expect(ev.any((e) => e.type == DuelEventType.support), isFalse);
      expect(en.supportActs, isEmpty);
    });

    test('solo se aceptan 2 compañeros', () {
      final en = _engine(supports: [ally, ally, ally]);
      expect(en.playerSupports, hasLength(2));
    });
  });

  group('stamina', () {
    test('se regenera con el tiempo hasta el máximo', () {
      final en = _engine();
      en.player.stamina = 20;
      _run(en, 1);
      expect(en.player.stamina, closeTo(20 + DuelTuning.staminaRegen, 1));
      _run(en, 10);
      expect(en.player.stamina, DuelTuning.staminaMax);
    });
  });

  group('daño', () {
    test('la efectividad de tipo multiplica el daño del poder', () {
      int skillDamage(Map<String, TypeRelations> rel) {
        final en = _engine(p: const ['fire'], e: const ['grass'], relations: rel);
        _place(en, 20, 60);
        final ev = _run(en, 2, first: _wave);
        return ev.firstWhere((e) => e.type == DuelEventType.skillHit).damage;
      }

      final neutral = skillDamage(const {});
      final strong = skillDamage(const {'grass': TypeRelations(typeName: 'grass', doubleDamageFrom: ['fire'])});
      final immune = skillDamage(const {'grass': TypeRelations(typeName: 'grass', noDamageFrom: ['fire'])});
      expect(strong, closeTo(neutral * 2, 2));
      expect(immune, 0);
    });

    test('los PS salen de la stat base', () {
      final en = DuelEngine(player: _mon(const ['normal'], hp: 100), enemy: _mon(const ['normal'], hp: 40), rng: _NoCrit());
      expect(en.player.maxHp, (100 * DuelTuning.hpFactor).round());
      expect(en.enemy.maxHp, (40 * DuelTuning.hpFactor).round());
    });
  });

  group('combo', () {
    test('golpes seguidos suben el combo y suman daño; recibir un golpe lo rompe', () {
      final en = _engine();
      final damages = <int>[];
      var lastCombo = 0;
      for (var i = 0; i < 3; i++) {
        _place(en, 50, 56);
        final ev = _run(en, 0.55, first: _attack);
        final hit = ev.firstWhere((e) => e.type == DuelEventType.hit);
        damages.add(hit.damage);
        lastCombo = hit.combo;
      }
      expect(lastCombo, 3);
      expect(damages[2], greaterThan(damages[0]));
      expect(en.player.combo, 3);

      _place(en, 50, 56);
      _run(en, 0.3, enemyFirst: _attack);
      expect(en.player.combo, 0);
    });

    test('el combo caduca si pasa mucho tiempo sin golpear', () {
      final en = _engine();
      _place(en, 50, 56);
      _run(en, 0.3, first: _attack);
      expect(en.player.combo, 1);
      _run(en, DuelTuning.comboWindow + 0.2);
      expect(en.player.combo, 0);
    });

    test('el evento de combo aparece desde el segundo golpe', () {
      final en = _engine();
      final ev = <DuelEvent>[];
      for (var i = 0; i < 2; i++) {
        _place(en, 50, 56);
        ev.addAll(_run(en, 0.55, first: _attack));
      }
      expect(ev.where((e) => e.type == DuelEventType.combo).map((e) => e.combo), [2]);
    });
  });

  group('fin de la ronda', () {
    test('KO: el que se queda sin PS pierde y el otro gana', () {
      final en = _engine();
      _place(en, 50, 56);
      en.enemy.hp = 1;
      final ev = _run(en, 0.3, first: _attack);
      expect(ev.any((e) => e.type == DuelEventType.ko && e.side == DuelSide.enemy), isTrue);
      expect(en.over, isTrue);
      expect(en.ko, isTrue);
      expect(en.winnerSide, DuelSide.player);
      expect(en.enemy.state, DuelState.ko);
      expect(_run(en, 1, first: _attack), isEmpty);
    });

    test('al acabarse el tiempo gana quien tenga más PS', () {
      final en = _engine(duration: 1);
      en.enemy.hp = en.enemy.maxHp * 0.5;
      final ev = _run(en, 1.2);
      expect(en.over, isTrue);
      expect(en.ko, isFalse);
      expect(en.winnerSide, DuelSide.player);
      expect(ev.any((e) => e.type == DuelEventType.timeUp), isTrue);
    });

    test('con los mismos PS es empate', () {
      final en = _engine(duration: 0.5);
      _run(en, 0.7);
      expect(en.over, isTrue);
      expect(en.draw, isTrue);
      expect(en.winnerSide, isNull);
    });

    test('el reloj cuenta hacia atrás', () {
      final en = _engine();
      _run(en, 2);
      expect(en.timeLeft, closeTo(DuelTuning.duration - 2, 0.05));
    });
  });

  group('combate a rondas', () {
    DuelMatch match() => DuelMatch(playerMon: _mon(const ['normal']), enemyMon: _mon(const ['normal']), rng: _NoCrit());

    /// Juega una ronda: [playerWins] decide quién gana.
    void playRound(DuelMatch m, {required bool playerWins}) {
      final en = m.engine;
      if (playerWins) {
        en.enemy.hp = 1;
        _place(en, 50, 56);
        _run(en, 0.3, first: _attack);
      } else {
        en.player.hp = 1;
        _place(en, 56, 50);
        _run(en, 0.3, enemyFirst: _attack);
      }
      m.settleRound();
    }

    test('empieza en la ronda 1 sin coronas', () {
      final m = match();
      expect(m.round, 1);
      expect(m.playerWins, 0);
      expect(m.enemyWins, 0);
      expect(m.over, isFalse);
    });

    test('gana el combate quien llega a 2 rondas', () {
      final m = match();
      playRound(m, playerWins: true);
      expect(m.playerWins, 1);
      expect(m.over, isFalse);
      m.nextRound();
      expect(m.round, 2);
      playRound(m, playerWins: true);
      expect(m.over, isTrue);
      expect(m.winner, DuelSide.player);
    });

    test('cada ronda reinicia PS, stamina y ULTRA', () {
      final m = match();
      m.engine.player.ultra = 80;
      m.engine.player.stamina = 5;
      playRound(m, playerWins: false);
      m.nextRound();
      expect(m.engine.player.hp, m.engine.player.maxHp);
      expect(m.engine.player.stamina, DuelTuning.staminaMax);
      expect(m.engine.player.ultra, 0);
      expect(m.engine.over, isFalse);
    });

    test('1-1 lleva a la tercera ronda decisiva', () {
      final m = match();
      playRound(m, playerWins: true);
      m.nextRound();
      playRound(m, playerWins: false);
      expect(m.over, isFalse);
      m.nextRound();
      expect(m.round, 3);
      playRound(m, playerWins: false);
      expect(m.over, isTrue);
      expect(m.winner, DuelSide.enemy);
    });

    test('settleRound solo cuenta una vez y no avanza si la ronda sigue', () {
      final m = match();
      m.settleRound();
      expect(m.playerWins + m.enemyWins, 0);
      playRound(m, playerWins: true);
      m.settleRound();
      m.settleRound();
      expect(m.playerWins, 1);
      m.nextRound();
      m.nextRound(); // la ronda 2 no ha terminado: no salta a la 3
      expect(m.round, 2);
    });

    test('un empate de ronda no da corona y obliga a seguir', () {
      final m = DuelMatch(playerMon: _mon(const ['normal']), enemyMon: _mon(const ['normal']), rng: _NoCrit(), roundDuration: 0.3);
      _run(m.engine, 0.5); // se acaba el tiempo con los mismos PS
      m.settleRound();
      expect(m.engine.draw, isTrue);
      expect(m.playerWins + m.enemyWins, 0);
      expect(m.over, isFalse);
      m.nextRound();
      expect(m.round, 2);
    });

    test('tras 3 rondas igualadas se desempata hasta la 5ª y luego es empate', () {
      final m = DuelMatch(playerMon: _mon(const ['normal']), enemyMon: _mon(const ['normal']), rng: _NoCrit(), roundDuration: 0.3);
      for (var i = 0; i < DuelTuning.maxRounds; i++) {
        _run(m.engine, 0.5);
        m.settleRound();
        if (m.over) break;
        m.nextRound();
      }
      expect(m.over, isTrue);
      expect(m.winner, isNull);
      expect(m.round, DuelTuning.maxRounds);
    });
  });
}
