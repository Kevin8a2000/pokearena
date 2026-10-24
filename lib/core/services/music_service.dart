import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_sound_guard_stub.dart'
    if (dart.library.js_interop) 'native_sound_guard_web.dart'
    if (dart.library.io) 'native_sound_guard_io.dart' as guard;
import 'sound_service.dart';

/// Música de fondo del juego (canal propio, en loop bajito).
/// Arranca con el botón JUGAR y respeta el sonido general + su switch.
class MusicService {
  static const _prefsKey = 'pokearena-music';
  static const _volKey = 'pokearena-music-vol';
  static const _asset = 'audio/music.mp3';
  static const double defaultVolume = 0.3;

  static bool musicOn = true;
  static double volume = defaultVolume;
  static AudioPlayer? _player;
  static StreamSubscription<void>? _stateSub;
  static bool _playing = false;
  static bool _pausedByBattle = false;

  static bool get playing => _playing;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      musicOn = prefs.getBool(_prefsKey) ?? true;
      volume =
          (prefs.getDouble(_volKey) ?? defaultVolume).clamp(0.0, 1.0);
    } catch (_) {}
  }

  static Future<void> setMusic(bool v) async {
    musicOn = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, v);
    } catch (_) {}
    if (!v) {
      await stop();
    }
  }

  /// Volumen 0..1 con persistencia; se aplica en vivo si suena.
  static Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volKey, volume);
    } catch (_) {}
    try {
      await _player?.setVolume(volume);
    } catch (_) {}
  }

  /// La batalla no lleva música de fondo (ya vendrá la suya):
  /// se pausa al empezar y se reanuda al salir.
  static Future<void> pauseBattle() async {
    if (!_playing) return;
    _pausedByBattle = true;
    try {
      await _player?.pause();
    } catch (_) {}
  }

  static Future<void> resumeBattle() async {
    if (!_pausedByBattle) return;
    _pausedByBattle = false;
    if (!musicOn || !SoundService.enabled) {
      _playing = false;
      return;
    }
    try {
      await _player?.resume();
    } catch (_) {
      _playing = false;
    }
  }

  static bool get _canPlay {
    if (!SoundService.enabled || !musicOn) return false;
    try {
      WidgetsBinding.instance;
    } catch (_) {
      return false;
    }
    return !guard.disableNativeSound;
  }

  /// Arranca el loop (una sola vez). Nunca lanza.
  static Future<void> start() async {
    if (_playing || !_canPlay) return;
    try {
      await _ensurePlayer();
      await _player!.setVolume(volume);
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource(_asset));
      _playing = true;
    } catch (_) {
      await _stateSub?.cancel();
      _stateSub = null;
      _player = null;
    }
  }

  static Future<void> _ensurePlayer() async {
    if (_player != null) return;
    final p = AudioPlayer();
    try {
      await p.setAudioContext(buildSharedAudioContext());
    } catch (_) {}
    _player = p;
    await _stateSub?.cancel();
    // Vigilante: si algo externo pausa la música fuera de batalla,
    // se reanuda sola. Todo queda en el log para diagnóstico.
    _stateSub = p.onPlayerStateChanged.listen((s) {
      debugPrint('[Music] estado nativo: $s');
      if (_playing && !_pausedByBattle && s == PlayerState.paused) {
        debugPrint('[Music] pausa externa: reanudando');
        _player?.resume();
      }
    });
  }

  static Future<void> stop() async {
    _playing = false;
    try {
      await _player?.stop();
    } catch (_) {}
  }
}
