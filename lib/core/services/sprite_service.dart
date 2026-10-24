import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../widgets/poke_image.dart'
    show PokeSpriteKind, spriteCandidates;

/// Descarga sprites con tiempo límite y concurrencia acotada.
/// En Chrome las peticiones a los CDN de imágenes a veces se cuelgan
/// para siempre (sin error): con timeout se pasa al siguiente CDN y
/// la UI muestra reintentar en vez de quedarse en blanco.
class SpriteService {
  static const int _maxConcurrent = 8;
  static const int _maxMemory = 150;
  static const Duration _timeout = Duration(seconds: 4);

  static final Map<String, Uint8List> _mem = {};
  static int _active = 0;
  static final List<Completer<void>> _queue = [];

  static Future<T> _pooled<T>(Future<T> Function() fn) async {
    if (_active >= _maxConcurrent) {
      final c = Completer<void>();
      _queue.add(c);
      await c.future;
    }
    _active++;
    try {
      return await fn();
    } finally {
      _active--;
      if (_queue.isNotEmpty) _queue.removeAt(0).complete();
    }
  }

  /// Bytes del sprite o null si ningún CDN respondió a tiempo.
  static Future<Uint8List?> fetch(int id,
      [PokeSpriteKind kind = PokeSpriteKind.artwork]) {
    final key = '${kind.name}_$id';
    final hit = _mem[key];
    if (hit != null) return Future.value(hit);
    return _pooled(() async {
      final hit2 = _mem[key];
      if (hit2 != null) return hit2;
      for (final url in spriteCandidates(id, kind)) {
        try {
          final res = await http
              .get(Uri.parse(url))
              .timeout(_timeout);
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            if (_mem.length >= _maxMemory) {
              _mem.remove(_mem.keys.first);
            }
            _mem[key] = res.bodyBytes;
            return res.bodyBytes;
          }
        } catch (_) {
          // Timeout o fallo: prueba el siguiente CDN.
        }
      }
      return null;
    });
  }

  static void clearMemory() => _mem.clear();
}
