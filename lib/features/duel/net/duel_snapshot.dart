import '../duel_engine.dart';

/// Codificación del Duelo online. Funciones puras (sin Firestore): el
/// anfitrión convierte su combate en un mapa y el invitado lo vuelca sobre un
/// combate "espejo" que solo dibuja. También codifica los controles del
/// invitado.

/// Ajustes de red (todo junto para afinar latencia y consumo de Firestore).
class DuelNetTuning {
  /// Segundos entre instantáneas del anfitrión (~10 Hz).
  static const double snapshotInterval = 0.1;

  /// Segundos entre controles del invitado cuando no cambia nada (latido).
  static const double inputKeepAlive = 0.5;

  /// Máximo de escrituras de controles por segundo.
  static const double inputMinInterval = 0.05;

  /// Segundos sin noticias tras los que se avisa y tras los que se pierde.
  static const double staleWarn = 5;
  static const double staleLoss = 15;

  /// Suavizado de posiciones del invitado (1/s) y del movimiento propio.
  static const double followRate = 14;
  static const double ownFollowRate = 3;
  static const double snapDistance = 25;

  /// Eventos recientes que viajan en cada instantánea (por si se saltan).
  static const int eventsKept = 24;
}

/// Estado de interfaz que decide el anfitrión y el invitado solo muestra.
class DuelUiState {
  String? banner;
  bool showResult;

  /// 'player' (anfitrión), 'enemy' (invitado), 'draw' o null si no acabó.
  String? winner;
  bool matchOver;
  bool waitingRematch;
  DuelUiState({this.banner, this.showResult = false, this.winner, this.matchOver = false, this.waitingRematch = false});

  Map<String, dynamic> toJson() => {
        'b': banner,
        'r': showResult,
        'w': winner,
        'o': matchOver,
      };

  static DuelUiState fromJson(Map m) => DuelUiState(
        banner: m['b'] as String?,
        showResult: (m['r'] as bool?) ?? false,
        winner: m['w'] as String?,
        matchOver: (m['o'] as bool?) ?? false,
      );
}

/// Redondea a 2 decimales para que las instantáneas pesen poco.
double _r(double v) => (v * 100).roundToDouble() / 100;

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

// ------------------------------------------------------------------ luchador

Map<String, dynamic> encodeFighter(DuelFighter f) => {
      'x': _r(f.x),
      'y': _r(f.y),
      'vy': _r(f.vy),
      'hp': _r(f.hp),
      'st': _r(f.stamina),
      'ul': _r(f.ultra),
      'fc': f.facing > 0 ? 1 : -1,
      's': f.state.index,
      'sT': _r(f.stateT),
      'aC': _r(f.attackCd),
      'hC': _r(f.hordeCd),
      'dC': _r(f.dodgeCd),
      'iv': _r(f.invulnerable),
      'dD': f.dodgeDir == 0 ? 0 : (f.dodgeDir > 0 ? 1 : -1),
      'g': f.guarding,
      'cb': f.combo,
    };

/// Vuelca el estado en [f] salvo la posición (x, y), que la suaviza el
/// invitado; devuelve la posición objetivo.
({double x, double y}) applyFighter(DuelFighter f, Map m) {
  f.hp = _d(m['hp']);
  f.stamina = _d(m['st']);
  f.ultra = _d(m['ul']);
  f.facing = _d(m['fc']) >= 0 ? 1 : -1;
  final s = (m['s'] as num?)?.toInt() ?? 0;
  f.state = DuelState.values[s.clamp(0, DuelState.values.length - 1)];
  f.stateT = _d(m['sT']);
  f.vy = _d(m['vy']);
  f.attackCd = _d(m['aC']);
  f.hordeCd = _d(m['hC']);
  f.dodgeCd = _d(m['dC']);
  f.invulnerable = _d(m['iv']);
  f.dodgeDir = _d(m['dD']);
  f.guarding = (m['g'] as bool?) ?? false;
  f.combo = (m['cb'] as num?)?.toInt() ?? 0;
  return (x: _d(m['x']), y: _d(m['y']));
}

