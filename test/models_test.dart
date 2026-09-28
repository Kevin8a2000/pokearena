import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/evolution.dart';
import 'package:pokearena/core/models/pokemon.dart';

void main() {
  group('idFromUrl', () {
    test('extrae el id con y sin "/" final', () {
      expect(idFromUrl('https://pokeapi.co/api/v2/pokemon/25/'), 25);
      expect(idFromUrl('https://pokeapi.co/api/v2/pokemon-species/133'), 133);
    });
  });

  group('PokemonSummary', () {
    test('lee nombre e id desde la lista de la API', () {
      final p = PokemonSummary.fromJson({
        'name': 'pikachu',
        'url': 'https://pokeapi.co/api/v2/pokemon/25/',
      });
      expect(p.id, 25);
      expect(p.name, 'pikachu');
      expect(p.imageUrl, contains('/25.png'));
    });
  });

  group('PokemonDetail', () {
    final json = {
      'id': 1,
      'name': 'bulbasaur',
      'height': 7,
      'weight': 69,
      'types': [
        {'slot': 1, 'type': {'name': 'grass', 'url': 'x'}},
        {'slot': 2, 'type': {'name': 'poison', 'url': 'x'}},
      ],
      'stats': [
        {'base_stat': 45, 'effort': 0, 'stat': {'name': 'hp', 'url': 'x'}},
        {'base_stat': 49, 'effort': 0, 'stat': {'name': 'attack', 'url': 'x'}},
      ],
      'abilities': [
        {'is_hidden': false, 'slot': 1, 'ability': {'name': 'overgrow', 'url': 'x'}},
        {'is_hidden': true, 'slot': 3, 'ability': {'name': 'chlorophyll', 'url': 'x'}},
      ],
    };

    test('parsea tipos, stats y habilidades', () {
      final d = PokemonDetail.fromJson(json);
      expect(d.types, ['grass', 'poison']);
      expect(d.stats['hp'], 45);
      expect(d.abilities.length, 2);
      expect(d.abilities[1].isHidden, isTrue);
    });

    test('el caché compacto se puede volver a leer sin perder datos', () {
      final original = PokemonDetail.fromJson(json);
      final again = PokemonDetail.fromJson(original.toCacheJson());
      expect(again.id, original.id);
      expect(again.types, original.types);
      expect(again.stats, original.stats);
      expect(again.abilities.map((a) => a.name),
          original.abilities.map((a) => a.name));
    });
  });

  group('EvolutionNode', () {
    // Eevee evoluciona en varios Pokémon (cadena ramificada).
    final chain = {
      'species': {'name': 'eevee', 'url': 'https://pokeapi.co/api/v2/pokemon-species/133/'},
      'evolves_to': [
        {
          'species': {'name': 'vaporeon', 'url': 'https://pokeapi.co/api/v2/pokemon-species/134/'},
          'evolves_to': [],
        },
        {
          'species': {'name': 'jolteon', 'url': 'https://pokeapi.co/api/v2/pokemon-species/135/'},
          'evolves_to': [],
        },
      ],
    };

    test('parsea una cadena ramificada', () {
      final root = EvolutionNode.fromChainJson(chain);
      expect(root.id, 133);
      expect(root.children.map((c) => c.name), ['vaporeon', 'jolteon']);
    });

    test('toJson y fromJson son inversos', () {
      final root = EvolutionNode.fromChainJson(chain);
      final again = EvolutionNode.fromJson(root.toJson());
      expect(again.children.length, 2);
      expect(again.children.first.id, 134);
    });
  });
}
