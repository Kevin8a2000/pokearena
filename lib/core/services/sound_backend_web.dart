import 'package:web/web.dart' as web;

/// Backend web: reproduce el WAV generado vía AudioElement.
/// Solo se compila en web (import condicional desde sound_service).
Future<void> playDataUrl(String url, double volume) async {
  try {
    final a = web.HTMLAudioElement()
      ..src = url
      ..volume = volume;
    a.play();
  } catch (_) {}
}
