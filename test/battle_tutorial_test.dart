import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/features/battle/battle_orientation.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/battle_tutorial.dart';
import 'package:pokearena/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PokemonDetail _mon(int id, String name) => PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: const ['normal'],
      stats: const {'hp': 50, 'attack': 50, 'defense': 50, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

const _titles = [
  'Así se combate',
  'Un ataque, dato por dato',
  'Eficacia y ★ recomendado',
  'Poción, cambio y Mov. Z',
];

/// Pantalla con un botón que abre el tutorial (como "?" o Ajustes).
Widget _host(SettingsProvider s, {Widget? child}) => ChangeNotifierProvider<SettingsProvider>.value(
      value: s,
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: child ?? Center(child: ElevatedButton(onPressed: () => showBattleTutorial(ctx), child: const Text('abrir'))),
          ),
        ),
      ),
    );

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

  group('persistencia', () {
    test('se marca como visto, se guarda y es por usuario', () async {
      final s = SettingsProvider();
      expect(s.battleTutorialSeen, isFalse);
      await s.markBattleTutorialSeen();
      expect(s.battleTutorialSeen, isTrue);

      final again = SettingsProvider();
      await again.load();
      expect(again.battleTutorialSeen, isTrue);

      await again.switchUser('otro');
      expect(again.battleTutorialSeen, isFalse, reason: 'cada usuario ve su propio tutorial');
    });
  });

  for (final s in const [Size(844, 390), Size(640, 300), Size(420, 800)]) {
    final tag = '${s.width.toInt()}x${s.height.toInt()}';

    testWidgets('$tag: recorre las 4 láminas sin overflow y termina con ¡Entendido!', (tester) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final settings = SettingsProvider();
      await tester.pumpWidget(_host(settings));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      for (var i = 0; i < _titles.length; i++) {
        expect(find.text(_titles[i]), findsOneWidget, reason: 'lámina $i');
        expect(tester.takeException(), isNull, reason: 'lámina $i');
        if (i < _titles.length - 1) {
          expect(find.text('Siguiente'), findsOneWidget);
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();
        }
      }
      expect(find.text('Siguiente'), findsNothing);
      expect(settings.battleTutorialSeen, isFalse, reason: 'aún no se ha cerrado');
      await tester.tap(find.text('¡Entendido!'));
      await tester.pumpAndSettle();
      expect(find.text('Así se combate'), findsNothing);
      expect(settings.battleTutorialSeen, isTrue);
    });
  }

  testWidgets('la lámina del ataque explica cada dato y muestra una tarjeta de ejemplo', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(SettingsProvider()));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Un ataque, dato por dato'), findsOneWidget);
    for (final t in ['Nombre y tipo', 'Poder', 'Precisión', 'PP']) {
      await tester.scrollUntilVisible(find.text(t), 80, scrollable: find.byType(Scrollable).last);
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saltar cierra el tutorial y lo da por visto', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(_host(settings));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saltar'));
    await tester.pumpAndSettle();
    expect(find.text('Así se combate'), findsNothing);
    expect(settings.battleTutorialSeen, isTrue);

    // Se puede volver a abrir a demanda (botón "?" o Ajustes).
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Así se combate'), findsOneWidget);
  });

  testWidgets('la primera vez, "¡A pelear!" enseña el tutorial y luego empieza; la segunda no', (tester) async {
    final api = PokeApiService(
      client: MockClient((req) async => http.Response('{"damage_relations": {}}', 200, headers: {'content-type': 'application/json'})),
    );
    final b = BattleProvider(api);
    b.battleCriesEnabled = false;
    b.setPlayerTeam([_mon(25, 'pikachu')]);
    b.enemyTeam = [_mon(4, 'charmander')];
    b.enemyTeamHp = [100];
    b.enemyTeamMaxHp = [100];
    final settings = SettingsProvider();

    late BuildContext ctx;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<BattleProvider>.value(value: b),
        ],
        child: MaterialApp(
          home: Builder(builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox());
          }),
        ),
      ),
    );

    Future<void> start() async {
      unawaited(startBattleWithTutorial(ctx, b));
      await tester.pump();
    }

    /// Avanza el reloj simulado hasta que arranca la entrada y la salta.
    Future<void> enterAndSkip() async {
      for (var i = 0; i < 100 && !b.entering; i++) {
        // Tiempo real (decodificar sprites) + reloj simulado (temporizadores).
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(b.phase, BattlePhase.fighting);
      b.skipIntro();
      await tester.pump(const Duration(milliseconds: 200));
      b.backToSelect();
      await tester.pump();
    }

    await start();
    await tester.pumpAndSettle();
    expect(find.text('Así se combate'), findsOneWidget, reason: 'primera vez: tutorial antes de empezar');
    expect(b.phase, BattlePhase.selecting, reason: 'todavía no ha empezado');

    await tester.tap(find.text('Saltar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await enterAndSkip(); // tras cerrar el tutorial arranca la batalla

    // Segunda vez: ya visto, empieza directo.
    await start();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Así se combate'), findsNothing);
    await enterAndSkip();
    await tester.pump(const Duration(seconds: 10)); // deja correr los temporizadores del combate
  });
}

void unawaited(Future<void> f) {}
