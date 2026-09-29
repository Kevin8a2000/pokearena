import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/pokemon.dart';
import '../../core/models/type_relations.dart';
import '../../core/services/pokeapi_service.dart';
import 'team_coverage_calculator.dart';

/// Gestor de estado del equipo Pokémon (módulo Equipo, Sprint 2).
/// Mantiene hasta 6 Pokémon, previene duplicados, persiste la selección
/// en SharedPreferences y calcula la cobertura defensiva combinada.
class TeamProvider extends ChangeNotifier {
  static const String _storageKey = 'pokearena_team_ids';
  static const int maxTeamSize = 6;

  final PokeApiService _apiService;
  final List<PokemonDetail> _team = [];
  final Map<String, TypeRelations> _relationsCache = {};

  bool _isLoadingTeam = false;
  bool _isLoadingCoverage = false;
  Map<String, double> _combinedMultipliers = {};
  Map<String, TypeCoverageInfo> _detailedCoverage = {};

  TeamProvider(this._apiService) {
    _initDefaultCoverage();
  }

  List<PokemonDetail> get team => List.unmodifiable(_team);
  int get count => _team.length;
  bool get isFull => _team.length >= maxTeamSize;
  bool get isEmpty => _team.isEmpty;
  bool get isLoadingTeam => _isLoadingTeam;
  bool get isLoadingCoverage => _isLoadingCoverage;
  Map<String, double> get combinedMultipliers => _combinedMultipliers;
  Map<String, TypeCoverageInfo> get detailedCoverage => _detailedCoverage;

  /// Cobertura neutra por defecto (todos en 1.0) antes de calcular o si el equipo está vacío.
  void _initDefaultCoverage() {
    _combinedMultipliers = TeamCoverageCalculator.calculateCombinedMultipliers(
      team: const [],
      relations: const {},
    );
    _detailedCoverage = TeamCoverageCalculator.calculateDetailedCoverage(
      team: const [],
      relations: const {},
    );
  }

  /// Verifica si un Pokémon por su id ya está en el equipo para evitar duplicados.
  bool isInTeam(int pokemonId) => _team.any((p) => p.id == pokemonId);

  /// Agrega un Pokémon al equipo si hay cupo (< 6) y no está duplicado.
  /// Retorna `true` si se agregó exitosamente, o `false` en caso contrario.
  Future<bool> addPokemon(PokemonDetail pokemon) async {
    if (isFull || isInTeam(pokemon.id)) {
      return false;
    }

    _team.add(pokemon);
    notifyListeners();

    await _saveTeamToStorage();
    await _recalculateCoverage();
    return true;
  }

  /// Remueve un Pokémon del equipo por su ID.
  Future<void> removePokemon(int pokemonId) async {
    final beforeCount = _team.length;
    _team.removeWhere((p) => p.id == pokemonId);

    if (_team.length != beforeCount) {
      notifyListeners();
      await _saveTeamToStorage();
      await _recalculateCoverage();
    }
  }

  /// Vacía todo el equipo.
  Future<void> clearTeam() async {
    if (_team.isEmpty) return;
    _team.clear();
    _initDefaultCoverage();
    notifyListeners();

    await _saveTeamToStorage();
  }

  /// Calcula las relaciones de tipo de los integrantes del equipo.
  /// Consulta PokeAPI para cualquier tipo que no esté ya en la memoria caché.
  Future<void> _recalculateCoverage() async {
    if (_team.isEmpty) {
      _initDefaultCoverage();
      notifyListeners();
      return;
    }

    _isLoadingCoverage = true;
    notifyListeners();

    try {
      final uniqueTypes = _team.expand((p) => p.types).toSet();

      // Carga en paralelo las relaciones de daño de los tipos que no tengamos en memoria
      final typesToFetch = uniqueTypes.where((t) => !_relationsCache.containsKey(t.toLowerCase())).toList();
      if (typesToFetch.isNotEmpty) {
        final relationsList = await Future.wait(
          typesToFetch.map((t) => _apiService.fetchTypeRelations(t)),
        );
        for (final rel in relationsList) {
          _relationsCache[rel.typeName.toLowerCase()] = rel;
        }
      }

      _combinedMultipliers = TeamCoverageCalculator.calculateCombinedMultipliers(
        team: _team,
        relations: _relationsCache,
      );
      _detailedCoverage = TeamCoverageCalculator.calculateDetailedCoverage(
        team: _team,
        relations: _relationsCache,
      );
    } catch (_) {
      // Si falla la red, mantenemos el cálculo con lo que haya en caché
    } finally {
      _isLoadingCoverage = false;
      notifyListeners();
    }
  }

  /// Justificación técnica de persistencia (Requisito E6):
  /// Usamos SharedPreferences directamente con la clave 'pokearena_team_ids' en lugar
  /// de LocalCache porque el equipo es un dato persistente de usuario (configuración/estado),
  /// mientras que LocalCache está conceptualmente diseñado para la caché volátil de respuestas HTTP
  /// de la PokeAPI con prefijo 'pokearena_cache_'.
  Future<void> _saveTeamToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _team.map((p) => p.id.toString()).toList();
      await prefs.setStringList(_storageKey, ids);
    } catch (_) {
      // Si el almacenamiento falla, el equipo sigue en memoria sin interrumpir al usuario.
    }
  }

  /// Carga el equipo persistido al iniciar la aplicación.
  Future<void> loadSavedTeam() async {
    _isLoadingTeam = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_storageKey) ?? [];

      if (ids.isNotEmpty) {
        _team.clear();
        for (final idStr in ids.take(maxTeamSize)) {
          final id = int.tryParse(idStr);
          if (id != null) {
            try {
              final detail = await _apiService.fetchPokemonDetail(id);
              if (!isInTeam(detail.id) && !isFull) {
                _team.add(detail);
              }
            } catch (_) {
              // Si falla un Pokémon específico, continúa cargando los demás
            }
          }
        }
      }
    } catch (_) {
      // Continuar con lista vacía si hay error
    } finally {
      _isLoadingTeam = false;
      notifyListeners();
      await _recalculateCoverage();
    }
  }
}
