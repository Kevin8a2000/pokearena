import '../../core/models/pokemon.dart';
import '../../core/models/type_relations.dart';

/// Movimiento simple para el simulador (Sprint 3).
class BattleMove {
  final String name;
  final String type;
  final int power;

  const BattleMove({
    required this.name,
    required this.type,
    required this.power,
  });
}

/// Genera 3-4 movimientos según los tipos del Pokémon.
/// Siempre incluye Placaje (Normal 40) + STAB del tipo primario (50) +
/// segundo tipo si es dual (50) + Hiperataque (Normal 70).
List<BattleMove> movesFor(PokemonDetail p) {
  final moves = <BattleMove>[
    const BattleMove(name: 'Placaje', type: 'normal', power: 40),
  ];
  if (p.types.isNotEmpty) {
    moves.add(BattleMove(
      name: 'Ataque ${p.types.first}',
      type: p.types.first,
      power: 50,
    ));
  }
  if (p.types.length > 1) {
    moves.add(BattleMove(
      name: 'Ataque ${p.types[1]}',
      type: p.types[1],
      power: 50,
    ));
  }
  moves.add(const BattleMove(name: 'Hiperataque', type: 'normal', power: 70));
  return moves;
}

/// Efectividad total de un tipo atacante contra los tipos defensores.
/// Multiplica cada defensa (ej. Agua/Fuego ante Eléctrico: 2.0*1.0=2.0).
double effectivenessFor({
  required String attackType,
  required List<String> defenderTypes,
  required Map<String, TypeRelations> relations,
}) {
  var total = 1.0;
  final atk = attackType.toLowerCase();
  for (final def in defenderTypes) {
    final rel = relations[def.toLowerCase()];
    if (rel == null) continue;
    total *= rel.defensiveMultiplierAgainst(atk);
  }
  return total;
}

/// Daño estilo Pokémon (nivel 50 fijo).
/// damage = (((22 * power * Atk/Def) / 50) + 2) * stab * effectiveness * rand
/// - STAB x1.5 si el tipo del movimiento es uno de los tipos del atacante.
/// - [randomFactor] 0.85-1.0 en batalla real; 1.0 en pruebas.
int calculateDamage({
  required PokemonDetail attacker,
  required PokemonDetail defender,
  required BattleMove move,
  required Map<String, TypeRelations> relations,
  double randomFactor = 1.0,
}) {
  final atk = (attacker.stats['attack'] ?? 50).toDouble();
  final def = (defender.stats['defense'] ?? 50).toDouble();
  final safeDef = def <= 0 ? 1.0 : def;

  final base = ((22 * move.power * atk / safeDef) / 50) + 2;
  final stab = attacker.types
          .map((t) => t.toLowerCase())
          .contains(move.type.toLowerCase())
      ? 1.5
      : 1.0;
  final eff = effectivenessFor(
    attackType: move.type,
    defenderTypes: defender.types,
    relations: relations,
  );
  return (base * stab * eff * randomFactor).floor();
}

String effectivenessText(double eff) {
  if (eff == 0.0) return 'No afecta...';
  if (eff >= 2.0) return '¡Súper efectivo!';
  if (eff < 1.0) return 'No es muy efectivo...';
  return '';
}
