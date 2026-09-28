import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pokemon.dart';

/// Único punto de acceso a PokeAPI. Todos los módulos deben usar esta clase
/// (no hacer llamadas http sueltas) para mantener el código ordenado.
class PokeApiService {
  static const _base = 'https://pokeapi.co/api/v2';
  final http.Client _client;

  PokeApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _getJson(String path) async {
    final res = await _client.get(Uri.parse('$_base$path'));
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode} al consultar $path');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Lista paginada de Pokémon.
  Future<List<PokemonSummary>> fetchPokemonPage({
    int offset = 0,
    int limit = 30,
  }) async {
    final data = await _getJson('/pokemon?limit=$limit&offset=$offset');
    return (data['results'] as List)
        .map((e) => PokemonSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Detalle completo (stats, tipos, medidas) por id o nombre.
  Future<PokemonDetail> fetchPokemonDetail(Object idOrName) async {
    final data = await _getJson('/pokemon/$idOrName');
    return PokemonDetail.fromJson(data);
  }

  // Los siguientes métodos los completan los dueños de cada módulo:
  // Future<TypeRelations> fetchTypeRelations(String type)   -> módulo Equipo
  // Future<EvolutionChain> fetchEvolutionChain(int id)      -> módulo Pokédex
}
