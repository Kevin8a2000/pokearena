import 'package:flutter/foundation.dart';

import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';

/// Estado del módulo Pokédex: lista con paginación (scroll infinito).
class PokedexProvider extends ChangeNotifier {
  final PokeApiService _api;
  PokedexProvider(this._api);

  static const _pageSize = 30;

  final List<PokemonSummary> items = [];
  bool loading = false;
  bool hasMore = true;
  String? error;

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _api.fetchPokemonPage(
        offset: items.length,
        limit: _pageSize,
      );
      items.addAll(page);
      if (page.length < _pageSize) hasMore = false;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
