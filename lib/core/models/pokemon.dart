/// Datos mínimos para la lista (barato: viene del endpoint /pokemon?limit=..).
class PokemonSummary {
  final int id;
  final String name;

  const PokemonSummary({required this.id, required this.name});

  factory PokemonSummary.fromJson(Map<String, dynamic> json) {
    // La URL viene como https://pokeapi.co/api/v2/pokemon/25/
    final url = json['url'] as String;
    final parts = url.split('/').where((p) => p.isNotEmpty).toList();
    return PokemonSummary(id: int.parse(parts.last), name: json['name'] as String);
  }

  String get imageUrl => officialArtwork(id);
}

/// Datos completos para el detalle (endpoint /pokemon/{id}).
class PokemonDetail {
  final int id;
  final String name;
  final int height; // decímetros
  final int weight; // hectogramos
  final List<String> types;
  final Map<String, int> stats; // hp, attack, defense, special-attack, ...

  const PokemonDetail({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.types,
    required this.stats,
  });

  factory PokemonDetail.fromJson(Map<String, dynamic> json) {
    final types = (json['types'] as List)
        .map((t) => (t['type']['name']) as String)
        .toList();
    final stats = <String, int>{
      for (final s in (json['stats'] as List))
        (s['stat']['name'] as String): s['base_stat'] as int,
    };
    return PokemonDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      height: json['height'] as int,
      weight: json['weight'] as int,
      types: types,
      stats: stats,
    );
  }

  String get imageUrl => officialArtwork(id);
}

String officialArtwork(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
