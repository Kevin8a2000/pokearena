import 'dart:async';
import 'dart:math' as math;

import '../duel_engine.dart';
import 'duel_snapshot.dart';
import 'duel_transport.dart';

/// Reloj en segundos (inyectable para pruebas).
typedef DuelClock = double Function();

DuelClock _stopwatchClock() {
  final sw = Stopwatch()..start();
  return () => sw.elapsedMicroseconds / 1e6;
}

/// Extremo del ANFITRIÓN: ejecuta el combate y publica instantáneas; lee los
/// controles del invitado (con las pulsaciones convertidas en eventos de un
/// tick).
class DuelHostLink {
  final DuelTransport transport;
  final DuelClock _clock;
  final RemoteInputTracker _tracker = RemoteInputTracker();
  StreamSubscription<Map<String, dynamic>>? _sub;

  DuelWireInput? _latest;
  double _lastInputAt = 0;
  bool _hello = false;
  int _seq = 0;
  int _nextEventId = 1;
  double _sinceSnap = 0;
  final List<Map<String, dynamic>> _events = [];

  DuelHostLink(this.transport, {DuelClock? clock}) : _clock = clock ?? _stopwatchClock() {
    _lastInputAt = _clock();
    _sub = transport.inputs.listen((m) {
      _latest = DuelWireInput.fromJson(m);
      _lastInputAt = _clock();
      _hello = true;
    });
  }

  /// El invitado ya se conectó.
  bool get guestConnected => _hello;

  /// El invitado cerró su tutorial y está listo.
  bool get guestReady => _latest?.ready ?? false;

  /// Segundos desde el último mensaje del invitado.
  double get secondsSinceGuest => _clock() - _lastInputAt;

  bool get guestStale => _hello && secondsSinceGuest > DuelNetTuning.staleWarn;
  bool get guestLost => secondsSinceGuest > DuelNetTuning.staleLoss;

  /// Controles del invitado para este tick (pulsaciones de un solo tick).
  DuelInput guestInput() => _latest == null ? DuelInput.none : _tracker.consume(_latest!);

  /// Guarda los eventos de este tick para la próxima instantánea.
  void addEvents(List<DuelEvent> events) {
    for (final e in events) {
      _events.add(encodeEvent(_nextEventId++, e));
    }
    while (_events.length > DuelNetTuning.eventsKept) {
      _events.removeAt(0);
    }
  }

  /// Publica una instantánea si toca (o siempre con [force]).
  void maybePublish(double dt, DuelMatch match, DuelUiState ui, {bool force = false}) {
    _sinceSnap += dt;
    if (!force && _sinceSnap < DuelNetTuning.snapshotInterval) return;
    _sinceSnap = 0;
    _seq++;
    transport.publishSnapshot(encodeSnapshot(
      match: match,
      seq: _seq,
      ts: DateTime.now().millisecondsSinceEpoch,
      recentEvents: List.of(_events),
      ui: ui,
    ));
  }

  Future<void> close() async {
    await _sub?.cancel();
    await transport.close();
  }
}

/// Extremo del INVITADO: envía sus controles y dibuja el combate espejo con
/// lo que recibe, suavizando las posiciones y prediciendo su propio avance.
class DuelGuestLink {
  final DuelTransport transport;
  final DuelClock _clock;
  StreamSubscription<Map<String, dynamic>>? _sub;

  Map<String, dynamic>? _pending; // instantánea sin volcar
  int _lastSnapSeq = 0;
  double _lastSnapAt = 0;
  int _lastEventId = 0;
  SnapTargets? _targets;
  DuelUiState ui = DuelUiState();

  // Controles.
  double _move = 0;
  bool _guard = false;
  int _attack = 0, _horde = 0, _ultra = 0, _dodge = 0;
  bool ready = false;
  int _inputSeq = 0;
  bool _dirty = true;
  double _sinceSend = 99;

  DuelGuestLink(this.transport, {DuelClock? clock}) : _clock = clock ?? _stopwatchClock() {
    _lastSnapAt = _clock();
    _sub = transport.snapshots.listen((m) {
      final seq = (m['seq'] as num?)?.toInt() ?? 0;
      if (seq <= _lastSnapSeq) return; // desordenada o repetida
      _lastSnapSeq = seq;
      _lastSnapAt = _clock();
      _pending = m;
    });
  }

