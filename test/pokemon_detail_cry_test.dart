import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/features/pokedex/pokemon_detail_page.dart';
import 'package:pokearena/features/profile/favorites_provider.dart';
import 'package:pokearena/features/team/team_provider.dart';
import 'package:pokearena/features/wallet/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _bulbasaurDetail = {
  'id': 1,
  'name': 'bulbasaur',
  'height': 7,
  'weight': 69,
  'types': [
    {'type': {'name': 'grass'}},
    {'type': {'name': 'poison'}},
  ],
  'stats': [
    {'stat': {'name': 'hp'}, 'base_stat': 45},
    {'stat': {'name': 'attack'}, 'base_stat': 49},
    {'stat': {'name': 'defense'}, 'base_stat': 49},
    {'stat': {'name': 'special-attack'}, 'base_stat': 65},
    {'stat': {'name': 'special-defense'}, 'base_stat': 65},
    {'stat': {'name': 'speed'}, 'base_stat': 45},
  ],
  'abilities': [],
};

final _bulbasaurSpecies = {'name': 'bulbasaur', 'evolution_chain': null};

PokeApiService _api() => PokeApiService(
      client: MockClient((req) async {
        if (req.url.path.contains('pokemon-species')) {
          return http.Response(jsonEncode(_bulbasaurSpecies), 200, headers: {'content-type': 'application/json'});
        }
        if (req.url.path.contains('/pokemon/1')) {
          return http.Response(jsonEncode(_bulbasaurDetail), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 404);
      }),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundService.enabled = false;
  });

  testWidgets('tocar el arte del Pokémon en el detalle reproduce su grito sin errores', (tester) async {
    final api = _api();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PokeApiService>.value(value: api),
          ChangeNotifierProvider<TeamProvider>(create: (_) => TeamProvider(api)),
          ChangeNotifierProvider<FavoritesProvider>(create: (_) => FavoritesProvider(api)),
          ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider()),
        ],
        child: const MaterialApp(home: PokemonDetailPage(id: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Bulbasaur'), findsWidgets);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
