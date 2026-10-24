import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'sound_backend.dart'
    if (dart.library.js_interop) 'sound_backend_web.dart' as backend;
import 'native_sound_guard_stub.dart'
    if (dart.library.js_interop) 'native_sound_guard_web.dart'
    if (dart.library.io) 'native_sound_guard_io.dart' as guard;

/// Contexto compartido: nadie pide el foco de audio (si no, cada
/// efectito pausaba la música sin devolverla) y en iOS se mezcla.
AudioContext buildSharedAudioContext() => AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    );

/// Sonido de todo el sistema SIN paquetes nuevos (evita trabar `pub get`).
/// Genera WAVs por código (tonos) y los reproduce en Web con AudioElement
/// y en escritorio/móvil con audioplayers (pool de 4 para solapar).
class SoundService {
  static bool enabled = true;
  static final Map<String, String> _urls = {};
  static final Map<String, Uint8List> _bytes = {};
  // Pool lazy: crearlo en tests sin binding rompería (MissingPlugin).
  static List<AudioPlayer>? _pool;
  static int _next = 0;

  static void toggle(bool v) => enabled = v;

  // (frecuencia, duración ms) por efecto.
  static const _defs = <String, List<List<int>>>{
    'hit': [
      [220, 120],
    ],
    'super': [
      [250, 90],
      [600, 160],
    ],
    'crit': [
      [850, 110],
      [1250, 180],
    ],
    'miss': [
      [320, 130],
      [150, 160],
    ],
    'ko': [
      [420, 200],
      [200, 200],
      [90, 260],
    ],
    'ultimate': [
      [400, 110],
      [600, 110],
      [800, 110],
      [1200, 220],
    ],
    'potion': [
      [520, 100],
      [920, 140],
    ],
    'select': [
      [700, 60],
    ],
    'correct': [
      [660, 120],
      [880, 180],
    ],
    'wrong': [
      [230, 180],
      [120, 220],
    ],
    'tick': [
      [1000, 50],
    ],
    'win': [
      [523, 140],
      [659, 140],
      [784, 140],
      [1046, 260],
    ],
    'fight': [
      [392, 110],
      [523, 110],
      [659, 110],
      [784, 240],
    ],
    'lose': [
      [400, 170],
      [300, 170],
      [200, 260],
    ],
  };

  static Uint8List _wav(List<List<int>> segs) {
    const rate = 22050;
    final samples = <int>[];
    for (final s in segs) {
      final freq = s[0].toDouble();
      final n = (rate * s[1] / 1000).round();
      for (var i = 0; i < n; i++) {
        final t = i / rate;
        final env = math.exp(-3.0 * i / n); // decaimiento
        final v = (math.sin(2 * math.pi * freq * t) * env * 12000).round();
        samples.add(v.clamp(-32768, 32767));
      }
    }
    final dataLen = samples.length * 2;
    final buf = ByteData(44 + dataLen);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        buf.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    buf.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little); // PCM
    buf.setUint16(22, 1, Endian.little); // mono
    buf.setUint32(24, rate, Endian.little);
    buf.setUint32(28, rate * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    str(36, 'data');
    buf.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      buf.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return buf.buffer.asUint8List();
  }

  static String _url(String name) {
    return _urls.putIfAbsent(name, () {
      final bytes = _wav(_defs[name] ?? _defs['select']!);
      return 'data:audio/wav;base64,${base64Encode(bytes)}';
    });
  }

  /// Reproduce un efecto. Nunca lanza. Suena en web Y en nativo.
  static void play(String name, {double volume = 0.5}) {
    if (!enabled) return;
    try {
      if (kIsWeb) {
        backend.playDataUrl(_url(name), volume);
      } else {
        _playBytes(_wav(_defs[name] ?? _defs['select']!), volume);
      }
    } catch (_) {}
  }

