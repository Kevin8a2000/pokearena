import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/score_entry.dart';

/// Servicio para registrar y consultar el historial de puntajes de minijuegos (Sprint 2, Requisito F5).
/// Diseñado para ser consumido por el módulo Quiz en el Sprint 3.
class ScoreHistoryService {
  static const String _storageKey = 'pokearena_score_history';

  final SharedPreferences? _prefs;

  ScoreHistoryService([this._prefs]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Guarda una nueva partida con su puntaje y fecha.
  Future<void> saveScore({
    required String gameName,
    required int score,
    DateTime? date,
  }) async {
    try {
      final prefs = await _getPrefs();
      final currentList = await getHistory();

      final newEntry = ScoreEntry(
        gameName: gameName,
        score: score,
        date: date ?? DateTime.now(),
      );

      // Agrega al inicio para mantener orden cronológico descendente (el más reciente primero)
      currentList.insert(0, newEntry);

      final encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {
      // Manejo silencioso: la app continúa si el almacenamiento falla
    }
  }

  /// Retorna la lista completa de puntajes, opcionalmente filtrada por el nombre del juego.
  Future<List<ScoreEntry>> getHistory({String? gameName}) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List;
      final entries = decoded
          .map((item) => ScoreEntry.fromJson(item as Map<String, dynamic>))
          .toList();

      if (gameName != null && gameName.isNotEmpty) {
        return entries
            .where((e) => e.gameName.toLowerCase() == gameName.toLowerCase())
            .toList();
      }

      return entries;
    } catch (_) {
      return [];
    }
  }

  /// Borra el historial guardado.
  Future<void> clearHistory() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Sin bloqueo ante fallo
    }
  }
}
