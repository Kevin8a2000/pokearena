import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/features/battle/battle_orientation.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/gba/gba_action_spotlight.dart';
import 'package:pokearena/features/battle/gba/gba_emulator_screen.dart';
import 'package:pokearena/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recorrido con foco de luz sobre los 4 botones reales de combate (LUCHAR/
/// MOCHILA/POKÉMON/HUIR) y lo que cada uno abre (ataques/mochila/equipo):
/// la primera vez que empieza un combate GBA, resalta uno a la vez (el
/// resto oscurecido y bloqueado), abre el panel real que toque y avanza
/// al tocar.

const _stepTitles = [
  'TUS PS',
  'SONIDO Y AYUDA',
  'LUCHAR',
  'TUS ATAQUES',
  'MOCHILA',
  'TU POCIÓN',
  'POKÉMON',
  'TU EQUIPO',
  'HUIR',
];

PokemonDetail _mon(int id, String name) => PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: const ['normal'],
      stats: const {'hp': 50, 'attack': 50, 'defense': 50, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

BattleProvider _setup() {
  final b = BattleProvider(PokeApiService());
  b.setPlayerTeam([_mon(7, 'squirtle')]);
  b.enemyTeam = [_mon(4, 'charmander')];
  b.enemyTeamHp = [100];
  b.enemyTeamMaxHp = [100];
  b.phase = BattlePhase.fighting;
  return b;
}

Widget _host(BattleProvider b, SettingsProvider s) => MultiProvider(
      providers: [
        ChangeNotifierProvider<BattleProvider>.value(value: b),
        ChangeNotifierProvider<SettingsProvider>.value(value: s),
      ],
      child: const MaterialApp(home: GbaEmulatorScreen()),
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

  Future<void> openLandscape(WidgetTester tester, BattleProvider b, SettingsProvider s) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(b, s));
    await tester.pump();
    await tester.pump();
  }

  /// Busca el título de la leyenda (dentro del propio recorrido), no el
  /// botón real de atrás, que comparte el mismo texto.
  Finder caption(String step) => find.descendant(of: find.byType(GbaActionSpotlight), matching: find.text(step));

  testWidgets('la primera vez enciende el foco en TUS PS y bloquea el resto', (tester) async {
    final settings = SettingsProvider();
    expect(settings.actionsTutorialSeen, isFalse);
    await openLandscape(tester, _setup(), settings);

    expect(find.byType(GbaActionSpotlight), findsOneWidget);
    expect(caption('TUS PS'), findsOneWidget, reason: 'la placa HP se explica primero');
    expect(find.text('Toca en cualquier lugar para continuar'), findsOneWidget);
    expect(find.text('1/9'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tocar en cualquier parte de la pantalla avanza al siguiente paso: los
    // interruptores de sonido/ayuda.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump();
    expect(caption('SONIDO Y AYUDA'), findsOneWidget);
    expect(find.text('2/9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recorre los 9 pasos en orden, abriendo cada panel real, y al terminar marca visto y desaparece', (tester) async {
    final settings = SettingsProvider();
    await openLandscape(tester, _setup(), settings);

    for (final step in _stepTitles) {
      expect(caption(step), findsOneWidget, reason: 'paso $step');
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump();
    }

    expect(find.byType(GbaActionSpotlight), findsNothing);
    expect(settings.actionsTutorialSeen, isTrue);
    // Termina en reposo (modo 0): no deja al jugador atrapado en un submenú.
    expect(find.text('LUCHAR'), findsOneWidget);
  });

  testWidgets('Saltar cierra el recorrido de inmediato y también lo marca visto', (tester) async {
    final settings = SettingsProvider();
    await openLandscape(tester, _setup(), settings);
    expect(find.byType(GbaActionSpotlight), findsOneWidget);

    await tester.tap(find.text('Saltar'));
    await tester.pump();

    expect(find.byType(GbaActionSpotlight), findsNothing);
    expect(settings.actionsTutorialSeen, isTrue);
  });

  testWidgets('ya visto, no vuelve a aparecer solo', (tester) async {
    final settings = SettingsProvider();
    await settings.markActionsTutorialSeen();
    await openLandscape(tester, _setup(), settings);
    expect(find.byType(GbaActionSpotlight), findsNothing);
  });
}
