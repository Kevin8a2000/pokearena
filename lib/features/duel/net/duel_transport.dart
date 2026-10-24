import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Canal de tiempo real entre anfitrión e invitado. Solo transporta mapas:
/// el anfitrión publica instantáneas y escucha los controles; el invitado
/// publica controles y escucha instantáneas.
abstract class DuelTransport {
  /// Anfitrión → invitado.
  void publishSnapshot(Map<String, dynamic> data);

  /// Invitado → anfitrión.
  void publishInput(Map<String, dynamic> data);

  /// Instantáneas del anfitrión (las escucha el invitado).
  Stream<Map<String, dynamic>> get snapshots;

  /// Controles del invitado (los escucha el anfitrión).
  Stream<Map<String, dynamic>> get inputs;

  Future<void> close();
}

/// Firestore: `rooms/{code}/live/host` (instantánea) y `live/guest` (controles).
/// Las escrituras no se esperan: si una falla, la siguiente la sustituye.
class FirestoreDuelTransport implements DuelTransport {
  final FirebaseFirestore _db;
  final String code;
  FirestoreDuelTransport(this._db, this.code);

  CollectionReference<Map<String, dynamic>> get _live => _db.collection('rooms').doc(code).collection('live');

  @override
  void publishSnapshot(Map<String, dynamic> data) {
    _live.doc('host').set(data).catchError((_) {});
  }

  @override
  void publishInput(Map<String, dynamic> data) {
    _live.doc('guest').set(data).catchError((_) {});
  }

  Stream<Map<String, dynamic>> _watch(String doc) =>
      _live.doc(doc).snapshots().where((s) => s.exists && s.data() != null).map((s) => s.data()!);

  @override
  Stream<Map<String, dynamic>> get snapshots => _watch('host');

  @override
  Stream<Map<String, dynamic>> get inputs => _watch('guest');

  @override
  Future<void> close() async {}
}

/// Canal en memoria para pruebas: dos extremos (`host` y `guest`) conectados,
/// con latencia simulada por un reloj manual (`advance`). Sin latencia entrega
/// al instante.
class MemoryDuelHub {
  /// Retardo de cada mensaje (en cada sentido).
  Duration latency;
  Duration _now = Duration.zero;
  final List<_Pending> _queue = [];
  late final MemoryDuelTransport host = MemoryDuelTransport._(this, isHost: true);
  late final MemoryDuelTransport guest = MemoryDuelTransport._(this, isHost: false);

  /// Si es true se descartan los mensajes (corte de red simulado).
  bool cut = false;

  MemoryDuelHub({this.latency = Duration.zero});

  void _send(bool toGuest, Map<String, dynamic> data) {
    if (cut) return;
    final copy = Map<String, dynamic>.from(data);
    if (latency == Duration.zero) {
      (toGuest ? guest : host)._deliver(copy, toGuest);
    } else {
      _queue.add(_Pending(_now + latency, toGuest, copy));
    }
  }

  /// Avanza el reloj y entrega los mensajes cuyo retardo ya pasó.
  void advance(Duration d) {
    _now += d;
    final due = _queue.where((m) => m.at <= _now).toList();
    _queue.removeWhere((m) => m.at <= _now);
    for (final m in due) {
      (m.toGuest ? guest : host)._deliver(m.data, m.toGuest);
    }
  }

  int get inFlight => _queue.length;
}

class _Pending {
  final Duration at;
  final bool toGuest;
  final Map<String, dynamic> data;
  _Pending(this.at, this.toGuest, this.data);
}

class MemoryDuelTransport implements DuelTransport {
  final MemoryDuelHub _hub;
  final bool isHost;
  final StreamController<Map<String, dynamic>> _snaps = StreamController.broadcast(sync: true);
  final StreamController<Map<String, dynamic>> _ins = StreamController.broadcast(sync: true);
  int published = 0;
  MemoryDuelTransport._(this._hub, {required this.isHost});

  void _deliver(Map<String, dynamic> data, bool toGuest) {
    if (toGuest) {
      _snaps.add(data);
    } else {
      _ins.add(data);
    }
  }

  @override
  void publishSnapshot(Map<String, dynamic> data) {
    published++;
    _hub._send(true, data);
  }

  @override
  void publishInput(Map<String, dynamic> data) {
    published++;
    _hub._send(false, data);
  }

  @override
  Stream<Map<String, dynamic>> get snapshots => _snaps.stream;

  @override
  Stream<Map<String, dynamic>> get inputs => _ins.stream;

  @override
  Future<void> close() async {
    await _snaps.close();
    await _ins.close();
  }
}
