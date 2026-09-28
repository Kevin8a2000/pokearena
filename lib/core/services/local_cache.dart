import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Caché en disco (shared_preferences). Guarda JSON por clave.
/// Si algo falla al leer o escribir, la app sigue funcionando sin caché.
class LocalCache {
  static const _prefix = 'pokearena_cache_';

  Future<dynamic> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(value));
    } catch (_) {
      // Sin caché la app igual funciona; no interrumpimos al usuario.
    }
  }
}