// --------------------------------------------------------------- proyectiles

Map<String, dynamic> encodeProjectile(DuelProjectile p) => {
      'o': p.owner.index,
      't': p.type,
      'sh': p.shape.index,
      'x': _r(p.x),
      'x0': _r(p.startX),
      'd': p.dir > 0 ? 1 : -1,
      'sp': _r(p.speed),
      'r': _r(p.radius),
      'ia': p.ignoresAir,
    };

DuelProjectile decodeProjectile(Map m) {
  final p = DuelProjectile(
    owner: DuelSide.values[(m['o'] as num?)?.toInt() == 1 ? 1 : 0],
    type: (m['t'] as String?) ?? 'normal',
    shape: DuelSkillShape.values[((m['sh'] as num?)?.toInt() ?? 0).clamp(0, DuelSkillShape.values.length - 1)],
    x: _d(m['x0']),
    dir: _d(m['d']) >= 0 ? 1 : -1,
    speed: _d(m['sp']),
    radius: _d(m['r']),
    damage: 0,
    effectiveness: 1,
    crit: false,
    ignoresAir: (m['ia'] as bool?) ?? false,
  );
  p.x = _d(m['x']);
  return p;
}

// ------------------------------------------------------------------- eventos

Map<String, dynamic> encodeEvent(int id, DuelEvent e) => {
      'id': id,
      't': e.type.index,
      's': e.side.index,
      'x': _r(e.x),
      'y': _r(e.y),
      'dm': e.damage,
      'ef': _r(e.effectiveness),
      'cr': e.crit,
      'cb': e.combo,
      'mt': e.moveType,
    };

DuelEvent decodeEvent(Map m) => DuelEvent(
      DuelEventType.values[((m['t'] as num?)?.toInt() ?? 0).clamp(0, DuelEventType.values.length - 1)],
      DuelSide.values[(m['s'] as num?)?.toInt() == 1 ? 1 : 0],
      x: _d(m['x']),
      y: _d(m['y']),
      damage: (m['dm'] as num?)?.toInt() ?? 0,
      effectiveness: m['ef'] == null ? 1 : _d(m['ef']),
      crit: (m['cr'] as bool?) ?? false,
      combo: (m['cb'] as num?)?.toInt() ?? 0,
      moveType: (m['mt'] as String?) ?? 'normal',
    );

// ------------------------------------------------------------- instantánea

/// Instantánea completa del combate para el invitado.
Map<String, dynamic> encodeSnapshot({
  required DuelMatch match,
  required int seq,
  required int ts,
  required List<Map<String, dynamic>> recentEvents,
  required DuelUiState ui,
}) {
  final en = match.engine;
  return {
    'seq': seq,
    'ts': ts,
    'tl': _r(en.timeLeft),
    'ro': match.round,
    'pw': match.playerWins,
    'ew': match.enemyWins,
    'ov': en.over,
    'ko': en.ko,
    'dr': en.draw,
    'wn': en.winnerSide?.index,
    'p': encodeFighter(en.player),
    'e': encodeFighter(en.enemy),
    'pr': [for (final p in en.projectiles) encodeProjectile(p)],
    'ev': recentEvents,
    'ui': ui.toJson(),
  };
}

/// Posiciones objetivo de la última instantánea (las suaviza el invitado).
class SnapTargets {
  double px, py, ex, ey;
  SnapTargets(this.px, this.py, this.ex, this.ey);
}

/// Resultado de volcar una instantánea.
class AppliedSnapshot {
  final SnapTargets targets;
  final List<DuelEvent> newEvents;
  final int lastEventId;
  final DuelUiState ui;
  AppliedSnapshot(this.targets, this.newEvents, this.lastEventId, this.ui);
}

