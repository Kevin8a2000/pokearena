import '../../core/models/pokemon.dart';
import '../../core/models/type_relations.dart';

/// Información detallada de la cobertura de un tipo atacante frente al equipo.
class TypeCoverageInfo {
  final String type;
  final double combinedMultiplier;
  final int weakCount; // Miembros vulnerables (> 1.0)
  final int resistCount; // Miembros resistentes (< 1.0 y > 0.0)
  final int immuneCount; // Miembros inmunes (== 0.0)
  final int neutralCount; // Miembros con daño neutro (== 1.0)
  final Map<int, double> memberMultipliers; // id de Pokémon -> multiplicador

  const TypeCoverageInfo({
    required this.type,
    required this.combinedMultiplier,
    this.weakCount = 0,
    this.resistCount = 0,
    this.immuneCount = 0,
    this.neutralCount = 0,
    this.memberMultipliers = const {},
  });
}

/// Motor de cálculo de cobertura defensiva para el equipo.
/// Evalúa el daño recibido ante cada uno de los 18 tipos elementales estándar.
class TeamCoverageCalculator {
  static const List<String> allPokemonTypes = [
    'normal',
    'fire',
    'water',
    'electric',
    'grass',
    'ice',
    'fighting',
    'poison',
    'ground',
    'flying',
    'psychic',
    'bug',
    'rock',
    'ghost',
    'dragon',
    'dark',
    'steel',
    'fairy',
  ];

  /// Calcula el multiplicador de daño que recibe un Pokémon individual frente a un tipo atacante.
  /// Combina los tipos defensivos del Pokémon (por ejemplo: Fuego/Volador ante Roca es 2.0 * 2.0 = 4.0).
  static double calculatePokemonMultiplier({
    required List<String> types,
    required String attackingType,
    required Map<String, TypeRelations> relations,
  }) {
    if (types.isEmpty) return 1.0;
    double mult = 1.0;
    for (final t in types) {
      final rel = relations[t.toLowerCase()];
      if (rel != null) {
        mult *= rel.defensiveMultiplierAgainst(attackingType);
      }
    }
    return mult;
  }

  /// Calcula los multiplicadores combinados para los 18 tipos elementales.
  /// Siguiendo los requerimientos E4 del proyecto, combina las relaciones de todos los
  /// Pokémon del equipo multiplicando sus multiplicadores individuales (x4, x2, x1, x0.5, x0.25, x0).
  ///
  /// - Si el equipo está vacío, retorna 1.0 (neutro) para todos los tipos.
  /// - Si dos Pokémon son débiles a Agua (x2 c/u), el multiplicador de equipo resulta x4.
  /// - Si uno es débil (x2) y otro resistente (x0.5), el resultado se compensa en x1.
  /// - Si un miembro tiene inmunidad (x0), el producto total para ese tipo resulta x0.
  static Map<String, double> calculateCombinedMultipliers({
    required List<PokemonDetail> team,
    required Map<String, TypeRelations> relations,
  }) {
    final result = <String, double>{};
    for (final attackingType in allPokemonTypes) {
      if (team.isEmpty) {
        result[attackingType] = 1.0;
      } else {
        double combined = 1.0;
        for (final pokemon in team) {
          combined *= calculatePokemonMultiplier(
            types: pokemon.types,
            attackingType: attackingType,
            relations: relations,
          );
        }
        result[attackingType] = combined;
      }
    }
    return result;
  }

  /// Genera un desglose detallado con contadores de miembros vulnerables, resistentes e inmunes
  /// para facilitar la visualización en la UI.
  static Map<String, TypeCoverageInfo> calculateDetailedCoverage({
    required List<PokemonDetail> team,
    required Map<String, TypeRelations> relations,
  }) {
    final result = <String, TypeCoverageInfo>{};
    for (final attackingType in allPokemonTypes) {
      if (team.isEmpty) {
        result[attackingType] = TypeCoverageInfo(
          type: attackingType,
          combinedMultiplier: 1.0,
        );
        continue;
      }

      double combined = 1.0;
      int weak = 0;
      int resist = 0;
      int immune = 0;
      int neutral = 0;
      final memberMap = <int, double>{};

      for (final pokemon in team) {
        final mult = calculatePokemonMultiplier(
          types: pokemon.types,
          attackingType: attackingType,
          relations: relations,
        );
        memberMap[pokemon.id] = mult;
        combined *= mult;

        if (mult == 0.0) {
          immune++;
        } else if (mult > 1.0) {
          weak++;
        } else if (mult < 1.0) {
          resist++;
        } else {
          neutral++;
        }
      }

      result[attackingType] = TypeCoverageInfo(
        type: attackingType,
        combinedMultiplier: combined,
        weakCount: weak,
        resistCount: resist,
        immuneCount: immune,
        neutralCount: neutral,
        memberMultipliers: memberMap,
      );
    }
    return result;
  }
}
