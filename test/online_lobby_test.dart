import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/core/widgets/poke_widgets.dart';
import 'package:pokearena/features/auth/auth_provider.dart';
import 'package:pokearena/features/battle/battle_orientation.dart';
import 'package:pokearena/features/duel/duel_screen.dart';
import 'package:pokearena/features/online/online_lobby_screen.dart';
import 'package:pokearena/features/online/online_room.dart';
import 'package:pokearena/features/settings/settings_provider.dart';
import 'package:pokearena/features/team/team_provider.dart';
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

PokeApiService _api() => PokeApiService(
      client: MockClient((req) async => http.Response('{"damage_relations": {}}', 200, headers: {'content-type': 'application/json'})),
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

  /// Pantalla del lobby con sus proveedores y una base falsa.
  Future<(FakeFirebaseFirestore, TeamProvider)> open(WidgetTester tester, {List<PokemonDetail> team = const [], FakeFirebaseFirestore? db}) async {
    final fake = db ?? FakeFirebaseFirestore();
    final api = _api();
    final teamProvider = TeamProvider(api);
    for (final p in team) {
      await teamProvider.addPokemon(p);
    }
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PokeApiService>.value(value: api),
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<TeamProvider>.value(value: teamProvider),
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(home: OnlineLobbyScreen(db: fake)),
      ),
    );
    await tester.pump();
    return (fake, teamProvider);
  }

  /// Deja correr las escuchas de Firestore (tiempo real) y repinta.
  Future<void> settle(WidgetTester tester, [int ms = 80]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('muestra el lobby del Duelo con crear sala y unirse con código', (tester) async {
    await open(tester, team: [_mon(1, 'bulbasaur', ['grass'])]);
    expect(find.byWidgetPredicate((w) => w is PokeLogoText && w.text == 'Duelo Online'), findsOneWidget);
    expect(find.text('CREAR SALA'), findsOneWidget);
    expect(find.text('UNIRSE'), findsOneWidget);
    expect(find.text('Tu luchador'), findsOneWidget);
    expect(find.text('Tu nombre'), findsOneWidget);
    // Ya no hay formatos 1v1/2v2/3v3 (el Duelo es 1 contra 1).
    expect(find.text('3v3'), findsNothing);
    expect(find.text('Batalla Online'), findsNothing);
  });

  testWidgets('sin equipo no deja crear ni unirse y lo explica', (tester) async {
    final (db, _) = await open(tester);
    expect(find.textContaining('Arma tu equipo'), findsOneWidget);
    await tester.tap(find.text('CREAR SALA'));
    await tester.pump();
    expect(find.text('Arma tu equipo primero (pestaña Equipo).'), findsOneWidget);
    expect((await db.collection('rooms').get()).docs, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Código'), 'ABC234');
    await tester.tap(find.text('UNIRSE'));
    await tester.pump();
    expect(find.text('Arma tu equipo primero (pestaña Equipo).'), findsOneWidget);
  });

  testWidgets('se elige el luchador entre los del equipo', (tester) async {
    await open(tester, team: [_mon(1, 'bulbasaur', ['grass']), _mon(7, 'squirtle', ['water']), _mon(4, 'charmander', ['fire'])]);
    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('Squirtle'), findsOneWidget);
    expect(find.text('Charmander'), findsOneWidget);
  });

  testWidgets('crear sala: aparece el código de 6, se espera al rival y la sala existe con mi luchador elegido', (tester) async {
    final (db, _) = await open(tester, team: [_mon(1, 'bulbasaur', ['grass']), _mon(7, 'squirtle', ['water'])]);
    await tester.tap(find.text('Squirtle'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Ash');
    await tester.tap(find.text('CREAR SALA'));
    await settle(tester);

    expect(find.textContaining('Comparte este código'), findsOneWidget);
    expect(find.textContaining('Esperando al rival'), findsOneWidget);
    final docs = (await db.collection('rooms').get()).docs;
    expect(docs, hasLength(1));
    final code = docs.single.id;
    expect(code.length, 6);
    expect(find.text(code), findsOneWidget);
    final data = docs.single.data();
    expect(data['status'], 'waiting');
    expect(data['players']['p0']['name'], 'Ash');
    expect(data['players']['p0']['fighter']['name'], 'squirtle');
    expect(tester.takeException(), isNull);

    // Cancelar borra la sala (nadie había entrado).
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect((await db.collection('rooms').doc(code).get()).exists, isFalse);
  });

  testWidgets('unirse: códigos incorrectos dan mensajes claros', (tester) async {
    final (db, _) = await open(tester, team: [_mon(1, 'bulbasaur', ['grass'])]);
    final field = find.widgetWithText(TextField, 'Código');

    await tester.enterText(field, 'AB12');
    await tester.tap(find.text('UNIRSE'));
    await settle(tester);
    expect(find.text('El código tiene 6 letras/números.'), findsOneWidget);

    await tester.enterText(field, 'ZZZZZZ');
    await tester.tap(find.text('UNIRSE'));
    await settle(tester);
    expect(find.text('Sala no encontrada.'), findsOneWidget);

    // Sala llena.
    final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(4, 'charmander', ['fire']), seed: 1);
    await OnlineRoom.join(db, code: host.code, name: 'Otro', fighter: _mon(7, 'squirtle', ['water']));
    await tester.enterText(field, host.code);
    await tester.tap(find.text('UNIRSE'));
    await settle(tester);
    expect(find.text('Esa sala ya está llena.'), findsOneWidget);

    // Sala que ya empezó.
    final started = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(4, 'charmander', ['fire']), seed: 1);
    await started.markReady();
    await tester.enterText(field, started.code);
    await tester.tap(find.text('UNIRSE'));
    await settle(tester);
    expect(find.text('Esa sala ya empezó o terminó.'), findsOneWidget);
  });

  testWidgets('unirse con el código (en minúsculas también) deja esperando al anfitrión', (tester) async {
    final db = FakeFirebaseFirestore();
    final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(4, 'charmander', ['fire']), seed: 5);
    await open(tester, team: [_mon(7, 'squirtle', ['water'])], db: db);
    await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Misty');
    await tester.enterText(find.widgetWithText(TextField, 'Código'), host.code.toLowerCase());
    await tester.tap(find.text('UNIRSE'));
    await settle(tester);
    expect(find.text('Te uniste a la sala:'), findsOneWidget);
    expect(find.textContaining('Esperando a que el anfitrión empiece'), findsOneWidget);
    final data = (await db.collection('rooms').doc(host.code).get()).data()!;
    expect(data['players']['p1']['name'], 'Misty');
    expect(data['players']['p1']['fighter']['name'], 'squirtle');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el anfitrión entra al duelo cuando se une el rival (flujo completo)', (tester) async {
    final (db, _) = await open(tester, team: [_mon(7, 'squirtle', ['water'])]);
    await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Ash');
    await tester.tap(find.text('CREAR SALA'));
    await settle(tester);
    final code = (await db.collection('rooms').get()).docs.single.id;

    // Llega el rival.
    await tester.runAsync(() => OnlineRoom.join(db, code: code, name: 'Misty', fighter: _mon(4, 'charmander', ['fire'])));
    await settle(tester, 200);
    await settle(tester, 200);

    expect(find.byType(DuelScreen), findsOneWidget);
    final screen = tester.widget<DuelScreen>(find.byType(DuelScreen));
    expect(screen.host, isNotNull);
    expect(screen.guest, isNull);
    expect(screen.hostFighter.name, 'squirtle');
    expect(screen.guestFighter.name, 'charmander');
    expect(screen.hostName, 'Ash');
    expect(screen.guestName, 'Misty');
    expect((await db.collection('rooms').doc(code).get()).data()!['status'], 'ready');
    expect(tester.takeException(), isNull);

    // Salir a media pelea: el rival gana por retiro.
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    final result = (await db.collection('rooms').doc(code).get()).data()!;
    expect(result['status'], 'finished');
    expect(result['result']['winner'], 'p1');
  });

  testWidgets('el invitado entra al duelo cuando el anfitrión marca la sala lista', (tester) async {
    final db = FakeFirebaseFirestore();
    final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(4, 'charmander', ['fire']), seed: 9);
    await open(tester, team: [_mon(7, 'squirtle', ['water'])], db: db);
    await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Misty');
    await tester.enterText(find.widgetWithText(TextField, 'Código'), host.code);
    await tester.tap(find.text('UNIRSE'));
    await settle(tester);
    expect(find.byType(DuelScreen), findsNothing);

    await tester.runAsync(host.markReady);
    await settle(tester, 200);
    await settle(tester, 200);

    expect(find.byType(DuelScreen), findsOneWidget);
    final screen = tester.widget<DuelScreen>(find.byType(DuelScreen));
    expect(screen.guest, isNotNull);
    expect(screen.host, isNull);
    expect(screen.hostFighter.name, 'charmander');
    expect(screen.guestFighter.name, 'squirtle');
    expect(screen.onFinish, isNull, reason: 'solo el anfitrión cierra la sala');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('los dos ven el mismo terreno (sale de la semilla de la sala)', (tester) async {
    final db = FakeFirebaseFirestore();
    final host = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(4, 'charmander', ['fire']), seed: 3);
    await open(tester, team: [_mon(7, 'squirtle', ['water'])], db: db);
    await tester.enterText(find.widgetWithText(TextField, 'Código'), host.code);
    await tester.tap(find.text('UNIRSE'));
    await settle(tester);
    await tester.runAsync(host.markReady);
    await settle(tester, 200);
    await settle(tester, 200);
    final terrainGuest = tester.widget<DuelScreen>(find.byType(DuelScreen)).terrain.id;
    await tester.pumpWidget(const SizedBox());
    await settle(tester);

    // Otro lobby en la misma sala con la misma semilla: mismo terreno.
    final host2 = await OnlineRoom.create(db, name: 'Ash', fighter: _mon(4, 'charmander', ['fire']), seed: 3);
    await open(tester, team: [_mon(7, 'squirtle', ['water'])], db: db);
    await tester.enterText(find.widgetWithText(TextField, 'Código'), host2.code);
    await tester.tap(find.text('UNIRSE'));
    await settle(tester);
    await tester.runAsync(host2.markReady);
    await settle(tester, 200);
    await settle(tester, 200);
    expect(tester.widget<DuelScreen>(find.byType(DuelScreen)).terrain.id, terrainGuest);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
