/// Extrae el id numérico de una URL de PokeAPI (…/pokemon/25/ → 25).
int idFromUrl(String url) {
  final parts = url.split('/').where((p) => p.isNotEmpty).toList();
  return int.parse(parts.last);
}

/// Datos mínimos para la lista (vienen del endpoint /pokemon?limit=..).
class PokemonSummary {
  final int id;
  final String name;

  const PokemonSummary({required this.id, required this.name});

  factory PokemonSummary.fromJson(Map<String, dynamic> json) {
    return PokemonSummary(
      id: idFromUrl(json['url'] as String),
      name: json['name'] as String,
    );
  }

  String get imageUrl => officialArtwork(id);
}

/// Habilidad de un Pokémon; la "oculta" solo se obtiene en casos especiales.
class PokemonAbility {
  final String name;
  final bool isHidden;

  const PokemonAbility({required this.name, required this.isHidden});
}

/// Datos completos para el detalle (endpoint /pokemon/{id}).
class PokemonDetail {
  final int id;
  final String name;
  final int height; // decímetros
  final int weight; // hectogramos
  final List<String> types;
  final Map<String, int> stats; // hp, attack, defense, special-attack, ...
  final List<PokemonAbility> abilities;

  const PokemonDetail({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.types,
    required this.stats,
    this.abilities = const [],
  });

  /// Sirve tanto para la respuesta real de la API como para lo guardado en
  /// caché (toCacheJson genera la misma forma, pero solo con lo que usamos).
  factory PokemonDetail.fromJson(Map<String, dynamic> json) {
    final types = (json['types'] as List)
        .map((t) => (t['type']['name']) as String)
        .toList();
    final stats = <String, int>{
      for (final s in (json['stats'] as List))
        (s['stat']['name'] as String): s['base_stat'] as int,
    };
    final abilities = [
      for (final a in (json['abilities'] as List? ?? const []))
        PokemonAbility(
          name: a['ability']['name'] as String,
          isHidden: (a['is_hidden'] as bool?) ?? false,
        ),
    ];
    return PokemonDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      height: json['height'] as int,
      weight: json['weight'] as int,
      types: types,
      stats: stats,
      abilities: abilities,
    );
  }

  /// Versión compacta con la misma forma que la API. La respuesta original
  /// pesa ~50 KB; así guardamos ~0.5 KB por Pokémon en el caché.
  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'height': height,
        'weight': weight,
        'types': [
          for (final t in types) {'type': {'name': t}},
        ],
        'stats': [
          for (final e in stats.entries)
            {'stat': {'name': e.key}, 'base_stat': e.value},
        ],
        'abilities': [
          for (final a in abilities)
            {'ability': {'name': a.name}, 'is_hidden': a.isHidden},
        ],
      };

  String get imageUrl => officialArtwork(id);
}

String officialArtwork(int id) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "mr-mime" → "Mr Mime", "solar-power" → "Solar Power".
String prettyName(String s) => s.split('-').map(capitalize).join(' ');
