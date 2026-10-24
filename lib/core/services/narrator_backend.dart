import 'package:flutter_tts/flutter_tts.dart';

import 'narrator_voices.dart';

/// Backend por defecto (móvil/escritorio/VM): usa flutter_tts.
/// En tests sin plugin, todo cae en silencio.
final FlutterTts _tts = FlutterTts();

Future<List<NarratorVoice>> listVoices() async {
  try {
    final raw = await _tts.getVoices;
    return sortVoices([
      for (final v in raw as List)
        {
          'name': '${(v as Map)['name'] ?? ''}',
          'locale': '${v['locale'] ?? ''}',
        },
    ]);
  } catch (_) {
    return const [];
  }
}

Future<void> speak(
  String text, {
  NarratorVoice? voice,
  double volume = 1.0,
  double rate = 1.0,
  double pitch = 1.0,
}) async {
  try {
    if (voice != null && voice.name.isNotEmpty) {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    } else {
      await _tts.setLanguage('es-ES');
    }
    await _tts.setVolume(volume);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.stop();
    await _tts.speak(text);
  } catch (_) {}
}

Future<void> stop() async {
  try {
    await _tts.stop();
  } catch (_) {}
}