  /// Ya llegó la primera instantánea del anfitrión.
  bool get connected => _lastSnapSeq > 0;

  double get secondsSinceHost => _clock() - _lastSnapAt;
  bool get hostStale => connected && secondsSinceHost > DuelNetTuning.staleWarn;
  bool get hostLost => secondsSinceHost > DuelNetTuning.staleLoss;

  // ---- controles (coordenadas del MOTOR: el que llama ya espejó el sentido) --

  void setMove(double v) {
    if ((v - _move).abs() < 0.02) return;
    _move = v;
    _dirty = true;
  }

  void setGuard(bool g) {
    if (g == _guard) return;
    _guard = g;
    _dirty = true;
  }

  void setReady(bool r) {
    if (r == ready) return;
    ready = r;
    _dirty = true;
  }

  void pressAttack() {
    _attack++;
    _dirty = true;
  }

  void pressHorde() {
    _horde++;
    _dirty = true;
  }

  void pressUltra() {
    _ultra++;
    _dirty = true;
  }

  void pressDodge() {
    _dodge++;
    _dirty = true;
  }

  void _send() {
    _inputSeq++;
    transport.publishInput(DuelWireInput(
      move: _move,
      guard: _guard,
      attack: _attack,
      horde: _horde,
      ultra: _ultra,
      dodge: _dodge,
      ready: ready,
      seq: _inputSeq,
    ).toJson());
    _dirty = false;
    _sinceSend = 0;
  }

  /// Un frame: envía controles si cambiaron (o de latido), vuelca la última
  /// instantánea sobre [mirror] y suaviza posiciones. Devuelve los eventos
  /// nuevos para dibujar efectos.
  List<DuelEvent> update(double dt, DuelMatch mirror) {
    _sinceSend += dt;
    if ((_dirty && _sinceSend >= DuelNetTuning.inputMinInterval) || _sinceSend >= DuelNetTuning.inputKeepAlive) {
      _send();
    }

    var events = const <DuelEvent>[];
    final snap = _pending;
    if (snap != null) {
      _pending = null;
      final applied = applySnapshot(mirror, snap, afterEventId: _lastEventId);
      _lastEventId = applied.lastEventId;
      _targets = applied.targets;
      ui = applied.ui;
      events = applied.newEvents;
      // La primera instantánea coloca a los luchadores sin deslizarlos.
      if (_firstApply) {
        _firstApply = false;
        mirror.engine.player.x = applied.targets.px;
        mirror.engine.player.y = applied.targets.py;
        mirror.engine.enemy.x = applied.targets.ex;
        mirror.engine.enemy.y = applied.targets.ey;
      }
    }
    _smooth(dt, mirror);
    return events;
  }

  bool _firstApply = true;

  void _smooth(double dt, DuelMatch mirror) {
    final t = _targets;
    if (t == null) return;
    final en = mirror.engine;
    double follow(double cur, double target, double rate) {
      if ((cur - target).abs() > DuelNetTuning.snapDistance) return target;
      return cur + (target - cur) * (1 - math.exp(-rate * dt));
    }

    en.player.x = follow(en.player.x, t.px, DuelNetTuning.followRate);
    en.player.y = follow(en.player.y, t.py, 24);

    // Mi luchador es el `enemy` del motor: avanza al instante con mis
    // controles y se corrige despacio hacia lo que dice el anfitrión.
    final me = en.enemy;
    if (me.state == DuelState.idle && !me.guarding && _move != 0) {
      me.x = (me.x + _move * DuelTuning.walkSpeed * dt).clamp(DuelTuning.minX, DuelTuning.maxX).toDouble();
      me.x = follow(me.x, t.ex, DuelNetTuning.ownFollowRate);
    } else {
      me.x = follow(me.x, t.ex, DuelNetTuning.followRate);
    }
    me.y = follow(me.y, t.ey, 24);

    // Los proyectiles siguen volando entre instantáneas.
    for (final p in en.projectiles) {
      p.x += p.dir * p.speed * dt;
    }
  }

  Future<void> close() async {
    await _sub?.cancel();
    await transport.close();
  }
}
