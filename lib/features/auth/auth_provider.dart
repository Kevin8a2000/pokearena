import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Login local por persona (sin servidor): cada entrenador inicia sesión
/// con usuario + clave y ve solo sus datos (equipo, favoritos, historial).
/// La clave se guarda con hash salteado FNV-1a (sin paquetes nuevos).
/// Nota honesta: protección suficiente para proyecto de clase, no bancaria.
class AuthProvider extends ChangeNotifier {
  static const String _usersKey = 'pokearena_users';
  static const String _sessionKey = 'pokearena_session';

  final SharedPreferences? _injected;
  AuthProvider([this._injected]);

  bool _ready = false;
  String? _currentUser;
  String? _error;

  bool get ready => _ready;
  bool get isLoggedIn => _currentUser != null;
  String? get currentUser => _currentUser;
  String? get error => _error;

  Future<SharedPreferences> _sp() async =>
      _injected ?? await SharedPreferences.getInstance();

  /// Usuario normalizado (minúsculas, sin espacios) para evitar
  /// duplicados tipo "Ash" vs "ash".
  static String normalize(String v) => v.trim().toLowerCase();

  static String? validateUsername(String v) {
    final u = v.trim();
    if (u.length < 3) return 'El usuario necesita mínimo 3 caracteres';
    if (u.length > 16) return 'El usuario admite máximo 16 caracteres';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(u)) {
      return 'Solo letras, números y guion bajo';
    }
    return null;
  }

  static String? validatePassword(String v) {
    if (v.length < 4) return 'La clave necesita mínimo 4 caracteres';
    if (v.length > 64) return 'La clave admite máximo 64 caracteres';
    return null;
  }

  /// Hash FNV-1a 32 bits de "salt:password", en hexadecimal.
  /// Se usa 32 bits (y no 64) para ser compatible con Flutter Web
  /// (JS no representa enteros de 64 bits con exactitud).
  static String hashPassword(String password, String salt) {
    var h = 0x811c9dc5;
    for (final b in utf8.encode('$salt:$password')) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  Future<Map<String, dynamic>> _readUsers() async {
    try {
      final prefs = await _sp();
      final raw = prefs.getString(_usersKey);
      if (raw == null || raw.isEmpty) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeUsers(Map<String, dynamic> users) async {
    final prefs = await _sp();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  Future<bool> _exists(String username) async {
    final users = await _readUsers();
    return users.containsKey(username);
  }

  /// Carga la sesión guardada (auto-login al abrir la app).
  Future<void> load() async {
    try {
      final prefs = await _sp();
      final saved = prefs.getString(_sessionKey);
      if (saved != null && saved.isEmpty == false && await _exists(saved)) {
        _currentUser = saved;
      }
    } catch (_) {}
    _ready = true;
    notifyListeners();
  }

  /// Crea la cuenta e inicia sesión. false + [error] si algo falla.
  Future<bool> register(String username, String password) async {
    _error = validateUsername(username) ?? validatePassword(password);
    if (_error != null) {
      notifyListeners();
      return false;
    }
    final u = normalize(username);
    try {
      final users = await _readUsers();
      if (users.containsKey(u)) {
        _error = 'Ese entrenador ya existe. Inicia sesión.';
        notifyListeners();
        return false;
      }
      final salt = '${DateTime.now().microsecondsSinceEpoch}$u';
      users[u] = {
        'salt': salt,
        'hash': hashPassword(password, salt),
        'created': DateTime.now().toIso8601String(),
      };
      await _writeUsers(users);
      final prefs = await _sp();
      await prefs.setString(_sessionKey, u);
      _currentUser = u;
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'No se pudo crear la cuenta. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
  }

  /// Inicia sesión. false + [error] si el usuario no existe o la clave falla.
  Future<bool> login(String username, String password) async {
    final u = normalize(username);
    if (u.isEmpty || password.isEmpty) {
      _error = 'Escribe tu usuario y tu clave.';
      notifyListeners();
      return false;
    }
    try {
      final users = await _readUsers();
      final entry = users[u];
      if (entry is! Map) {
        _error = 'Ese entrenador no existe. Crea tu cuenta.';
        notifyListeners();
        return false;
      }
      final salt = (entry['salt'] ?? '') as String;
      final hash = (entry['hash'] ?? '') as String;
      if (hashPassword(password, salt) != hash) {
        _error = 'Clave incorrecta. Intenta de nuevo.';
        notifyListeners();
        return false;
      }
      final prefs = await _sp();
      await prefs.setString(_sessionKey, u);
      _currentUser = u;
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'No se pudo iniciar sesión. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
  }

  /// Cierra la sesión (los datos de cada usuario se conservan).
  Future<void> logout() async {
    try {
      final prefs = await _sp();
      await prefs.remove(_sessionKey);
    } catch (_) {}
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
}
