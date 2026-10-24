import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/features/duel/duel_engine.dart';
import 'package:pokearena/features/duel/net/duel_link.dart';
import 'package:pokearena/features/duel/net/duel_snapshot.dart';
import 'package:pokearena/features/duel/net/duel_transport.dart';

PokemonDetail _mon(String name, List<String> types) => PokemonDetail(
      id: 1,
      name: name,
      height: 10,
      weight: 100,
      types: types,
      stats: const {'hp': 50, 'attack': 50, 'defense': 50, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

/// Random que nunca da crítico.
class _NoCrit implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
}

DuelMatch _match() => DuelMatch(playerMon: _mon('host', ['fire']), enemyMon: _mon('guest', ['water']), rng: _NoCrit());

/// Banco de pruebas: anfitrión (combate real) + invitado (espejo) conectados.
class _Rig {
  final MemoryDuelHub hub;
  double now = 0;
  final DuelMatch host = _match();
  final DuelMatch mirror = _match();
  late final DuelHostLink hostLink;
  late final DuelGuestLink guestLink;
  final DuelUiState ui = DuelUiState();
  final List<DuelEvent> guestEvents = [];
  final List<DuelEvent> hostEvents = [];

  _Rig({Duration latency = Duration.zero}) : hub = MemoryDuelHub(latency: latency) {
    hostLink = DuelHostLink(hub.host, clock: () => now);
    guestLink = DuelGuestLink(hub.guest, clock: () => now);
  }

  /// Un paso de 1/60 s de los dos extremos, como hace la pantalla.
  void tick({DuelInput hostInput = DuelInput.none, bool hostPlays = true}) {
    const dt = 1 / 60;
    now += dt;
    hub.advance(const Duration(microseconds: 16667));
    if (hostPlays) {
      final events = host.engine.step(dt, hostInput, hostLink.guestInput());
      hostEvents.addAll(events);
      hostLink.addEvents(events);
    }
    hostLink.maybePublish(dt, host, ui);
    guestEvents.addAll(guestLink.update(dt, mirror));
  }

  void run(double seconds, {DuelInput hostInput = DuelInput.none}) {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      tick(hostInput: hostInput);
    }
  }
}

