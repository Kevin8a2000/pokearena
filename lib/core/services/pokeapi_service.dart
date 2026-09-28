import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/evolution.dart';
import '../models/pokemon.dart';
import 'local_cache.dart';

/// Único punto de acceso a PokeAPI. Todos los módulos deben usar esta clase
/// (no hacer llamadas http sueltas) para mantener el código ordenado.
class PokeApiService {
  static const _base = 'https://pokeapi.co/api/v2';

  /// Los ids desde 10000 son formas alternativas (megas, regionales...).
  /// Los excluimos para mostrar solo la Pokédex "normal" (1 a 1025).
  static const _maxDexId = 10000;

  final http.Client _client;
  final LocalCache _cache;

  PokeApiService({http.Client? client, LocalCache? cache})
      : _client = client ?? http.Client(),
        _cache = cache ?? LocalCache();

  Future<dynamic> _getJson(String path) async {
    final res = await _client.get(Uri.parse('$_base$path'));
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode} al consultar $path');
    }
    return jsonDecode(res.body);
  }

  /// Los datos de PokeAPI casi nunca cambian, así que primero miramos el
  /// caché y solo vamos a internet si no está. Esto acelera la app y permite
  /// usarla sin conexión lo que ya se visitó.
  Future<dynamic> _cachedOrFetch(
    String key,
    Future<dynamic> Function() fetch,
  ) async {
    final cached = await _cache.read(key);
    if (cached != null) return cached;
    final fresh = await fetch();
    await _cache.write(key, fresh);
    return fresh;
  }

  /// Lista paginada de Pokémon (la dejamos por si otro módulo la necesita).
  Future<List<PokemonSummary>> fetchPokemonPage({
    int offset = 0,
    int limit = 30,
  }) async {
    final data =
        await _getJson('/pokemon?limit=$limit&offset=$offset') as Map<String, dynamic>;
    return (data['results'] as List)
        .map((e) => PokemonSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Todos los Pokémon en una sola petición (~1300 nombres, son livianos).
  /// Así la búsqueda y los filtros funcionan sobre TODA la Pokédex.
  Future<List<PokemonSummary>> fetchAllPokemon() async {
    final results = (await _cachedOrFetch('all-pokemon', () async {
      final data = await _getJson('/pokemon?limit=100000&offset=0')
          as Map<String, dynamic>;
      return data['results'];
    })) as List;
    return results
        .map((e) => PokemonSummary.fromJson(e as Map<String, dynamic>))
        .where((p) => p.id < _maxDexId)
        .toList();
  }

  /// Ids de los Pokémon de un tipo (/type/{name}).
  Future<Set<int>> fetchIdsByType(String type) async {
    final ids = (await _cachedOrFetch('type-$type', () async {
      final data = await _getJson('/type/$type') as Map<String, dynamic>;
      return [
        for (final e in (data['pokemon'] as List))
          idFromUrl(e['pokemon']['url'] as String),
      ];
    })) as List;
    return ids.cast<int>().where((id) => id < _maxDexId).toSet();
  }

  /// Ids de los Pokémon de una generación (/generation/{id}).
  /// Usamos pokemon_species: su id coincide con el del Pokémon base.
  Future<Set<int>> fetchIdsByGeneration(int generation) async {
    final ids = (await _cachedOrFetch('generation-$generation', () async {
      final data =
          await _getJson('/generation/$generation') as Map<String, dynamic>;
      return [
        for (final e in (data['pokemon_species'] as List))
          idFromUrl(e['url'] as String),
      ];
    })) as List;
    return ids.cast<int>().toSet();
  }

  /// Detalle completo (stats, tipos, medidas, habilidades) por id o nombre.
  Future<PokemonDetail> fetchPokemonDetail(Object idOrName) async {
    final json = (await _cachedOrFetch('detail-$idOrName', () async {
      final data = await _getJson('/pokemon/$idOrName') as Map<String, dynamic>;
      // Guardamos la versión compacta, no los ~50 KB de la respuesta original.
      return PokemonDetail.fromJson(data).toCacheJson();
    })) as Map<String, dynamic>;
    return PokemonDetail.fromJson(json);
  }

  /// Cadena evolutiva de un Pokémon: primero la especie (que dice cuál es su
  /// cadena) y luego la cadena completa.
  Future<EvolutionNode> fetchEvolutionChain(int pokemonId) async {
    final json = (await _cachedOrFetch('evolution-$pokemonId', () async {
      final species =
          await _getJson('/pokemon-species/$pokemonId') as Map<String, dynamic>;
      final chainRef = species['evolution_chain'];
      if (chainRef == null) {
        // Algunas especies no tienen cadena: se muestran solas.
        return EvolutionNode(id: pokemonId, name: species['name'] as String)
            .toJson();
      }
      final chainId = idFromUrl(chainRef['url'] as String);
      final chain =
          await _getJson('/evolution-chain/$chainId') as Map<String, dynamic>;
      return EvolutionNode.fromChainJson(chain['chain'] as Map<String, dynamic>)
          .toJson();
    })) as Map<String, dynamic>;
    return EvolutionNode.fromJson(json);
  }

  // Los siguientes métodos los completan los dueños de cada módulo:
  // Future<TypeRelations> fetchTypeRelations(String type)   -> módulo Equipo
}
