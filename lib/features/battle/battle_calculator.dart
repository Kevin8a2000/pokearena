import '../../core/models/pokemon.dart';
import '../../core/models/type_relations.dart';

/// Movimiento simple para el simulador (Sprint 3 + mejoras).
class BattleMove {
  final String name;
  final String type;
  final int power;
  final int maxPp;
  final int accuracy; // 0-100
  final bool isUltimate;

  const BattleMove({
    required this.name,
    required this.type,
    required this.power,
    this.maxPp = 25,
    this.accuracy = 100,
    this.isUltimate = false,
  });
}

/// Nombre vistoso por tipo (en vez del genérico "Ataque x").
String moveNameForType(String type) {
  return switch (type.toLowerCase()) {
    'normal' => 'Golpe Cuerpo',
    'fire' => 'Ascuas',
    'water' => 'Pistola Agua',
    'electric' => 'Impactrueno',
    'grass' => 'Látigo Cepa',
    'ice' => 'Viento Hielo',
    'fighting' => 'Golpe Kárate',
    'poison' => 'Picotazo Veneno',
    'ground' => 'Terremoto',
    'flying' => 'Ataque Ala',
    'psychic' => 'Confusión',
    'bug' => 'Picadura',
    'rock' => 'Avalancha',
    'ghost' => 'Bola Sombra',
    'dragon' => 'Furia Dragón',
    'dark' => 'Mordisco',
    'steel' => 'Garra Metal',
    'fairy' => 'Brillo Mágico',
    _ => 'Ataque',
  };
}

/// Genera 4 movimientos según los tipos del Pokémon, con PP y precisión.
/// Placaje (40/35PP/95) + STAB primario (60/20PP/100) +
/// segundo tipo si es dual (60/20PP/100) + Hiperataque (80/10PP/90).
List<BattleMove> movesFor(PokemonDetail p) {
  final moves = <BattleMove>[
    const BattleMove(name: 'Placaje', type: 'normal', power: 40,
        maxPp: 35, accuracy: 95),
  ];
  if (p.types.isNotEmpty) {
    final t = p.types.first.toLowerCase();
    moves.add(BattleMove(
      name: moveNameForType(t),
      type: t,
      power: 60,
      maxPp: 20,
      accuracy: 100,
    ));
  }
  if (p.types.length > 1) {
    final t = p.types[1].toLowerCase();
    moves.add(BattleMove(
      name: moveNameForType(t),
      type: t,
      power: 60,
      maxPp: 20,
      accuracy: 100,
    ));
  }
  moves.add(const BattleMove(
      name: 'Hiperataque', type: 'normal', power: 80,
      maxPp: 10, accuracy: 90));
  return moves;
}

/// Ultimate: se carga al combatir, poder 120 garantizado.
BattleMove ultimateFor(PokemonDetail p) {
  final t = p.types.isNotEmpty ? p.types.first.toLowerCase() : 'normal';
  return BattleMove(
    name: 'Movimiento Z ${moveNameForType(t)}',
    type: t,
    power: 120,
    maxPp: 1,
    accuracy: 100,
    isUltimate: true,
  );
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
