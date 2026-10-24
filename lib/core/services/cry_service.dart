import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

import 'sound_service.dart';

/// URLs de respaldo para el grito (repo oficial PokeAPI/cries).
/// Los ids 1-151 salen del asset local (sin internet); el resto por red.
List<String> cryCandidates(int id) {
  final latest = 'cries/pokemon/latest/$id.ogg';
  final legacy = 'cries/pokemon/legacy/$id.ogg';
  final urls = [
    'https://cdn.jsdelivr.net/gh/PokeAPI/cries@main/$latest',
    'https://raw.githubusercontent.com/PokeAPI/cries/main/$latest',
  ];
  if (id >= 1 && id <= 649) {
    urls.addAll([
      'https://cdn.jsdelivr.net/gh/PokeAPI/cries@main/$legacy',
      'https://raw.githubusercontent.com/PokeAPI/cries/main/$legacy',
    ]);
  }
  return urls;
}

/// True si el grito está empaquetado en assets (Gen 1, ids 1-151).
bool isLocalCry(int id) => id >= 1 && id <= CryService.localMaxId;

/// Gritos originales por personaje. Respeta el mute global y
/// nunca lanza aunque no haya red ni archivo.
class CryService {
  /// Último id con asset local (Gen 1 copiada a assets/cries/).
  static const int localMaxId = 151;

  static final List<AudioPlayer> _pool =
      List.generate(3, (_) => AudioPlayer());
  static int _next = 0;
  static final Map<int, Uint8List> _mem = {};

  static Future<Uint8List?> _fetch(int id) async {
    final hit = _mem[id];
    if (hit != null) return hit;
    for (final url in cryCandidates(id)) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final bytes = Uint8List.fromList(res.bodyBytes);
          if (_mem.length >= 60) _mem.remove(_mem.keys.first);
          _mem[id] = bytes;
          return bytes;
        }
      } catch (_) {
        // Timeout o fallo: siguiente respaldo.
      }
    }
    return null;
  }

  /// Suena el grito del Pokémon [id]. En KO usa rate 0.6 (desmayo).
  /// [volume] bajo por defecto para no saturar en batalla.
  static Future<bool> playCry(int id,
      {double rate = 1.0, double volume = 0.35}) async {
    if (!SoundService.enabled) return false;
    try {
      final player = _pool[_next++ % _pool.length];
      await player.setVolume(volume.clamp(0.0, 1.0));
      if (isLocalCry(id)) {
        await player.play(AssetSource('cries/$id.ogg'));
      } else {
        final bytes = await _fetch(id);
        if (bytes == null) return false;
        await player.play(BytesSource(bytes));
      }
      await player.setPlaybackRate(rate);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await Future.wait(_pool.map((p) => p.stop()));
    } catch (_) {}
  }
}
