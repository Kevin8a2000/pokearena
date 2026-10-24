import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/pokemon.dart';

/// Código de sala de 6 caracteres (A-Z, 0-9, sin confusos). Puro y testeable.
String generateRoomCode([Random? random]) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = random ?? Random();
  return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Foto mínima del luchador para la sala: el Duelo solo usa id, nombre,
/// tipos y stats. Puro y testeable.
Map<String, dynamic> fighterToJson(PokemonDetail p) => {
      'id': p.id,
      'name': p.name,
      'types': p.types,
      'stats': p.stats,
    };

/// Reconstruye al luchador desde la foto de la sala.
PokemonDetail fighterFromJson(Map<dynamic, dynamic> e) => PokemonDetail(
      id: (e['id'] as num).toInt(),
      name: e['name'] as String,
      height: 0,
      weight: 0,
      types: List<String>.from(e['types'] as List),
      stats: {
        for (final kv in (e['stats'] as Map).entries) kv.key as String: (kv.value as num).toInt(),
      },
    );

/// Segundos sin noticias del rival tras los que se le da por desconectado.
const int kRoomStaleSeconds = 15;

/// Si Firestore no responde en este tiempo (red bloqueada, sin DNS, etc.),
/// se corta en vez de dejar la pantalla colgada para siempre sin aviso.
const Duration kRoomTimeout = Duration(seconds: 10);

/// Sala Firestore `rooms/{code}`: crea, une, observa y cierra la partida.
/// Esquema: {status(waiting|ready|finished), seed, seen{p0,p1},
/// players{p0,p1{name,fighter}}, result{winner,reason}}.
/// El juego en tiempo real viaja aparte, en `rooms/{code}/live/*`
/// (ver `duel/net/duel_transport.dart`).
class OnlineRoom {
  final FirebaseFirestore _db;
  final String code;
  final int mySlot; // 0 anfitrión, 1 invitado

  OnlineRoom(this._db, this.code, this.mySlot);

  bool get isHost => mySlot == 0;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('rooms').doc(code);

  FirebaseFirestore get db => _db;

  static Future<OnlineRoom> create(
    FirebaseFirestore db, {
    required String name,
    required PokemonDetail fighter,
    required int seed,
  }) async {
    final code = generateRoomCode();
    final room = OnlineRoom(db, code, 0);
    await room._doc.set({
      'status': 'waiting',
      'seed': seed,
      'mode': 'duel',
      'createdAt': FieldValue.serverTimestamp(),
      'seen': {'p0': DateTime.now().millisecondsSinceEpoch},
      'players': {
        'p0': {'name': name, 'fighter': fighterToJson(fighter)},
      },
      'result': {'winner': null, 'reason': null},
    }).timeout(kRoomTimeout);
    return room;
  }

  /// Une a una sala. Lanza [OnlineRoomError] si no existe, está llena
  /// o ya empezó.
  static Future<OnlineRoom> join(
    FirebaseFirestore db, {
    required String code,
    required String name,
    required PokemonDetail fighter,
  }) async {
    final ref = db.collection('rooms').doc(code.toUpperCase());
    final snap = await ref.get().timeout(kRoomTimeout);
    if (!snap.exists) throw OnlineRoomError('Sala no encontrada.');
    final data = snap.data()!;
    if (data['status'] != 'waiting') {
      throw OnlineRoomError('Esa sala ya empezó o terminó.');
    }
    final players = (data['players'] as Map?) ?? {};
    if (players.containsKey('p1')) {
      throw OnlineRoomError('Esa sala ya está llena.');
    }
    await ref.set({
      'players': {
        'p1': {'name': name, 'fighter': fighterToJson(fighter)},
      },
      'seen': {'p1': DateTime.now().millisecondsSinceEpoch},
    }, SetOptions(merge: true)).timeout(kRoomTimeout);
    return OnlineRoom(db, code.toUpperCase(), 1);
  }

  Future<Map<String, dynamic>?> fetchState() async {
    try {
      final snap = await _doc.get().timeout(kRoomTimeout);
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> markReady() => _doc.set({'status': 'ready'}, SetOptions(merge: true));

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch() => _doc.snapshots();

  Future<void> heartbeat() => _doc.set({
        'seen': {'p$mySlot': DateTime.now().millisecondsSinceEpoch},
      }, SetOptions(merge: true));

  /// Cierra la sala con su resultado ([winner] null = empate).
  Future<void> claimResult({int? winner, required String reason}) => _doc.set({
        'status': 'finished',
        'result': {'winner': winner == null ? null : 'p$winner', 'reason': reason},
      }, SetOptions(merge: true));

  /// Sale: si esperaba rival y soy anfitrión borro la sala; si peleaba,
  /// el rival gana por retiro (solo si aún no hay resultado).
  Future<void> leave({required bool wasFighting}) async {
    try {
      if (!wasFighting && mySlot == 0) {
        await _doc.delete();
        return;
      }
      if (wasFighting) {
        final snap = await _doc.get();
        // Solo si la partida no estaba ya cerrada (un empate también la cierra).
        if (snap.data()?['status'] != 'finished') {
          await claimResult(winner: 1 - mySlot, reason: 'Retiro del rival');
        }
      }
    } catch (_) {}
  }
}

class OnlineRoomError implements Exception {
  final String message;
  OnlineRoomError(this.message);
  @override
  String toString() => message;
}
