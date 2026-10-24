import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/features/battle/battle_orientation.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PokemonDetail _mon(int id, String name) => PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: const ['normal'],
      stats: const {'hp': 50, 'attack': 50, 'defense': 50, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

/// API de mentira: las relaciones de tipo son siempre neutras.
PokeApiService _fakeApi({bool fail = false}) => PokeApiService(
      client: MockClient((req) async {
        if (fail) return http.Response('error', 500);
        return http.Response('{"damage_relations": {}}', 200, headers: {'content-type': 'application/json'});
      }),
    );

BattleProvider _provider(PokeApiService api) {
  final b = BattleProvider(api);
  b.battleCriesEnabled = false; // sin audio en los tests
  b.setPlayerTeam([_mon(25, 'pikachu')]);
  b.enemyTeam = [_mon(4, 'charmander')];
  b.enemyTeamHp = [100];
  b.enemyTeamMaxHp = [100];
  return b;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundService.enabled = false;
    BattleOrientation.debugReset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    BattleOrientation.debugReset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Normal', () {
    test('startBattle gira a horizontal al empezar y se queda así durante el combate', () async {
      final b = _provider(_fakeApi());
      final start = b.startBattle();
      // La orientación se pide antes de cargar nada (sin esperar a la red).
      expect(BattleOrientation.locks, 1);

      // Espera a que arranque la entrada y sáltala para no esperar 3,4 s.
      for (var i = 0; i < 100 && !b.entering; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(b.phase, BattlePhase.fighting);
      b.skipIntro();
      await start;

      expect(b.phase, BattlePhase.fighting);
      expect(BattleOrientation.locks, 1, reason: 'sigue en horizontal durante el combate');
    });

    test('al volver a la selección se suelta la orientación, y una sola vez', () async {
      final b = _provider(_fakeApi());
      final start = b.startBattle();
      for (var i = 0; i < 100 && !b.entering; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      b.skipIntro();
      await start;
      expect(BattleOrientation.locks, 1);

      b.backToSelect();
      expect(BattleOrientation.locks, 0);
      b.backToSelect(); // un segundo "Volver" no debe dejarla en negativo
      b.resetTeams();
      expect(BattleOrientation.locks, 0);
    });

    test('si la carga falla no queda bloqueado en horizontal', () async {
      final b = _provider(_fakeApi(fail: true));
      Object? error;
      try {
        await b.startBattle();
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull, reason: 'la API falla, startBattle lanza');
      expect(BattleOrientation.locks, 0);
      expect(b.phase, BattlePhase.selecting);
    });
  });

  test('huir durante la entrada también restaura la orientación', () async {
    final b = _provider(_fakeApi());
    final start = b.startBattle();
    for (var i = 0; i < 100 && !b.entering; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(BattleOrientation.locks, 1);
    b.backToSelect(); // HUIR
    expect(BattleOrientation.locks, 0);
    b.skipIntro();
    await start;
    expect(BattleOrientation.locks, 0);
  });
}
