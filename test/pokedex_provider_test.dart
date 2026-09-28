import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/pokedex/pokedex_provider.dart';

/// Servicio falso: no usa internet, devuelve datos fijos.
class FakeApi extends PokeApiService {
  @override
  Future<List<PokemonSummary>> fetchAllPokemon() async => const [
        PokemonSummary(id: 1, name: 'bulbasaur'),
        PokemonSummary(id: 4, name: 'charmander'),
        PokemonSummary(id: 25, name: 'pikachu'),
        PokemonSummary(id: 122, name: 'mr-mime'),
      ];

  @override
  Future<Set<int>> fetchIdsByType(String type) async => {4};

  @override
  Future<Set<int>> fetchIdsByGeneration(int generation) async => {1, 4, 25};
}

void main() {
  late PokedexProvider provider;

  setUp(() async {
    provider = PokedexProvider(FakeApi());
    await provider.load();
  });

  tearDown(() => provider.dispose());

  test('carga toda la lista', () {
    expect(provider.visible.length, 4);
  });

  test('busca por nombre parcial', () {
    provider.applyQuery('char');
    expect(provider.visible.map((p) => p.name), ['charmander']);
  });

  test('busca por número, con o sin #', () {
    provider.applyQuery('25');
    expect(provider.visible.single.name, 'pikachu');
    provider.applyQuery('#25');
    expect(provider.visible.single.name, 'pikachu');
  });

  test('los espacios equivalen a guion (mr mime)', () {
    provider.applyQuery('mr mime');
    expect(provider.visible.single.id, 122);
  });

  test('el filtro por tipo reduce la lista', () async {
    await provider.selectType('fire');
    expect(provider.visible.map((p) => p.name), ['charmander']);
  });

  test('búsqueda, tipo y generación se combinan', () async {
    await provider.selectGeneration(1);
    expect(provider.visible.length, 3);
    provider.applyQuery('pika');
    expect(provider.visible.single.name, 'pikachu');
    await provider.selectType('fire');
    expect(provider.visible, isEmpty); // pikachu no es de fuego
  });

  test('limpiar filtros devuelve todo', () async {
    await provider.selectType('fire');
    provider.applyQuery('char');
    provider.clearFilters();
    expect(provider.visible.length, 4);
    expect(provider.hasActiveFilters, isFalse);
  });
}
