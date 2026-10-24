import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallet_rules.dart';

/// Monedero general: monedas ganadas en batalla y desbloqueos de avatares.
/// El candado solo bloquea agregar al equipo; ver la carta, stats y grito
/// siempre está permitido. Persiste por usuario.
class WalletProvider extends ChangeNotifier {
  static const String _storageKey = 'pokearena_wallet';
  static const String _legacyKey = 'pokearena_horde_save';

  String? _owner;
  String get _key =>
      _owner == null ? _storageKey : '${_storageKey}_u_$_owner';
  String get _legacy =>
      _owner == null ? _legacyKey : '${_legacyKey}_u_$_owner';

  int coins = 0;
  final Set<int> unlocked = {for (var i = 1; i <= 30; i++) i};

  bool isUnlocked(int id) => unlocked.contains(id);
  int priceOf(int id) => WalletRules.priceFor(id);

  /// Cambio de usuario (login): recarga el guardado de ese dueño.
  Future<void> switchUser(String? user) async {
    _owner = user;
    coins = 0;
    unlocked
      ..clear()
      ..addAll([for (var i = 1; i <= 30; i++) i]);
    await _load();
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        coins = (data['coins'] as num?)?.toInt() ?? 0;
        final un = data['unlocked'] as List? ?? [];
        for (final e in un) {
          final id = (e as num?)?.toInt();
          if (id != null) unlocked.add(id);
        }
      } else {
        // Migración por única vez del guardado de la Horda (monedas y
        // desbloqueos ya ganados se conservan).
        final legacy = prefs.getString(_legacy);
        if (legacy != null && legacy.isNotEmpty) {
          final data = jsonDecode(legacy) as Map<String, dynamic>;
          coins = (data['coins'] as num?)?.toInt() ?? 0;
          final un = data['unlocked'] as List? ?? [];
          for (final e in un) {
            final id = (e as num?)?.toInt();
            if (id != null) unlocked.add(id);
          }
          await _save();
        }
        await prefs.remove(_legacy);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({'coins': coins, 'unlocked': unlocked.toList()}),
      );
    } catch (_) {}
  }

  /// Suma monedas ganadas en batalla.
  Future<void> addCoins(int n) async {
    if (n <= 0) return;
    coins += n;
    await _save();
    notifyListeners();
  }

  /// Canjea un avatar bloqueado. Retorna true si quedó desbloqueado.
  Future<bool> unlock(int id) async {
    if (isUnlocked(id)) return true;
    final price = priceOf(id);
    if (coins < price) return false;
    coins -= price;
    unlocked.add(id);
    await _save();
    notifyListeners();
    return true;
  }
}
