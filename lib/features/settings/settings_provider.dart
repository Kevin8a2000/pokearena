import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/sound_service.dart';

/// Fondo predeterminado: azul marino con Pokébolas dibujado por código
/// (no es un archivo; ver `PokeballBackground`).
const kNavyWallpaper = 'navy-pokeballs';

/// Fondos elegibles para la Pokédex (el primero es el predeterminado).
const wallpapers = [
  kNavyWallpaper,
  'assets/images/background_collage.png',
  'assets/images/wallpaper_3.jpg',
  'assets/images/wallpaper_4.jpg',
  'assets/images/wallpaper_5.jpg',
];

/// Ajustes por usuario: fondo, sonido maestro y avatar.
/// El resto (gritos, voz) vive en sus providers y se puentea
/// desde la pantalla de ajustes.
class SettingsProvider extends ChangeNotifier {
  static const _key = 'pokearena_settings';

  String _wallpaper = wallpapers.first;
  bool _soundOn = true;
  int? _avatarId;
  bool _trainerFemale = false;
  bool _battleTutorialSeen = false;
  bool _duelTutorialSeen = false;
  bool _teamTutorialSeen = false;
  bool _actionsTutorialSeen = false;

  String? _owner;
  String get _prefsKey =>
      _owner == null ? _key : '${_key}_u_$_owner';

  String get wallpaper => _wallpaper;
  bool get soundOn => _soundOn;
  int? get avatarId => _avatarId;

  /// Entrenador que sale a lanzar la Poké Ball en la batalla Normal:
  /// false = Red (chico), true = Leaf (chica).
  bool get trainerFemale => _trainerFemale;

  /// ¿Ya vio el tutorial de batalla? (sale solo la primera vez)
  bool get battleTutorialSeen => _battleTutorialSeen;

  /// ¿Ya vio cómo se juega el Duelo en tiempo real?
  bool get duelTutorialSeen => _duelTutorialSeen;

  /// ¿Ya vio la ayuda de la pantalla Mi Equipo (huecos y cobertura)?
  bool get teamTutorialSeen => _teamTutorialSeen;

  /// ¿Ya vio el recorrido con foco de luz sobre los 4 botones reales de
  /// combate (LUCHAR/MOCHILA/POKÉMON/HUIR)?
  bool get actionsTutorialSeen => _actionsTutorialSeen;

  Future<void> switchUser(String? owner) async {
    _owner = owner;
    await load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final w = prefs.getString('$_prefsKey-wallpaper');
      if (w != null && wallpapers.contains(w)) _wallpaper = w;
      _soundOn = prefs.getBool('$_prefsKey-sound') ?? true;
      _avatarId = prefs.getInt('$_prefsKey-avatar');
      _trainerFemale = prefs.getBool('$_prefsKey-trainer-female') ?? false;
      _battleTutorialSeen = prefs.getBool('$_prefsKey-battle-tutorial') ?? false;
      _duelTutorialSeen = prefs.getBool('$_prefsKey-duel-tutorial') ?? false;
      _teamTutorialSeen = prefs.getBool('$_prefsKey-team-tutorial') ?? false;
      _actionsTutorialSeen = prefs.getBool('$_prefsKey-actions-tutorial') ?? false;
    } catch (_) {}
    SoundService.toggle(_soundOn);
    notifyListeners();
  }

  Future<void> setWallpaper(String path) async {
    if (!wallpapers.contains(path)) return;
    _wallpaper = path;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsKey-wallpaper', path);
    } catch (_) {}
  }

  Future<void> setSound(bool v) async {
    _soundOn = v;
    SoundService.toggle(v);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefsKey-sound', v);
    } catch (_) {}
  }

  Future<void> markBattleTutorialSeen() async {
    if (_battleTutorialSeen) return;
    _battleTutorialSeen = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefsKey-battle-tutorial', true);
    } catch (_) {}
  }

  Future<void> markDuelTutorialSeen() async {
    if (_duelTutorialSeen) return;
    _duelTutorialSeen = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefsKey-duel-tutorial', true);
    } catch (_) {}
  }

  Future<void> markTeamTutorialSeen() async {
    if (_teamTutorialSeen) return;
    _teamTutorialSeen = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefsKey-team-tutorial', true);
    } catch (_) {}
  }

  Future<void> markActionsTutorialSeen() async {
    if (_actionsTutorialSeen) return;
    _actionsTutorialSeen = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefsKey-actions-tutorial', true);
    } catch (_) {}
  }

  Future<void> setTrainerFemale(bool v) async {
    _trainerFemale = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefsKey-trainer-female', v);
    } catch (_) {}
  }

  Future<void> setAvatar(int? id) async {
    _avatarId = id;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove('$_prefsKey-avatar');
      } else {
        await prefs.setInt('$_prefsKey-avatar', id);
      }
    } catch (_) {}
  }
}