/// Vuelca [data] sobre el combate espejo [mirror]. Devuelve los eventos que no
/// se habían visto ([afterEventId]) y la interfaz que decide el anfitrión.
AppliedSnapshot applySnapshot(DuelMatch mirror, Map data, {int afterEventId = 0}) {
  final en = mirror.engine;
  en.timeLeft = _d(data['tl']);
  mirror.round = (data['ro'] as num?)?.toInt() ?? 1;
  mirror.playerWins = (data['pw'] as num?)?.toInt() ?? 0;
  mirror.enemyWins = (data['ew'] as num?)?.toInt() ?? 0;
  en.over = (data['ov'] as bool?) ?? false;
  en.ko = (data['ko'] as bool?) ?? false;
  en.draw = (data['dr'] as bool?) ?? false;
  final w = (data['wn'] as num?)?.toInt();
  en.winnerSide = w == null ? null : DuelSide.values[w == 1 ? 1 : 0];
  final p = applyFighter(en.player, (data['p'] as Map?) ?? const {});
  final e = applyFighter(en.enemy, (data['e'] as Map?) ?? const {});
  en.projectiles
    ..clear()
    ..addAll([for (final m in (data['pr'] as List?) ?? const []) decodeProjectile(m as Map)]);

  var last = afterEventId;
  final fresh = <DuelEvent>[];
  for (final raw in (data['ev'] as List?) ?? const []) {
    final m = raw as Map;
    final id = (m['id'] as num?)?.toInt() ?? 0;
    if (id > last) {
      fresh.add(decodeEvent(m));
      last = id;
    }
  }
  return AppliedSnapshot(
    SnapTargets(p.x, p.y, e.x, e.y),
    fresh,
    last,
    DuelUiState.fromJson((data['ui'] as Map?) ?? const {}),
  );
}

// ---------------------------------------------------------------- controles

/// Controles del invitado tal como viajan: `move` y `guard` son estados
/// mantenidos; los botones son contadores acumulativos (cada pulsación suma),
/// así el anfitrión no pierde ninguna aunque lleguen juntas o tarde.
class DuelWireInput {
  final double move;
  final bool guard;
  final int attack;
  final int horde;
  final int ultra;
  final int dodge;

  /// El invitado ya cerró su tutorial y está listo para empezar.
  final bool ready;
  final int seq;
  const DuelWireInput({
    this.move = 0,
    this.guard = false,
    this.attack = 0,
    this.horde = 0,
    this.ultra = 0,
    this.dodge = 0,
    this.ready = false,
    this.seq = 0,
  });

  Map<String, dynamic> toJson() => {
        'mv': _r(move),
        'gd': guard,
        'at': attack,
        'hd': horde,
        'ul': ultra,
        'dg': dodge,
        'rd': ready,
        'sq': seq,
      };

  factory DuelWireInput.fromJson(Map m) => DuelWireInput(
        move: _d(m['mv']).clamp(-1.0, 1.0).toDouble(),
        guard: (m['gd'] as bool?) ?? false,
        attack: (m['at'] as num?)?.toInt() ?? 0,
        horde: (m['hd'] as num?)?.toInt() ?? 0,
        ultra: (m['ul'] as num?)?.toInt() ?? 0,
        dodge: (m['dg'] as num?)?.toInt() ?? 0,
        ready: (m['rd'] as bool?) ?? false,
        seq: (m['sq'] as num?)?.toInt() ?? 0,
      );
}

/// Convierte los contadores del invitado en pulsaciones de un tick para el
/// motor. La primera lectura solo fija la referencia (no dispara nada).
class RemoteInputTracker {
  bool _seeded = false;
  int _a = 0, _h = 0, _u = 0, _d = 0;

  DuelInput consume(DuelWireInput w) {
    if (!_seeded) {
      _seeded = true;
      _a = w.attack;
      _h = w.horde;
      _u = w.ultra;
      _d = w.dodge;
      return DuelInput(move: w.move, guard: w.guard);
    }
    final input = DuelInput(
      move: w.move,
      guard: w.guard,
      attack: w.attack > _a,
      horde: w.horde > _h,
      ultra: w.ultra > _u,
      dodge: w.dodge > _d,
    );
    _a = w.attack;
    _h = w.horde;
    _u = w.ultra;
    _d = w.dodge;
    return input;
  }
}