  /// True si hay engine Flutter (app real). En tests unitarios sin
  /// binding, audioplayers lanzaría errores async imposibles de atrapar:
  /// ahí el sonido es silencio.
  static bool get _engineReady {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reproduce bytes WAV en nativo con el pool (solapa ataques).
  /// Lazy + silencioso: en tests sin binding no hace nada.
  static void _playBytes(Uint8List bytes, double volume) {
    if (!_engineReady || guard.disableNativeSound) return;
    try {
      if (_pool == null) {
        _pool = List.generate(4, (_) => AudioPlayer());
        for (final p in _pool!) {
          p.setAudioContext(buildSharedAudioContext());
        }
      }
      final pool = _pool!;
      final player = pool[_next++ % pool.length];
      player.setVolume(volume.clamp(0.0, 1.0));
      player.play(BytesSource(bytes));
    } catch (_) {
      _pool = null;
    }
  }

  /// Bytes en caché para un efecto con nombre (nativo).
  static Uint8List _bytesFor(String key, List<List<int>> segs) {
    return _bytes.putIfAbsent(key, () => _wav(segs));
  }

  static void hit() => play('hit');
  static void superHit() => play('super');
  static void crit() => play('crit');
  static void miss() => play('miss');
  static void ko() => play('ko');
  static void ultimate() => play('ultimate');
  static void potion() => play('potion');
  static void select() => play('select');
  static void correct() => play('correct');
  static void wrong() => play('wrong');
  static void tick() => play('tick');
  static void win() => play('win');
  static void lose() => play('lose');

  /// Fanfarria de inicio de batalla (botón JUGAR).
  static void fight() => play('fight');

  /// Frecuencia base por tipo de movimiento (para variar el golpe).
  /// Devuelve [frecuencia, duración extra por potencia].
  static List<int> moveBase(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return [740, 60];
      case 'water':
        return [420, 70];
      case 'electric':
        return [1180, 50];
      case 'grass':
        return [520, 70];
      case 'ice':
        return [980, 60];
      case 'fighting':
        return [130, 80];
      case 'poison':
        return [310, 70];
      case 'ground':
        return [150, 80];
      case 'flying':
        return [860, 55];
      case 'psychic':
        return [1020, 55];
      case 'bug':
        return [640, 55];
      case 'rock':
        return [170, 80];
      case 'ghost':
        return [240, 75];
      case 'dragon':
        return [330, 75];
      case 'dark':
        return [200, 75];
      case 'steel':
        return [560, 65];
      case 'fairy':
        return [900, 55];
      case 'stellar':
        return [800, 60];
      default:
        return [220, 60]; // normal
    }
  }

  /// Sonido de golpe según el poder lanzado: varía por tipo + potencia.
  /// [power] 0-250 alarga el impacto y sube el volumen. Nunca lanza.
  static void playMove(String type, {int power = 40}) {
    if (!enabled) return;
    try {
      final base = moveBase(type);
      final freq = base[0];
      final extra = base[1];
      final p = power.clamp(0, 250);
      final dur1 = 70 + (p * 60 ~/ 120) + extra ~/ 2;
      final dur2 = 90 + (p * 80 ~/ 120);
      final volume = (0.35 + p / 350).clamp(0.3, 0.7);
      final segs = [
        [freq, dur1],
        [(freq * 1.5).round(), dur2],
      ];
      if (kIsWeb) {
        final key = 'move_${type.toLowerCase()}_${(p ~/ 20) * 20}';
        final url = _urls.putIfAbsent(key, () {
          final bytes = _wav(segs);
          return 'data:audio/wav;base64,${base64Encode(bytes)}';
        });
        backend.playDataUrl(url, volume);
      } else {
        final key = 'move_${type.toLowerCase()}_${(p ~/ 20) * 20}';
        _playBytes(_bytesFor(key, segs), volume);
      }
    } catch (_) {}
  }

  /// Silbido de lanzamiento (quien ATACA). Corto y agudo por tipo.
  static void playWhoosh(String type) {
    if (!enabled) return;
    try {
      final base = moveBase(type);
      final freq = (base[0] * 2).clamp(200, 2400);
      const key = 'whoosh';
      if (kIsWeb) {
        final url = _urls.putIfAbsent(key, () {
          final bytes = _wav([
            [freq, 70],
            [(freq * 1.3).round(), 60],
          ]);
          return 'data:audio/wav;base64,${base64Encode(bytes)}';
        });
        backend.playDataUrl(url, 0.35);
      } else {
        _playBytes(
            _bytesFor(key, [
              [freq, 70],
              [(freq * 1.3).round(), 60],
            ]),
            0.35);
      }
    } catch (_) {}
  }
}
