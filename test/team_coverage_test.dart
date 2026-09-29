import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/models/type_relations.dart';
import 'package:pokearena/features/team/team_coverage_calculator.dart';

void main() {
  // Mock de relaciones de daño para pruebas sin conexión a internet
  final Map<String, TypeRelations> mockRelations = {
    'fire': const TypeRelations(
      typeName: 'fire',
      doubleDamageFrom: ['water', 'ground', 'rock'],
      halfDamageFrom: ['fire', 'grass', 'ice', 'bug', 'steel', 'fairy'],
      noDamageFrom: [],
    ),
    'water': const TypeRelations(
      typeName: 'water',
      doubleDamageFrom: ['electric', 'grass'],
      halfDamageFrom: ['fire', 'water', 'ice', 'steel'],
      noDamageFrom: [],
    ),
    'grass': const TypeRelations(
      typeName: 'grass',
      doubleDamageFrom: ['fire', 'ice', 'poison', 'flying', 'bug'],
      halfDamageFrom: ['water', 'electric', 'grass', 'ground'],
      noDamageFrom: [],
    ),
    'ground': const TypeRelations(
      typeName: 'ground',
      doubleDamageFrom: ['water', 'grass', 'ice'],
      halfDamageFrom: ['poison', 'rock'],
      noDamageFrom: ['electric'],
    ),
    'flying': const TypeRelations(
      typeName: 'flying',
      doubleDamageFrom: ['electric', 'ice', 'rock'],
      halfDamageFrom: ['grass', 'fighting', 'bug'],
      noDamageFrom: ['ground'],
    ),
    'steel': const TypeRelations(
      typeName: 'steel',
      doubleDamageFrom: ['fire', 'fighting', 'ground'],
      halfDamageFrom: ['normal', 'flying', 'rock', 'bug', 'steel', 'grass', 'psychic', 'ice', 'dragon', 'fairy'],
      noDamageFrom: ['poison'],
    ),
    'fairy': const TypeRelations(
      typeName: 'fairy',
      doubleDamageFrom: ['poison', 'steel'],
      halfDamageFrom: ['fighting', 'bug', 'dark'],
      noDamageFrom: ['dragon'],
    ),
  };

  PokemonDetail createPokemon({
    required int id,
    required String name,
    required List<String> types,
  }) {
    return PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: types,
      stats: const {'hp': 50, 'attack': 50, 'defense': 50},
    );
  }

  group('TeamCoverageCalculator - Pruebas Unitarias (Sprint 2 / Requisito E7)', () {
    test('Caso 1: Equipo vacío retorna multiplicador neutro (1.0) para todos los tipos', () {
      final coverage = TeamCoverageCalculator.calculateCombinedMultipliers(
        team: const [],
        relations: mockRelations,
      );

      expect(coverage.length, 18);
      for (final type in TeamCoverageCalculator.allPokemonTypes) {
        expect(coverage[type], 1.0, reason: 'El tipo $type debe ser 1.0 en equipo vacío');
      }
    });

    test('Caso 2: Pokémon de tipo dual combina sus debilidades y resistencias (Swampert: Agua/Tierra)', () {
      final swampert = createPokemon(id: 260, name: 'swampert', types: ['water', 'ground']);

      // Planta es debilidad x2 para Agua y x2 para Tierra -> 2.0 * 2.0 = 4.0 (x4 debilidad)
      final grassMult = TeamCoverageCalculator.calculatePokemonMultiplier(
        types: swampert.types,
        attackingType: 'grass',
        relations: mockRelations,
      );
      expect(grassMult, 4.0);

      // Eléctrico es debilidad x2 para Agua, pero inmunidad x0 para Tierra -> 2.0 * 0.0 = 0.0 (inmunidad)
      final electricMult = TeamCoverageCalculator.calculatePokemonMultiplier(
        types: swampert.types,
        attackingType: 'electric',
        relations: mockRelations,
      );
      expect(electricMult, 0.0);

      // Fuego es resistido por Agua (x0.5) y neutro para Tierra (x1.0) -> 0.5 * 1.0 = 0.5
      final fireMult = TeamCoverageCalculator.calculatePokemonMultiplier(
        types: swampert.types,
        attackingType: 'fire',
        relations: mockRelations,
      );
      expect(fireMult, 0.5);
    });

    test('Caso 3: Equipo con debilidad compartida x4 (dos tipo Fuego atacados por Agua: 2.0 * 2.0 = 4.0)', () {
      final charmander = createPokemon(id: 4, name: 'charmander', types: ['fire']);
      final cyndaquil = createPokemon(id: 155, name: 'cyndaquil', types: ['fire']);
      final team = [charmander, cyndaquil];

      final coverage = TeamCoverageCalculator.calculateCombinedMultipliers(
        team: team,
        relations: mockRelations,
      );

      // Ambos son débiles a Agua (x2 cada uno): 2 * 2 = 4
      expect(coverage['water'], 4.0);
      // Ambos son débiles a Tierra (x2 cada uno): 2 * 2 = 4
      expect(coverage['ground'], 4.0);
    });

    test('Caso 4: Equipo sin debilidades frente a un tipo (debilidad compensada con resistencia: 2.0 * 0.5 = 1.0)', () {
      // Bulbasaur (Planta, débil a Fuego x2) y Squirtle (Agua, resiste Fuego x0.5)
      final bulbasaur = createPokemon(id: 1, name: 'bulbasaur', types: ['grass']);
      final squirtle = createPokemon(id: 7, name: 'squirtle', types: ['water']);
      final team = [bulbasaur, squirtle];

      final coverage = TeamCoverageCalculator.calculateCombinedMultipliers(
        team: team,
        relations: mockRelations,
      );

      // Frente a Fuego: 2.0 (Bulbasaur) * 0.5 (Squirtle) = 1.0 (neutro, sin debilidad combinada)
      expect(coverage['fire'], 1.0);
    });

    test('Caso 5: Inmunidad en el equipo anula el daño recibido (Volador inmune a Tierra: factor x0)', () {
      final pidgeot = createPokemon(id: 18, name: 'pidgeot', types: ['flying']);
      final charmander = createPokemon(id: 4, name: 'charmander', types: ['fire']);
      final team = [pidgeot, charmander];

      final coverage = TeamCoverageCalculator.calculateCombinedMultipliers(
        team: team,
        relations: mockRelations,
      );

      // Pidgeot tiene inmunidad x0 ante Tierra, por lo que el producto combinado es 0.0
      expect(coverage['ground'], 0.0);
    });

    test('Caso 6: Desglose detallado calcula contadores correctos (débiles, resistentes, inmunes)', () {
      final swampert = createPokemon(id: 260, name: 'swampert', types: ['water', 'ground']);
      final charmander = createPokemon(id: 4, name: 'charmander', types: ['fire']);
      final team = [swampert, charmander];

      final detailed = TeamCoverageCalculator.calculateDetailedCoverage(
        team: team,
        relations: mockRelations,
      );

      final grassCoverage = detailed['grass']!;
      // Swampert es débil x4 a Planta, Charmander resiste x0.5 a Planta
      expect(grassCoverage.weakCount, 1);
      expect(grassCoverage.resistCount, 1);
      expect(grassCoverage.combinedMultiplier, 4.0 * 0.5); // 2.0
    });
  });
}
