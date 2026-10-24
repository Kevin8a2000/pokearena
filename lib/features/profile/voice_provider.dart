import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/narrator_service.dart';
import '../../core/services/sound_service.dart';

/// Ajustes de la voz del narrador: solo 2 opciones (♀ Mujer / ♂ Hombre).
/// El proveedor resuelve la voz real del dispositivo (español primero),
/// persiste género y volumen, y fija ritmo/tono a valores neutros de
/// narrador de pelea (ni lentos ni iguales entre géneros).
class VoiceProvider extends ChangeNotifier {
  static const _kEnabled = 'pokearena_voice_enabled';
  static const _kGender = 'pokearena_voice_gender';
  static const _kVolume = 'pokearena_voice_volume';
  // Claves viejas (migración por única vez a género).
  static const _kOldName = 'pokearena_voice_name';
  static const _kOldLocale = 'pokearena_voice_locale';

  bool enabled = true;
  VoiceGender gender = VoiceGender.female;
  NarratorVoice? current;
  double volume = 0.8;

  /// Velocidad neutra (1.0 = ritmo normal), fija para que el narrador siga
  /// el ritmo del combate sin sonar lento/arrastrado. Ya no se guarda por
  /// usuario (antes se podía dejar en un valor muy bajo, ej. 0.60, y sonaba
  /// a traducción automática).
  double rate = 1.0;
  double pitch = 1.12;
  bool loading = false;

  /// Tono fijo por género: en muchos dispositivos (sobre todo Android con
  /// una sola voz de Google instalada) no hay una voz de hombre real, así
  /// que la diferencia entre ♀/♂ se la da el tono — más agudo para Mujer,
  /// más grave para Hombre — para que SIEMPRE se note la diferencia, sin
  /// depender de que el sistema tenga voces separadas.
  static double pitchForGender(VoiceGender g) => switch (g) {
        VoiceGender.male => 0.78,
        VoiceGender.female => 1.12,
        VoiceGender.unknown => 1.0,
      };

  List<NarratorVoice> _baseVoices = [];

  /// Carga ajustes guardados + voces del dispositivo y resuelve la voz.
  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_kEnabled) ?? true;
      volume = prefs.getDouble(_kVolume) ?? 0.8;
      gender = _decodeGender(prefs.getString(_kGender));

      _baseVoices = await NarratorService.loadVoices();
      if (prefs.getString(_kGender) == null) {
        // Migración: género de la voz específica guardada antes.
        final name = prefs.getString(_kOldName) ?? '';
        final locale = prefs.getString(_kOldLocale) ?? '';
        final match = _baseVoices.where(
          (v) => v.name == name && v.locale == locale,
        );
        if (match.isNotEmpty &&
            match.first.gender != VoiceGender.unknown) {
          gender = match.first.gender;
        }
        await prefs.setString(_kGender, gender.name);
      }
      pitch = pitchForGender(gender);
      _resolve();
      _apply();
    } catch (_) {
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static VoiceGender _decodeGender(String? raw) => switch (raw) {
        'male' => VoiceGender.male,
        'female' => VoiceGender.female,
        _ => VoiceGender.female,
      };

  /// Primera voz del género elegido (lista ya ordenada: español primero).
  void _resolve() {
    NarratorVoice? pick(bool Function(NarratorVoice) f) {
      for (final v in _baseVoices) {
        if (f(v)) return v;
      }
      return null;
    }

    current = pick((v) => v.gender == gender) ??
        (_baseVoices.isEmpty ? null : _baseVoices.first);
  }

  void _apply() {
    NarratorService.enabled = enabled && SoundService.enabled;
    NarratorService.voice = current;
    NarratorService.volume = volume;
    NarratorService.rate = rate;
    NarratorService.pitch = pitch;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, enabled);
      await prefs.setString(_kGender, gender.name);
      await prefs.setDouble(_kVolume, volume);
    } catch (_) {}
  }

  /// Se llama cuando cambia el mute global para que la voz lo respete.
  void refreshGlobalMute() {
    _apply();
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    if (!v) await NarratorService.stop();
    _apply();
    await _save();
    notifyListeners();
  }

  /// Elige género (solo hembra/macho) y resuelve la voz real.
  Future<void> setGender(VoiceGender g) async {
    gender =
        g == VoiceGender.male ? VoiceGender.male : VoiceGender.female;
    pitch = pitchForGender(gender);
    _resolve();
    _apply();
    await _save();
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    _apply();
    await _save();
    notifyListeners();
  }

  Future<void> setRate(double v) async {
    rate = v.clamp(0.5, 1.5);
    _apply();
    await _save();
    notifyListeners();
  }

  Future<void> setPitch(double v) async {
    pitch = v.clamp(0.5, 2.0);
    _apply();
    await _save();
    notifyListeners();
  }

  /// Pre-escucha la voz actual.
  Future<void> preview() async {
    _apply();
    await NarratorService.preview();
  }
}
