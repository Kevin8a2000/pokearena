import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'narrator_voices.dart';

/// Backend web: lee y habla con las voces del propio navegador
/// (Web Speech API). Así aparecen TODAS: mujeres, hombres, español,
/// inglés y demás, sin depender del plugin en Chrome.
web.SpeechSynthesis get _synth => web.window.speechSynthesis;

Future<List<NarratorVoice>> listVoices() async {
  // Chrome carga las voces de forma asíncrona: reintenta un momento.
  for (var i = 0; i < 8; i++) {
    final found = [
      for (final v in _synth.getVoices().toDart)
        NarratorVoice(
          name: v.name,
          locale: v.lang,
          gender: voiceGender(v.name),
        ),
    ];
    if (found.isNotEmpty) return found;
    await Future.delayed(const Duration(milliseconds: 400));
  }
  return const [];
}

Future<void> speak(
  String text, {
  NarratorVoice? voice,
  double volume = 1.0,
  double rate = 1.0,
  double pitch = 1.0,
}) async {
  try {
    final u = web.SpeechSynthesisUtterance(text);
    final v = voice;
    if (v != null && v.name.isNotEmpty) {
      for (final candidate in _synth.getVoices().toDart) {
        if (candidate.name == v.name) {
          u.voice = candidate;
          break;
        }
      }
      if (v.locale.isNotEmpty) u.lang = v.locale;
    } else {
      u.lang = 'es-ES';
    }
    u.volume = volume;
    u.rate = rate;
    u.pitch = pitch;
    _synth.cancel();
    _synth.speak(u);
  } catch (_) {}
}

Future<void> stop() async {
  try {
    _synth.cancel();
  } catch (_) {}
}
