import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';

/// Estado del módulo Pokédex: lista completa + búsqueda + filtros.
///
/// Decisión de diseño: cargamos la lista completa una sola vez (solo nombres
/// e ids, es liviana) y filtramos en memoria. Así la búsqueda y los filtros
/// funcionan sobre TODA la Pokédex y se pueden combinar. Las imágenes se
/// cargan solo al hacer scroll (GridView.builder construye lo visible).
class PokedexProvider extends ChangeNotifier {
  final PokeApiService _api;
  PokedexProvider(this._api);

  List<PokemonSummary> _all = [];
  bool loading = false;
  String? error;

  String query = '';
  String? selectedType;
  int? selectedGeneration;
  String? filterError;

  Set<int>? _typeIds;
  Set<int>? _generationIds;
  Timer? _debounce;
  int _pendingFilters = 0;

  bool get hasData => _all.isNotEmpty;
  bool get filtering => _pendingFilters > 0;
  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      selectedType != null ||
      selectedGeneration != null;

  /// Lista ya filtrada. Se recalcula cada vez que cambia algo.
  List<PokemonSummary> get visible {
    final q = query.trim().toLowerCase().replaceAll(' ', '-');
    final asNumber = int.tryParse(q.replaceFirst('#', ''));
    return _all.where((p) {
      if (_typeIds != null && !_typeIds!.contains(p.id)) return false;
      if (_generationIds != null && !_generationIds!.contains(p.id)) {
        return false;
      }
      if (q.isEmpty) return true;
      if (asNumber != null) return p.id == asNumber;
      return p.name.contains(q);
    }).toList();
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      _all = await _api.fetchAllPokemon();
    } catch (_) {
      error = 'No se pudo cargar la Pokédex. Revisa tu conexión.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Se llama en cada tecla; espera 400 ms sin escribir antes de filtrar
  /// para no recalcular la lista con cada letra (debounce).
  void onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => applyQuery(value));
  }

  void applyQuery(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> selectType(String? type) async {
    selectedType = type;
    filterError = null;
    if (type == null) {
      _typeIds = null;
      notifyListeners();
      return;
    }
    _pendingFilters++;
    notifyListeners();
    try {
      final ids = await _api.fetchIdsByType(type);
      // Si el usuario cambió de tipo mientras cargaba, ignoramos esta respuesta.
      if (selectedType == type) _typeIds = ids;
    } catch (_) {
      if (selectedType == type) {
        selectedType = null;
        _typeIds = null;
        filterError = 'No se pudo cargar el filtro de tipo';
      }
    } finally {
      _pendingFilters--;
      notifyListeners();
    }
  }

  Future<void> selectGeneration(int? generation) async {
    selectedGeneration = generation;
    filterError = null;
    if (generation == null) {
      _generationIds = null;
      notifyListeners();
      return;
    }
    _pendingFilters++;
    notifyListeners();
    try {
      final ids = await _api.fetchIdsByGeneration(generation);
      if (selectedGeneration == generation) _generationIds = ids;
    } catch (_) {
      if (selectedGeneration == generation) {
        selectedGeneration = null;
        _generationIds = null;
        filterError = 'No se pudo cargar el filtro de generación';
      }
    } finally {
      _pendingFilters--;
      notifyListeners();
    }
  }

  void clearFilters() {
    _debounce?.cancel();
    query = '';
    selectedType = null;
    selectedGeneration = null;
    _typeIds = null;
    _generationIds = null;
    filterError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
