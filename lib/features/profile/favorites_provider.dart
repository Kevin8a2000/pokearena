import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';

/// Gestor de estado de Pokémon favoritos (Sprint 2, Requisitos F1, F2, F3).
/// Almacena los IDs favoritos, persiste la lista en SharedPreferences
/// y resuelve los resúmenes de Pokémon para mostrarlos en el Perfil.
class FavoritesProvider extends ChangeNotifier {
  static const String _storageKey = 'pokearena_favorite_ids';

  final PokeApiService _apiService;
  final Set<int> _favoriteIds = {};
  List<PokemonSummary> _favorites = [];
  bool _isLoading = false;

  FavoritesProvider(this._apiService);

  Set<int> get favoriteIds => Set.unmodifiable(_favoriteIds);
  List<PokemonSummary> get favorites => List.unmodifiable(_favorites);
  int get count => _favoriteIds.length;
  bool get isEmpty => _favoriteIds.isEmpty;
  bool get isLoading => _isLoading;

  /// Indica si un Pokémon específico está en la lista de favoritos.
  bool isFavorite(int pokemonId) => _favoriteIds.contains(pokemonId);

  /// Alterna el estado de favorito (agrega o remueve) y persiste el cambio.
  Future<void> toggleFavorite({required int id, required String name}) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      _favorites.removeWhere((p) => p.id == id);
    } else {
      _favoriteIds.add(id);
      _favorites.insert(0, PokemonSummary(id: id, name: name));
    }

    notifyListeners();
    await _saveToStorage();
  }

  /// Remueve un favorito directamente por su ID.
  Future<void> removeFavorite(int id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      _favorites.removeWhere((p) => p.id == id);
      notifyListeners();
      await _saveToStorage();
    }
  }

  /// Guarda los IDs de favoritos en SharedPreferences como lista de cadenas.
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringIds = _favoriteIds.map((id) => id.toString()).toList();
      await prefs.setStringList(_storageKey, stringIds);
    } catch (_) {
      // Manejo silencioso: la app continúa en memoria si falla el almacenamiento
    }
  }

  /// Carga los favoritos guardados desde SharedPreferences y resuelve sus datos.
  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final stringIds = prefs.getStringList(_storageKey) ?? [];

      _favoriteIds.clear();
      for (final s in stringIds) {
        final id = int.tryParse(s);
        if (id != null) _favoriteIds.add(id);
      }

      if (_favoriteIds.isNotEmpty) {
        try {
          // Usamos la lista completa ya cacheada por PokeApiService para resolver nombres
          final allPokemon = await _apiService.fetchAllPokemon();
          final map = {for (final p in allPokemon) p.id: p};

          _favorites = _favoriteIds.map((id) {
            return map[id] ?? PokemonSummary(id: id, name: 'pokemon-$id');
          }).toList();
        } catch (_) {
          // Si no hay red, creamos resúmenes básicos con el id (la imagen oficial funcionará igual)
          _favorites = _favoriteIds
              .map((id) => PokemonSummary(id: id, name: 'Pokémon #$id'))
              .toList();
        }
      } else {
        _favorites = [];
      }
    } catch (_) {
      // Continuar con lista vacía si hay error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
