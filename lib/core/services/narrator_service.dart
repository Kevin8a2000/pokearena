import 'narrator_backend.dart'
    if (dart.library.js_interop) 'narrator_backend_web.dart' as backend;
import 'narrator_voices.dart';

export 'narrator_voices.dart';

/// Narrador con voz configurable (catálogo curado es/en × ♀/♂,
/// más volumen, ritmo y tono).
/// Todo falla en silencio si no hay voz disponible.
class NarratorService {
  static bool enabled = true;
  static NarratorVoice? voice;
  static double volume = 0.8;
  static double rate = 1.0;
  static double pitch = 1.12;

  static Future<List<NarratorVoice>> loadVoices() async {
    try {
      final voices = await backend.listVoices();
      sortNarratorVoices(voices);
      // Catálogo corto para Ajustes (máx. 12: es/en × ♀/♂ × 3).
      return curateNarratorCatalog(voices);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> speak(String text) =>
      _speakText(text, voice: voice);

  static Future<void> preview() => previewFor(voice);

  /// Prueba con la frase en el idioma de la voz dada.
  static Future<void> previewFor(NarratorVoice? v) =>
      _speakText(previewPhrase(v?.locale ?? ''), voice: v);

  static Future<void> _speakText(String text, {NarratorVoice? voice}) async {
    if (!enabled || text.isEmpty) return;
    try {
      await backend.speak(
        text,
        voice: voice ?? NarratorService.voice,
        volume: volume,
        rate: rate,
        pitch: pitch,
      );
    } catch (_) {}
  }

  /// Prueba [v] sin cambiar la voz guardada.
  static Future<void> previewAs(NarratorVoice v) =>
      previewFor(v);

  static Future<void> stop() async {
    try {
      await backend.stop();
    } catch (_) {}
  }
}
