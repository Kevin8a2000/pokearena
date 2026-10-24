import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/features/duel/net/duel_snapshot.dart';
import 'package:pokearena/features/duel/net/duel_transport.dart';
import 'package:pokearena/features/online/online_room.dart';

PokemonDetail _mon(int id, String name, List<String> types) => PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: types,
      stats: const {'hp': 45, 'attack': 49, 'defense': 49, 'special-attack': 65, 'special-defense': 65, 'speed': 45},
    );

void main() {
  group('código de sala', () {
    test('6 caracteres legibles (sin 0/O/1/I/L)', () {
      final code = generateRoomCode(Random(1));
      expect(code.length, 6);
      expect(RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code), isTrue);
      for (var i = 0; i < 200; i++) {
        expect(generateRoomCode().contains(RegExp('[01OIL]')), isFalse);
      }
    });

    test('con la misma semilla sale el mismo y con otra, distinto', () {
      expect(generateRoomCode(Random(7)), generateRoomCode(Random(7)));
      expect(generateRoomCode(Random(7)), isNot(generateRoomCode(Random(8))));
    });
  });

  group('foto del luchador', () {
    test('viaja y vuelve intacta', () {
      final bulba = _mon(1, 'bulbasaur', ['grass', 'poison']);
      final back = fighterFromJson(fighterToJson(bulba));
      expect(back.id, 1);
      expect(back.name, 'bulbasaur');
      expect(back.types, ['grass', 'poison']);
      expect(back.stats['hp'], 45);
      expect(back.stats['special-attack'], 65);
    });

    test('tolera números como double (así los devuelve Firestore en web)', () {
      final back = fighterFromJson({
        'id': 25.0,
        'name': 'pikachu',
        'types': ['electric'],
        'stats': {'hp': 35.0, 'attack': 55.0},
      });
      expect(back.id, 25);
      expect(back.stats['hp'], 35);
    });
  });

  group('sala en Firestore', () {
    late FakeFirebaseFirestore db;
    setUp(() => db = FakeFirebaseFirestore());

    test('crear deja la sala esperando con el luchador del anfitrión', () async {
      final room = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'bulbasaur', ['grass']), seed: 42);
      expect(room.mySlot, 0);
      expect(room.isHost, isTrue);
      expect(room.code.length, 6);
      final data = (await db.collection('rooms').doc(room.code).get()).data()!;
      expect(data['status'], 'waiting');
      expect(data['seed'], 42);
      expect(data['mode'], 'duel');
      expect(data['players']['p0']['name'], 'Ash');
      expect(data['players']['p0']['fighter']['id'], 1);
      expect(data['players'].containsKey('p1'), isFalse);
      expect(data['result']['winner'], isNull);
    });

    test('unirse con el código añade al invitado (sin importar mayúsculas)', () async {
      final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'bulbasaur', ['grass']), seed: 1);
      final guest = await OnlineRoom.join(db, code: host.code.toLowerCase(), name: 'Misty', fighter: _mon(7, 'squirtle', ['water']));
      expect(guest.mySlot, 1);
      expect(guest.isHost, isFalse);
      expect(guest.code, host.code);
      final data = (await db.collection('rooms').doc(host.code).get()).data()!;
      expect(data['players']['p1']['name'], 'Misty');
      expect(data['players']['p1']['fighter']['name'], 'squirtle');
      expect(data['players']['p0']['name'], 'Ash', reason: 'no pisa al anfitrión');
    });

    test('errores claros: sala inexistente, llena o ya empezada', () async {
      await expectLater(
        OnlineRoom.join(db, code: 'ZZZZZZ', name: 'X', fighter: _mon(1, 'a', ['normal'])),
        throwsA(isA<OnlineRoomError>().having((e) => e.message, 'message', 'Sala no encontrada.')),
      );

      final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'a', ['normal']), seed: 1);
      await OnlineRoom.join(db, code: host.code, name: 'Misty', fighter: _mon(2, 'b', ['normal']));
      await expectLater(
        OnlineRoom.join(db, code: host.code, name: 'Brock', fighter: _mon(3, 'c', ['normal'])),
        throwsA(isA<OnlineRoomError>().having((e) => e.message, 'message', 'Esa sala ya está llena.')),
      );

      final other = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'a', ['normal']), seed: 1);
      await other.markReady();
      await expectLater(
        OnlineRoom.join(db, code: other.code, name: 'Tarde', fighter: _mon(2, 'b', ['normal'])),
        throwsA(isA<OnlineRoomError>().having((e) => e.message, 'message', 'Esa sala ya empezó o terminó.')),
      );
    });

    test('markReady y heartbeat actualizan la sala', () async {
      final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'a', ['normal']), seed: 1);
      final before = ((await host.fetchState())!['seen'] as Map)['p0'] as int;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await host.heartbeat();
      final after = ((await host.fetchState())!['seen'] as Map)['p0'] as int;
      expect(after, greaterThanOrEqualTo(before));
      await host.markReady();
      expect((await host.fetchState())!['status'], 'ready');
    });

    test('el anfitrión que cancela la espera borra la sala', () async {
      final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'a', ['normal']), seed: 1);
      await host.leave(wasFighting: false);
      expect((await db.collection('rooms').doc(host.code).get()).exists, isFalse);
    });

    test('si el invitado cancela, la sala no se borra', () async {
      final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'a', ['normal']), seed: 1);
      final guest = await OnlineRoom.join(db, code: host.code, name: 'Misty', fighter: _mon(2, 'b', ['normal']));
      await guest.leave(wasFighting: false);
      expect((await db.collection('rooms').doc(host.code).get()).exists, isTrue);
    });

    test('salir a media pelea da la victoria al rival por retiro', () async {
      final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'a', ['normal']), seed: 1);
      final guest = await OnlineRoom.join(db, code: host.code, name: 'Misty', fighter: _mon(2, 'b', ['normal']));
      await host.markReady();
      await guest.leave(wasFighting: true);
      final data = (await host.fetchState())!;
      expect(data['status'], 'finished');
      expect(data['result']['winner'], 'p0');
      expect(data['result']['reason'], 'Retiro del rival');
    });

    test('salir después de acabar (también tras un empate) no cambia el resultado', () async {
      final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'a', ['normal']), seed: 1);
      final guest = await OnlineRoom.join(db, code: host.code, name: 'Misty', fighter: _mon(2, 'b', ['normal']));
      await host.claimResult(winner: null, reason: 'Fin del combate'); // empate
      await guest.leave(wasFighting: true);
      final data = (await host.fetchState())!;
      expect(data['result']['winner'], isNull);
      expect(data['result']['reason'], 'Fin del combate');

      final host2 = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'a', ['normal']), seed: 1);
      final guest2 = await OnlineRoom.join(db, code: host2.code, name: 'Misty', fighter: _mon(2, 'b', ['normal']));
      await host2.claimResult(winner: 1, reason: 'Fin del combate');
      await host2.leave(wasFighting: true);
      await guest2.leave(wasFighting: true);
      expect(((await host2.fetchState())!['result'] as Map)['winner'], 'p1');
    });

    test('la sala se puede observar y avisa cuando entra el rival', () async {
      final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(1, 'a', ['normal']), seed: 1);
      final seen = <bool>[];
      final sub = host.watch().listen((s) => seen.add(((s.data()?['players'] as Map?) ?? {}).containsKey('p1')));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await OnlineRoom.join(db, code: host.code, name: 'Misty', fighter: _mon(2, 'b', ['normal']));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(seen.first, isFalse);
      expect(seen.last, isTrue);
    });
  });

  group('canal de tiempo real en Firestore', () {
    test('el anfitrión publica y el invitado lo recibe; y al revés con los controles', () async {
      final db = FakeFirebaseFirestore();
      final host = FirestoreDuelTransport(db, 'ABC234');
      final guest = FirestoreDuelTransport(db, 'ABC234');

      final snaps = <Map<String, dynamic>>[];
      final inputs = <Map<String, dynamic>>[];
      final s1 = guest.snapshots.listen(snaps.add);
      final s2 = host.inputs.listen(inputs.add);

      host.publishSnapshot({'seq': 1, 'tl': 90.0});
      guest.publishInput(const DuelWireInput(move: 0.5, attack: 2, ready: true).toJson());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      host.publishSnapshot({'seq': 2, 'tl': 89.5});
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(snaps.map((m) => m['seq']), contains(2));
      expect(snaps.last['tl'], 89.5);
      expect(DuelWireInput.fromJson(inputs.last).attack, 2);
      expect(DuelWireInput.fromJson(inputs.last).ready, isTrue);

      // Los dos canales viven bajo la sala, separados de su documento principal.
      expect((await db.collection('rooms').doc('ABC234').collection('live').doc('host').get()).exists, isTrue);
      expect((await db.collection('rooms').doc('ABC234').collection('live').doc('guest').get()).exists, isTrue);
      await s1.cancel();
      await s2.cancel();
    });

    test('un documento que aún no existe no produce eventos', () async {
      final db = FakeFirebaseFirestore();
      final t = FirestoreDuelTransport(db, 'NOROOM');
      final got = <Map<String, dynamic>>[];
      final sub = t.snapshots.listen(got.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(got, isEmpty);
      await sub.cancel();
    });
  });
}
