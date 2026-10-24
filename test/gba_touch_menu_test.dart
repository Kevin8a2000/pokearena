import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/features/battle/battle_calculator.dart';
import 'package:pokearena/features/battle/battle_orientation.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/gba/gba_controls.dart';
import 'package:pokearena/features/battle/gba/gba_emulator_screen.dart';
import 'package:pokearena/features/battle/gba/gba_touch_menu.dart';
import 'package:pokearena/features/battle/gba/gba_viewport.dart';
import 'package:pokearena/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PokemonDetail _mon(int id, String name, List<String> types) => PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: types,
      stats: const {'hp': 50, 'attack': 50, 'defense': 50, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

BattleProvider _setup() {
  final b = BattleProvider(PokeApiService());
  b.setPlayerTeam([_mon(7, 'squirtle', ['water']), _mon(25, 'pikachu', ['electric'])]);
  b.enemyTeam = [_mon(4, 'charmander', ['fire'])];
  b.enemyTeamHp = [100];
  b.enemyTeamMaxHp = [100];
  b.phase = BattlePhase.fighting;
  return b;
}

/// Estas pruebas tocan el menú táctil directamente: dan por visto el
/// recorrido de foco de luz para que no tape los botones (ese recorrido
/// tiene sus propias pruebas en gba_action_spotlight_test.dart).
Widget _host(BattleProvider b, SettingsProvider s) {
  s.markActionsTutorialSeen();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BattleProvider>.value(value: b),
      ChangeNotifierProvider<SettingsProvider>.value(value: s),
    ],
    child: const MaterialApp(home: GbaEmulatorScreen()),
  );
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

  group('efectividad en el provider', () {
    test('un golpe de fuego contra una planta es ×2 y se recomienda', () async {
      final api = PokeApiService(
        client: MockClient((req) async => http.Response(
              '{"damage_relations": {"double_damage_from": [{"name": "fire"}]}}',
              200,
              headers: {'content-type': 'application/json'},
            )),
      );
      final b = BattleProvider(api);
      b.battleCriesEnabled = false;
      b.setPlayerTeam([_mon(4, 'charmander', ['fire'])]);
      b.enemyTeam = [_mon(1, 'bulbasaur', ['grass'])];
      b.enemyTeamHp = [100];
      b.enemyTeamMaxHp = [100];

      final start = b.startBattle();
      for (var i = 0; i < 100 && !b.entering; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      b.skipIntro();
      await start;

      final moves = b.playerMoves;
      final fire = moves.indexWhere((m) => m.type == 'fire' && !m.isUltimate);
      expect(fire, isNonNegative, reason: 'un Pokémon de fuego tiene un golpe de fuego');
      expect(b.moveEffectiveness(moves[fire]), 2.0);
      expect(b.playerPpLeft(fire), moves[fire].maxPp);
      expect(b.recommendedPlayerMove, isNotNull);
      expect(moves[b.recommendedPlayerMove!].type, 'fire');
      b.backToSelect();
    });

    test('sin relaciones cargadas todo es normal', () {
      final b = _setup();
      for (final m in b.playerMoves) {
        expect(b.moveEffectiveness(m), 1.0);
      }
    });
  });

  for (final s in const [Size(844, 390), Size(640, 300)]) {
    final tag = '${s.width.toInt()}x${s.height.toInt()}';

    Future<void> open(WidgetTester tester, BattleProvider b, {SettingsProvider? settings}) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(b, settings ?? SettingsProvider()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    testWidgets('$tag: los 4 botones de acción con su subtítulo y sin cruceta', (tester) async {
      await open(tester, _setup());
      for (final t in ['LUCHAR', 'MOCHILA', 'POKÉMON', 'HUIR']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (final t in ['Elige un ataque', 'Usa una poción', 'Cambia de Pokémon', 'Escapa del combate']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.byType(GbaTouchBar), findsOneWidget);
      expect(find.byType(GbaDPad), findsNothing);
      expect(find.byType(GbaABButtons), findsNothing);
      expect(find.textContaining('¿Qué debe hacer'), findsWidgets);

      // Pantalla completa: la escena llena el área y la barra va encima, abajo.
      final scene = tester.getRect(find.byType(GbaViewport));
      expect(scene, Offset.zero & s);
      final bar = tester.getRect(find.byType(GbaTouchBar));
      expect(bar.bottom, closeTo(s.height, 0.5));
      expect(bar.height, lessThan(s.height * 0.4), reason: 'la barra no tapa el juego');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: LUCHAR muestra las tarjetas con poder, precisión, PP y efectividad', (tester) async {
      final b = _setup();
      await open(tester, b);
      await tester.tap(find.text('LUCHAR'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final n = b.playerMoves.where((m) => !m.isUltimate).length;
      expect(find.byType(GbaMoveCard), findsNWidgets(n));
      expect(find.textContaining('Poder '), findsNWidgets(n));
      expect(find.textContaining('Prec. '), findsNWidgets(n));
      // Todos valen ×1 (no hay relaciones): "Normal", y solo uno lleva la estrella.
      expect(find.textContaining('★'), findsOneWidget);
      // La barra pasa a mostrar los ataques y deja volver a las acciones.
      expect(find.byType(GbaTouchBar), findsOneWidget);
      expect(find.text('HUIR'), findsNothing);
      expect(tester.getRect(find.byType(GbaTouchBar)).bottom, closeTo(s.height, 0.5));
      expect(tester.getRect(find.byType(GbaTouchBar)).height, lessThan(s.height * 0.45));
      await tester.tap(find.text('Volver'));
      await tester.pump();
      expect(find.text('HUIR'), findsOneWidget);
      expect(find.byType(GbaMoveCard), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: un movimiento sin PP no se puede lanzar y no se recomienda', (tester) async {
      final b = _setup();
      b.playerPp = [
        [for (var i = 0; i < b.playerMoves.length; i++) i == 0 ? 0 : b.playerMoves[i].maxPp],
        [for (final m in movesFor(b.playerTeam[1])) m.maxPp],
      ];
      await open(tester, b);
      await tester.tap(find.text('LUCHAR'));
      await tester.pump();
      expect(find.text('Sin PP'), findsOneWidget);
      expect(b.recommendedPlayerMove, isNot(0));

      final before = b.log.length;
      await tester.tap(find.text('Sin PP'));
      await tester.pump();
      expect(b.log.length, before, reason: 'tocar un ataque sin PP no hace nada');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: MOCHILA y POKÉMON muestran su contexto', (tester) async {
      await open(tester, _setup());
      await tester.tap(find.text('MOCHILA'));
      await tester.pump();
      expect(find.textContaining('POCIÓN x'), findsOneWidget);
      expect(find.byType(GbaTouchBar), findsOneWidget);

      await tester.tap(find.text('Volver'));
      await tester.pump();
      await tester.tap(find.text('POKÉMON'));
      await tester.pump();
      expect(find.text('Squirtle'), findsWidgets);
      expect(find.text('Pikachu'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: solo hay menú táctil: sin cruceta, A/B ni interruptor de controles', (tester) async {
      await open(tester, _setup());
      expect(find.byType(GbaDPad), findsNothing);
      expect(find.byType(GbaABButtons), findsNothing);
      expect(find.byType(GbaTriggerButton), findsNothing);
      expect(find.byType(GbaOptionButton), findsNothing);
      expect(find.byType(GbaRetroMenu), findsNothing);
      expect(find.byTooltip('Controles clásicos'), findsNothing);
      // Quedan los botones pequeños: sonido, tutorial y vista moderna.
      expect(find.byTooltip('Sonido'), findsOneWidget);
      expect(find.byTooltip('Tutorial'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('en vertical se conserva el menú clásico', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_setup(), SettingsProvider()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(GbaDPad), findsOneWidget);
    expect(find.byType(GbaTouchBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
