import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/profile/favorites_provider.dart';
import 'package:pokearena/features/profile/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePokeApiService extends PokeApiService {
  @override
  Future<List<PokemonSummary>> fetchAllPokemon() async {
    return const [
      PokemonSummary(id: 25, name: 'pikachu'),
      PokemonSummary(id: 4, name: 'charmander'),
      PokemonSummary(id: 1, name: 'bulbasaur'),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider - Pruebas Unitarias (Sprint 2 / Requisito F4)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('inicia por defecto en ThemeMode.system', () {
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.system);
    });

    test('cambia el modo y notifica a los oyentes', () async {
      final provider = ThemeProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      expect(notified, isTrue);
    });

    test('persiste y recupera el modo de tema guardado', () async {
      final provider1 = ThemeProvider();
      await provider1.setThemeMode(ThemeMode.light);

      final provider2 = ThemeProvider();
      await provider2.loadSavedTheme();
      expect(provider2.themeMode, ThemeMode.light);
    });
  });

  group('FavoritesProvider - Pruebas Unitarias (Sprint 2 / Requisitos F1, F2)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('agrega y remueve favoritos con toggleFavorite', () async {
      final api = _FakePokeApiService();
      final provider = FavoritesProvider(api);

      expect(provider.isFavorite(25), isFalse);
      expect(provider.count, 0);

      // Agregar a Pikachu
      await provider.toggleFavorite(id: 25, name: 'pikachu');
      expect(provider.isFavorite(25), isTrue);
      expect(provider.count, 1);
      expect(provider.favorites.first.name, 'pikachu');

      // Remover a Pikachu
      await provider.toggleFavorite(id: 25, name: 'pikachu');
      expect(provider.isFavorite(25), isFalse);
      expect(provider.count, 0);
    });

    test('persiste los favoritos y los carga al reiniciar', () async {
      final api = _FakePokeApiService();
      final provider1 = FavoritesProvider(api);

      await provider1.toggleFavorite(id: 25, name: 'pikachu');
      await provider1.toggleFavorite(id: 4, name: 'charmander');

      final provider2 = FavoritesProvider(api);
      await provider2.loadFavorites();

      expect(provider2.count, 2);
      expect(provider2.isFavorite(25), isTrue);
      expect(provider2.isFavorite(4), isTrue);
      expect(provider2.isFavorite(1), isFalse);
    });
  });
}
