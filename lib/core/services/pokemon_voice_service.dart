import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

import '../models/pokemon.dart';
import '../theme/type_colors.dart' show typeNameEs;

/// Voz del "Narrador Pokémon LATAM" vía Fish Audio (TTS).
///
/// 1. Consigue tu key gratis en https://fish.audio
/// 2. Pásala con `--dart-define=FISH_AUDIO_API_KEY=tu_key`
///    o pégala en [_hardcodedKey] abajo.
/// Sin key válida el método no hace nada (el bocadillo sigue visible).
class PokemonVoiceService {
  static const String _endpoint = 'https://api.fish.audio/v1/tts';

  /// Reference ID del modelo de voz del narrador.
  static const String referenceId = 'b9fe6cc661d0439593fa38e96908120d';

  static const String _envKey = String.fromEnvironment('FISH_AUDIO_API_KEY');

  /// Pega tu API key aquí si no usas --dart-define.
  static const String _hardcodedKey = '';

  static String get _key =>
      _envKey.isNotEmpty ? _envKey : _hardcodedKey;

  static bool enabled = true;

  /// Pool de reproductores para que frases seguidas no se corten.
  static final List<AudioPlayer> _pool =
      List.generate(4, (_) => AudioPlayer());
  static int _next = 0;

  /// Narra [text] con la voz del narrador. Reproduce desde bytes,
  /// sin guardar archivos. Devuelve true si sonó.
  static Future<bool> speak(String text) async {
    if (!enabled || text.trim().isEmpty || _key.isEmpty) return false;
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'text': text,
              'reference_id': referenceId,
              'format': 'mp3',
              'mp3_bitrate': 128,
              'normalize': true,
              'latency': 'balanced',
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return false;
      final bytes = Uint8List.fromList(res.bodyBytes);
      final player = _pool[_next++ % _pool.length];
      unawaited(player.play(BytesSource(bytes), volume: 1.0));
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

  /// Texto corto en español con los datos del Pokémon, listo para narrar.
  static String narrationFor(PokemonDetail d) {
    final name = prettyName(d.name);
    final types = d.types.map(typeNameEs).join(' y ');
    final height = (d.height / 10).toString();
    final weight = (d.weight / 10).toString();
    final abilities =
        d.abilities.take(2).map((a) => prettyName(a.name)).join(' y ');
    final buffer = StringBuffer()
      ..write('¡$name! Pokémon de tipo $types. ')
      ..write('Mide $height metros y pesa $weight kilos. ');
    if (abilities.isNotEmpty) {
      buffer.write('Sus habilidades son $abilities. ');
    }
    buffer.write('¡Atrápalo ya!');
    return buffer.toString();
  }
}
