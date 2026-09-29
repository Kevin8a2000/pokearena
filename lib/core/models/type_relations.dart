/// Modelo para representar las relaciones de daño de un tipo elemental.
/// Viene del endpoint /type/{name} de PokeAPI.
/// Contiene multiplicadores defensivos (daño recibido) y ofensivos (daño infligido).
class TypeRelations {
  final String typeName;
  final List<String> doubleDamageFrom;
  final List<String> halfDamageFrom;
  final List<String> noDamageFrom;
  final List<String> doubleDamageTo;
  final List<String> halfDamageTo;
  final List<String> noDamageTo;

  const TypeRelations({
    required this.typeName,
    this.doubleDamageFrom = const [],
    this.halfDamageFrom = const [],
    this.noDamageFrom = const [],
    this.doubleDamageTo = const [],
    this.halfDamageTo = const [],
    this.noDamageTo = const [],
  });

  /// Parsea la respuesta directa de PokeAPI (endpoint /type/{name}).
  factory TypeRelations.fromApiJson(String typeName, Map<String, dynamic> json) {
    final dr = (json['damage_relations'] as Map<String, dynamic>?) ?? json;

    List<String> extractNames(String key) {
      final list = dr[key] as List?;
      if (list == null) return const [];
      return list
          .map((item) {
            if (item is Map<String, dynamic>) {
              return (item['name'] as String?) ?? '';
            }
            return item.toString();
          })
          .where((name) => name.isNotEmpty)
          .toList();
    }

    return TypeRelations(
      typeName: typeName,
      doubleDamageFrom: extractNames('double_damage_from'),
      halfDamageFrom: extractNames('half_damage_from'),
      noDamageFrom: extractNames('no_damage_from'),
      doubleDamageTo: extractNames('double_damage_to'),
      halfDamageTo: extractNames('half_damage_to'),
      noDamageTo: extractNames('no_damage_to'),
    );
  }

  /// Formato compacto guardado en caché local para reducir uso de almacenamiento y tráfico de red.
  Map<String, dynamic> toCacheJson() => {
        'typeName': typeName,
        'double_damage_from': doubleDamageFrom,
        'half_damage_from': halfDamageFrom,
        'no_damage_from': noDamageFrom,
        'double_damage_to': doubleDamageTo,
        'half_damage_to': halfDamageTo,
        'no_damage_to': noDamageTo,
      };

  /// Reconstruye el objeto desde el caché guardado en SharedPreferences.
  factory TypeRelations.fromCacheJson(Map<String, dynamic> json) {
    return TypeRelations(
      typeName: (json['typeName'] as String?) ?? '',
      doubleDamageFrom:
          List<String>.from(json['double_damage_from'] as List? ?? const []),
      halfDamageFrom:
          List<String>.from(json['half_damage_from'] as List? ?? const []),
      noDamageFrom:
          List<String>.from(json['no_damage_from'] as List? ?? const []),
      doubleDamageTo:
          List<String>.from(json['double_damage_to'] as List? ?? const []),
      halfDamageTo:
          List<String>.from(json['half_damage_to'] as List? ?? const []),
      noDamageTo: List<String>.from(json['no_damage_to'] as List? ?? const []),
    );
  }

  /// Retorna el factor multiplicador de daño que este tipo elemental recibe
  /// al ser atacado por un tipo [attackingType].
  /// - 2.0 si es debilidad (recibe doble daño)
  /// - 0.5 si es resistencia (recibe la mitad de daño)
  /// - 0.0 si es inmunidad (no recibe daño)
  /// - 1.0 si es daño neutro
  double defensiveMultiplierAgainst(String attackingType) {
    final lower = attackingType.toLowerCase();
    if (noDamageFrom.contains(lower)) return 0.0;
    if (doubleDamageFrom.contains(lower)) return 2.0;
    if (halfDamageFrom.contains(lower)) return 0.5;
    return 1.0;
  }
}