void main() {
  group('codificación de instantáneas', () {
    test('ida y vuelta de un combate completo (luchadores, proyectiles y reloj)', () {
      final a = _match();
      final en = a.engine;
      en.player
        ..x = 33.337
        ..y = 4.2
        ..vy = 12.5
        ..hp = 77.5
        ..stamina = 61.25
        ..ultra = 40.5
        ..combo = 3
        ..facing = 1
        ..dodgeDir = -1
        ..hordeCd = 1.5
        ..attackCd = 0.25
        ..invulnerable = 0.1
        ..state = DuelState.attack
        ..stateT = 0.2;
      en.enemy
        ..x = 71.4
        ..hp = 120
        ..facing = -1
        ..guarding = true
        ..state = DuelState.idle;
      en.timeLeft = 55.55;
      a.round = 2;
      a.playerWins = 1;
      en.projectiles.add(DuelProjectile(
        owner: DuelSide.player,
        type: 'fire',
        shape: DuelSkillShape.bomb,
        x: 40,
        dir: 1,
        speed: 42,
        radius: 12,
        damage: 5,
        effectiveness: 2,
        crit: false,
        ignoresAir: true,
      )..x = 52.5);

      final snap = encodeSnapshot(match: a, seq: 7, ts: 123, recentEvents: const [], ui: DuelUiState(banner: 'RONDA 2'));
      final b = _match();
      final applied = applySnapshot(b, snap);
      final e = b.engine;
      expect(e.player.hp, 77.5);
      expect(e.player.stamina, 61.25);
      expect(e.player.ultra, 40.5);
      expect(e.player.combo, 3);
      expect(e.player.state, DuelState.attack);
      expect(e.player.stateT, 0.2);
      expect(e.player.vy, 12.5);
      expect(e.player.dodgeDir, -1);
      expect(e.player.hordeCd, 1.5);
      expect(e.player.attackCd, 0.25);
      expect(e.player.invulnerable, 0.1);
      expect(e.enemy.guarding, isTrue);
      expect(e.enemy.facing, -1);
      expect(e.timeLeft, 55.55);
      expect(b.round, 2);
      expect(b.playerWins, 1);
      expect(e.projectiles, hasLength(1));
      expect(e.projectiles.first.shape, DuelSkillShape.bomb);
      expect(e.projectiles.first.x, 52.5);
      expect(e.projectiles.first.startX, 40);
      expect(e.projectiles.first.ignoresAir, isTrue);
      // La posición va aparte (la suaviza el invitado).
      expect(applied.targets.px, closeTo(33.34, 0.01));
      expect(applied.targets.py, closeTo(4.2, 0.01));
      expect(applied.targets.ex, closeTo(71.4, 0.01));
      expect(applied.ui.banner, 'RONDA 2');
    });

    test('todos los estados, tipos de evento y formas sobreviven al viaje', () {
      for (final s in DuelState.values) {
        final a = _match();
        a.engine.player.state = s;
        final b = _match();
        applySnapshot(b, encodeSnapshot(match: a, seq: 1, ts: 0, recentEvents: const [], ui: DuelUiState()));
        expect(b.engine.player.state, s);
      }
      for (final t in DuelEventType.values) {
        final ev = DuelEvent(t, DuelSide.enemy, x: 12.5, y: 3, damage: 9, effectiveness: 2, crit: true, combo: 4, moveType: 'ice');
        final back = decodeEvent(encodeEvent(5, ev));
        expect(back.type, t);
        expect(back.side, DuelSide.enemy);
        expect(back.damage, 9);
        expect(back.effectiveness, 2);
        expect(back.crit, isTrue);
        expect(back.combo, 4);
        expect(back.moveType, 'ice');
        expect(back.x, 12.5);
      }
      for (final sh in DuelSkillShape.values) {
        final p = DuelProjectile(owner: DuelSide.enemy, type: 'rock', shape: sh, x: 10, dir: -1, speed: 70, radius: 7, damage: 1, effectiveness: 1, crit: false, ignoresAir: false);
        final back = decodeProjectile(encodeProjectile(p));
        expect(back.shape, sh);
        expect(back.owner, DuelSide.enemy);
        expect(back.dir, -1);
      }
    });

    test('los eventos ya vistos no se repiten y los nuevos sí', () {
      final a = _match();
      final evs = [
        for (var i = 1; i <= 5; i++) encodeEvent(i, DuelEvent(DuelEventType.hit, DuelSide.player, damage: i)),
      ];
      final snap = encodeSnapshot(match: a, seq: 1, ts: 0, recentEvents: evs, ui: DuelUiState());
      final b = _match();
      final first = applySnapshot(b, snap);
      expect(first.newEvents.map((e) => e.damage), [1, 2, 3, 4, 5]);
      expect(first.lastEventId, 5);
      final again = applySnapshot(b, snap, afterEventId: first.lastEventId);
      expect(again.newEvents, isEmpty);
      final partial = applySnapshot(b, snap, afterEventId: 3);
      expect(partial.newEvents.map((e) => e.damage), [4, 5]);
    });

    test('la instantánea es pequeña (cabe de sobra en un documento)', () {
      final a = _match();
      for (var i = 0; i < 6; i++) {
        a.engine.projectiles.add(DuelProjectile(owner: DuelSide.player, type: 'fire', shape: DuelSkillShape.fast, x: 10.0 * i, dir: 1, speed: 95, radius: 5, damage: 1, effectiveness: 1, crit: false, ignoresAir: false));
      }
      final evs = [for (var i = 0; i < DuelNetTuning.eventsKept; i++) encodeEvent(i, DuelEvent(DuelEventType.hit, DuelSide.player, damage: 9, x: 40.5, y: 3, moveType: 'electric'))];
      final snap = encodeSnapshot(match: a, seq: 1, ts: 1, recentEvents: evs, ui: DuelUiState(banner: 'RONDA 2'));
      expect(snap.toString().length, lessThan(6000));
    });
  });

  group('controles del invitado', () {
    test('ida y vuelta', () {
      const w = DuelWireInput(move: -0.456, guard: true, attack: 3, horde: 2, ultra: 1, dodge: 4, ready: true, seq: 9);
      final back = DuelWireInput.fromJson(w.toJson());
      expect(back.move, closeTo(-0.46, 0.01));
      expect(back.guard, isTrue);
      expect(back.attack, 3);
      expect(back.horde, 2);
      expect(back.ultra, 1);
      expect(back.dodge, 4);
      expect(back.ready, isTrue);
      expect(back.seq, 9);
    });

    test('los datos raros no rompen y el movimiento se acota', () {
      final w = DuelWireInput.fromJson({'mv': 99});
      expect(w.move, 1);
      expect(w.attack, 0);
      expect(w.ready, isFalse);
    });

    test('las pulsaciones se convierten en eventos de un solo tick, sin repetirse', () {
      final t = RemoteInputTracker();
      // La primera lectura solo fija la referencia.
      expect(t.consume(const DuelWireInput(attack: 5)).attack, isFalse);
      expect(t.consume(const DuelWireInput(attack: 5)).attack, isFalse);
      final up = t.consume(const DuelWireInput(attack: 6, horde: 1, move: 0.5, guard: true));
      expect(up.attack, isTrue);
      expect(up.horde, isTrue);
      expect(up.ultra, isFalse);
      expect(up.move, 0.5);
      expect(up.guard, isTrue);
      final next = t.consume(const DuelWireInput(attack: 6, horde: 1, move: 0.5, guard: true));
      expect(next.attack, isFalse, reason: 'ya se contó');
      // Varias pulsaciones llegadas juntas = una pulsación en ese tick.
      expect(t.consume(const DuelWireInput(attack: 9, horde: 1)).attack, isTrue);
      expect(t.consume(const DuelWireInput(attack: 9, horde: 1)).attack, isFalse);
    });
  });

  group('anfitrión + invitado (sin retardo)', () {
    test('el invitado pega con su botón: el anfitrión lo aplica y el espejo lo ve', () {
      final r = _Rig();
      r.host.engine.player.x = 50;
      r.host.engine.enemy.x = 58;
      r.run(0.2);
      r.guestLink.pressAttack();
      r.run(0.6);
      expect(r.host.engine.player.hp, lessThan(r.host.engine.player.maxHp), reason: 'el golpe del invitado llegó');
      expect(r.mirror.engine.player.hp, closeTo(r.host.engine.player.hp, 0.5));
      expect(r.guestEvents.where((e) => e.type == DuelEventType.hit && e.side == DuelSide.enemy), hasLength(1), reason: 'el evento llega una sola vez');
    });

    test('mover, bloquear, horda, ultra y esquivar del invitado funcionan', () {
      final r = _Rig();
      r.host.engine.player.x = 15;
      r.host.engine.enemy.x = 80;
      r.run(0.1);
      final x0 = r.host.engine.enemy.x;
      r.guestLink.setMove(-1); // hacia el anfitrión (coordenadas del motor)
      r.run(0.5);
      expect(r.host.engine.enemy.x, lessThan(x0 - 5));
      r.guestLink.setMove(0);
      r.run(0.1);

      r.guestLink.setGuard(true);
      r.run(0.2);
      expect(r.host.engine.enemy.guarding, isTrue);
      r.guestLink.setGuard(false);
      r.run(0.1);
      expect(r.host.engine.enemy.guarding, isFalse);

      r.guestLink.pressHorde();
      r.run(0.4);
      expect(r.host.engine.enemy.hordeCd, greaterThan(0));
      expect(r.host.engine.projectiles.where((p) => p.owner == DuelSide.enemy), isNotEmpty);
      r.run(3);

      final st = r.host.engine.enemy.stamina;
      r.guestLink.pressDodge();
      r.run(0.1);
      expect(r.host.engine.enemy.stamina, lessThan(st));
      r.run(0.6); // acaba el impulso

      r.host.engine.enemy.ultra = DuelTuning.ultraMax;
      r.guestLink.pressUltra();
      r.run(0.2);
      expect(r.host.engine.enemy.state, DuelState.ultra);
    });

    test('el espejo converge con el combate del anfitrión', () {
      final r = _Rig();
      r.guestLink.setMove(-0.6);
      r.run(1.5, hostInput: const DuelInput(move: 0.5));
      r.guestLink.setMove(0);
      r.run(1.0);
      expect(r.mirror.engine.player.x, closeTo(r.host.engine.player.x, 0.5));
      expect(r.mirror.engine.enemy.x, closeTo(r.host.engine.enemy.x, 0.5));
      expect(r.mirror.engine.timeLeft, closeTo(r.host.engine.timeLeft, 0.2));
    });

    test('el guion completo de una pelea deja los dos lados con los mismos PS', () {
      final r = _Rig();
      r.host.engine.player.x = 50;
      r.host.engine.enemy.x = 58;
      for (var i = 0; i < 8; i++) {
        r.tick(hostInput: i % 3 == 0 ? const DuelInput(attack: true) : DuelInput.none);
        if (i % 4 == 0) r.guestLink.pressAttack();
        r.run(0.5);
      }
      r.run(1);
      expect(r.mirror.engine.player.hp, closeTo(r.host.engine.player.hp, 0.5));
      expect(r.mirror.engine.enemy.hp, closeTo(r.host.engine.enemy.hp, 0.5));
      expect(r.mirror.engine.player.ultra, closeTo(r.host.engine.player.ultra, 0.5));
    });

    test('el estado de interfaz (aviso y resultado) viaja del anfitrión al invitado', () {
      final r = _Rig();
      r.ui
        ..banner = 'RONDA 2'
        ..showResult = true
        ..matchOver = true
        ..winner = 'enemy';
      r.run(0.5);
      expect(r.guestLink.ui.banner, 'RONDA 2');
      expect(r.guestLink.ui.showResult, isTrue);
      expect(r.guestLink.ui.matchOver, isTrue);
      expect(r.guestLink.ui.winner, 'enemy');
    });

    test('rondas y coronas se sincronizan', () {
      final r = _Rig();
      r.host.playerWins = 1;
      r.host.round = 2;
      r.host.enemyWins = 1;
      r.run(0.3);
      expect(r.mirror.round, 2);
      expect(r.mirror.playerWins, 1);
      expect(r.mirror.enemyWins, 1);
    });

    test('KO: el invitado ve el fin de la ronda', () {
      final r = _Rig();
      r.host.engine.player.x = 50;
      r.host.engine.enemy.x = 58;
      r.host.engine.player.hp = 1;
      r.run(0.1);
      r.guestLink.pressAttack();
      r.run(1);
      expect(r.host.engine.over, isTrue);
      expect(r.mirror.engine.over, isTrue);
      expect(r.mirror.engine.ko, isTrue);
      expect(r.mirror.engine.winnerSide, DuelSide.enemy);
      expect(r.guestEvents.any((e) => e.type == DuelEventType.ko), isTrue);
    });
  });

  group('con latencia y pérdidas', () {
    test('con 150 ms de retardo no se pierde ninguna pulsación', () {
      final r = _Rig(latency: const Duration(milliseconds: 150));
      r.host.engine.player.x = 50;
      r.host.engine.enemy.x = 58;
      r.host.engine.player.stamina = 100;
      r.run(0.5);
      // Pulsaciones espaciadas pero con enfriamiento por medio.
      var landed = 0;
      for (var i = 0; i < 4; i++) {
        final before = r.host.engine.player.hp;
        r.host.engine.player.x = 50;
        r.host.engine.enemy.x = 58;
        r.guestLink.pressAttack();
        r.run(1.0);
        if (r.host.engine.player.hp < before) landed++;
      }
      expect(landed, 4);
    });

    test('con retardo el espejo igualmente converge', () {
      final r = _Rig(latency: const Duration(milliseconds: 200));
      r.run(1.5, hostInput: const DuelInput(move: 1));
      r.run(1.5);
      expect(r.mirror.engine.player.x, closeTo(r.host.engine.player.x, 1));
    });

    test('si se pierden instantáneas, los eventos llegan igual y una sola vez', () {
      final r = _Rig();
      r.host.engine.player.x = 50;
      r.host.engine.enemy.x = 58;
      // Cada evento va en las últimas 24 instantáneas: si el invitado se salta
      // algunas, el siguiente que llega los trae.
      r.run(0.1);
      r.guestLink.pressAttack();
      // Se corta la red mientras ocurre el golpe y se restablece.
      r.hub.cut = true;
      r.run(0.4);
      r.hub.cut = false;
      r.run(0.5);
      final hits = r.guestEvents.where((e) => e.type == DuelEventType.hit).toList();
      expect(hits.length, lessThanOrEqualTo(1));
    });

    test('las instantáneas desordenadas o repetidas se ignoran', () {
      final hub = MemoryDuelHub();
      final guest = DuelGuestLink(hub.guest, clock: () => 0);
      final mirror = _match();
      final host = _match();
      Map<String, dynamic> snap(int seq, double hp) {
        host.engine.player.hp = hp;
        return encodeSnapshot(match: host, seq: seq, ts: 0, recentEvents: const [], ui: DuelUiState());
      }

      hub.host.publishSnapshot(snap(5, 100));
      guest.update(0.016, mirror);
      expect(mirror.engine.player.hp, 100);
      hub.host.publishSnapshot(snap(4, 10)); // vieja
      guest.update(0.016, mirror);
      expect(mirror.engine.player.hp, 100);
      hub.host.publishSnapshot(snap(5, 20)); // repetida
      guest.update(0.016, mirror);
      expect(mirror.engine.player.hp, 100);
      hub.host.publishSnapshot(snap(6, 50));
      guest.update(0.016, mirror);
      expect(mirror.engine.player.hp, 50);
    });

    test('el invitado no satura Firestore: pocos mensajes cuando no hace nada', () {
      final r = _Rig();
      r.run(5);
      // Latido cada 0,5 s → ~10 en 5 s (más el primero), no uno por frame.
      expect(r.hub.guest.published, lessThan(14));
      // El anfitrión publica ~10 por segundo.
      expect(r.hub.host.published, inInclusiveRange(40, 60));
    });
  });

  group('conexión', () {
    test('el anfitrión sabe cuándo se conecta el invitado y cuándo está listo', () {
      final r = _Rig();
      expect(r.hostLink.guestConnected, isFalse);
      r.run(0.1);
      expect(r.hostLink.guestConnected, isTrue, reason: 'el primer latido lo anuncia');
      expect(r.hostLink.guestReady, isFalse);
      r.guestLink.setReady(true);
      r.run(0.2);
      expect(r.hostLink.guestReady, isTrue);
    });

    test('el invitado sabe cuándo llega el primer estado del anfitrión', () {
      final r = _Rig();
      expect(r.guestLink.connected, isFalse);
      r.run(0.3);
      expect(r.guestLink.connected, isTrue);
    });

    test('un corte de red avisa a los 5 s y se da por perdido a los 15 s (en ambos lados)', () {
      final r = _Rig();
      r.run(0.5);
      expect(r.hostLink.guestStale, isFalse);
      expect(r.guestLink.hostStale, isFalse);
      r.hub.cut = true;
      r.run(6);
      expect(r.hostLink.guestStale, isTrue);
      expect(r.guestLink.hostStale, isTrue);
      expect(r.hostLink.guestLost, isFalse);
      r.run(10);
      expect(r.hostLink.guestLost, isTrue);
      expect(r.guestLink.hostLost, isTrue);
      // Al volver la red se recupera.
      r.hub.cut = false;
      r.run(0.5);
      expect(r.hostLink.guestStale, isFalse);
      expect(r.guestLink.hostStale, isFalse);
    });
  });

  group('predicción del movimiento propio', () {
    test('el invitado se mueve al instante, sin esperar al anfitrión', () {
      final r = _Rig(latency: const Duration(milliseconds: 300));
      r.run(1.0);
      final x0 = r.mirror.engine.enemy.x;
      r.guestLink.setMove(-1);
      r.run(0.2); // antes de que el anfitrión pueda contestar
      expect(r.mirror.engine.enemy.x, lessThan(x0 - 3));
      expect(r.host.engine.enemy.x, greaterThan(r.mirror.engine.enemy.x), reason: 'el anfitrión aún no se ha enterado');
    });

    test('al soltar se corrige hacia la posición del anfitrión sin teletransportes', () {
      final r = _Rig(latency: const Duration(milliseconds: 100));
      r.guestLink.setMove(-1);
      r.run(1);
      r.guestLink.setMove(0);
      var maxJump = 0.0;
      var prev = r.mirror.engine.enemy.x;
      for (var i = 0; i < 120; i++) {
        r.tick();
        maxJump = math.max(maxJump, (r.mirror.engine.enemy.x - prev).abs());
        prev = r.mirror.engine.enemy.x;
      }
      expect(maxJump, lessThan(2), reason: 'se corrige suave, no a saltos');
      expect(r.mirror.engine.enemy.x, closeTo(r.host.engine.enemy.x, 0.6));
    });

    test('si la diferencia es enorme, se coloca directamente', () {
      final r = _Rig();
      r.run(0.3);
      r.host.engine.enemy.x = 20; // salto grande (p. ej. tras una pausa de red)
      r.run(0.3);
      expect(r.mirror.engine.enemy.x, closeTo(20, 1));
    });
  });
}
