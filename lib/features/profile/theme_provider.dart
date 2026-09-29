import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestor de tema de la aplicación (Sprint 2, Requisito F4).
/// Permite alternar entre claro, oscuro y sistema, con persistencia inmediata
/// en SharedPreferences para recordar la preferencia del usuario.
class ThemeProvider extends ChangeNotifier {
  static const String _storageKey = 'pokearena_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Modifica el modo de tema, notifica a los oyentes de inmediato y persiste la selección.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, mode.name);
    } catch (_) {
      // Manejo silencioso: el tema funciona en memoria
    }
  }

  /// Carga la preferencia de tema guardada al iniciar la aplicación.
  Future<void> loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved != null) {
        if (saved == ThemeMode.light.name) {
          _themeMode = ThemeMode.light;
        } else if (saved == ThemeMode.dark.name) {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {
      // Valor por defecto es ThemeMode.system
    }
  }
}
