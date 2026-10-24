import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/core/widgets/poke_image.dart';
import 'package:pokearena/features/battle/battle_orientation.dart';
import 'package:pokearena/features/battle/battle_terrain.dart';
import 'package:pokearena/features/duel/duel_engine.dart';
import 'package:pokearena/features/duel/duel_hud.dart';
import 'package:pokearena/features/duel/duel_rig.dart';
import 'package:pokearena/features/duel/duel_screen.dart';
import 'package:pokearena/features/duel/net/duel_link.dart';
import 'package:pokearena/features/duel/net/duel_snapshot.dart';
import 'package:pokearena/features/duel/net/duel_transport.dart';
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

final _hostMon = _mon(7, 'squirtle', ['water']);
final _guestMon = _mon(4, 'charmander', ['fire']);

Future<SettingsProvider> _seen() async {
  final s = SettingsProvider();
  await s.markDuelTutorialSeen();
  return s;
}

/// Lo que ve cada prueba: el combate real vive en el anfitrión; el invitado es
/// un extremo "sin pantalla" (ordenador) o la pantalla misma.
class _Session {
  final MemoryDuelHub hub = MemoryDuelHub();
  double now = 0;
  late final DuelHostLink hostLink = DuelHostLink(hub.host, clock: () => now);
  late final DuelGuestLink guestLink = DuelGuestLink(hub.guest, clock: () => now);
  final DuelMatch mirror = DuelMatch(playerMon: _hostMon, enemyMon: _guestMon);
  final List<(int?, String)> finishes = [];
  final List<bool> leaves = [];
  bool guestPlays = true; // el invitado sin pantalla envía sus latidos
}

Widget _hostApp(SettingsProvider s, _Session ses, {double? roundDuration}) => ChangeNotifierProvider<SettingsProvider>.value(
      value: s,
      child: MaterialApp(
        home: DuelScreen(
          hostFighter: _hostMon,
          guestFighter: _guestMon,
          hostName: 'Ash',
          guestName: 'Misty',
          terrain: battleTerrains.first,
          host: ses.hostLink,
          roundDuration: roundDuration,
          rng: math.Random(3),
          onFinish: (w, r) => ses.finishes.add((w, r)),
          onLeave: ses.leaves.add,
        ),
      ),
    );

Widget _guestApp(SettingsProvider s, _Session ses) => ChangeNotifierProvider<SettingsProvider>.value(
      value: s,
      child: MaterialApp(
        home: DuelScreen(
          hostFighter: _hostMon,
          guestFighter: _guestMon,
          hostName: 'Ash',
          guestName: 'Misty',
          terrain: battleTerrains.first,
          guest: ses.guestLink,
          rng: math.Random(3),
          onLeave: ses.leaves.add,
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

  Future<void> pumpFor(WidgetTester tester, _Session ses, double seconds) async {
    for (var i = 0; i < (seconds / 0.05).round(); i++) {
      ses.now += 0.05;
      await tester.pump(const Duration(milliseconds: 50));
      if (ses.guestPlays) ses.guestLink.update(0.05, ses.mirror);
    }
  }

  // ------------------------------------------------------------- anfitrión

  for (final s in const [Size(844, 390), Size(640, 300)]) {
    final tag = '${s.width.toInt()}x${s.height.toInt()}';

    /// Abre la pantalla del anfitrión con el invitado ya listo.
    Future<(DuelScreenState, _Session)> openHost(WidgetTester tester, {double? roundDuration, bool guestReady = true, SettingsProvider? settings}) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final ses = _Session();
      if (guestReady) ses.guestLink.setReady(true);
      await tester.pumpWidget(_hostApp(settings ?? await _seen(), ses, roundDuration: roundDuration));
      await pumpFor(tester, ses, 0.2);
      expect(tester.takeException(), isNull);
      return (tester.state<DuelScreenState>(find.byType(DuelScreen)), ses);
    }

    testWidgets('$tag: HUD simple (placas, barras, reloj, terreno, analógico y 5 botones) sin overflow', (tester) async {
      final (_, _) = await openHost(tester);
      for (final t in ['PUÑO', 'PODERES', '¡ULTRA!', 'ESCUDO', 'ESQUIVAR']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (final t in ['SALTO', 'CORRER/DESLIZAR', 'APOYO 1', 'APOYO 2', 'BLOQUEO', 'ATAQUE BÁSICO', 'HIDROPULSO']) {
        expect(find.text(t), findsNothing, reason: t);
      }
      expect(find.byType(DuelJoystick), findsOneWidget);
      expect(find.byType(DuelActionButton), findsNWidgets(5));
      expect(find.byType(DuelPlate), findsNWidgets(2));
      expect(find.text('STAMINA'), findsNWidgets(2));
      expect(find.text('ULTRA'), findsOneWidget);
      expect(find.text('FRENESÍ'), findsOneWidget);
      expect(find.byType(DuelTimer), findsOneWidget);
      expect(find.text(battleTerrains.first.name.toUpperCase()), findsOneWidget);
      // El anfitrión se ve a la izquierda con su luchador.
      expect(find.text('SQUIRTLE'), findsOneWidget);
      expect(find.text('CHARMANDER'), findsOneWidget);
      expect(tester.getCenter(find.text('SQUIRTLE')).dx, lessThan(tester.getCenter(find.text('CHARMANDER')).dx));

      expect(tester.getCenter(find.byType(DuelJoystick)).dx, lessThan(s.width * 0.25));
      expect(tester.getCenter(find.text('PUÑO')).dx, greaterThan(s.width * 0.7));
      for (final t in ['PUÑO', 'PODERES', '¡ULTRA!', 'ESCUDO', 'ESQUIVAR']) {
        final r = tester.getRect(find.text(t));
        expect(r.left, greaterThanOrEqualTo(-0.5), reason: t);
        expect(r.right, lessThanOrEqualTo(s.width + 0.5), reason: t);
        expect(r.bottom, lessThanOrEqualTo(s.height + 0.5), reason: t);
      }
      final joy = tester.getRect(find.byType(DuelJoystick));
      final rects = [for (final e in find.byType(DuelActionButton).evaluate()) tester.getRect(find.byElementPredicate((x) => x == e))];
      for (final r in rects) {
        expect(r.left, greaterThan(joy.right - 1));
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          final inter = rects[i].intersect(rects[j]);
          expect(inter.width <= 0 || inter.height <= 0 || inter.width * inter.height < 60, isTrue, reason: 'botones $i y $j se pisan');
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: el anfitrión espera al invitado y empieza cuando está listo', (tester) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final ses = _Session()..guestPlays = false;
      await tester.pumpWidget(_hostApp(await _seen(), ses));
      await tester.pump(const Duration(milliseconds: 100));
      final st = tester.state<DuelScreenState>(find.byType(DuelScreen));
      expect(find.text('Esperando a Misty…'), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(st.engine.timeLeft, DuelTuning.duration, reason: 'el reloj espera');

      // El invitado se conecta pero aún no está listo (leyendo el tutorial).
      ses.guestLink.update(0.1, ses.mirror);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Misty está leyendo el tutorial…'), findsOneWidget);
      expect(st.engine.timeLeft, DuelTuning.duration);

      // Ya está listo: desaparece el aviso y corre el reloj.
      ses.guestLink.setReady(true);
      ses.guestLink.update(0.1, ses.mirror);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Esperando'), findsNothing);
      expect(find.textContaining('leyendo'), findsNothing);
      ses.guestPlays = true;
      await pumpFor(tester, ses, 1);
      expect(st.engine.timeLeft, lessThan(DuelTuning.duration));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: PUÑO golpea al rival en alcance y sale el número de daño', (tester) async {
      final (st, ses) = await openHost(tester);
      st.engine.player.x = 50;
      st.engine.enemy.x = 58;
      await tester.tap(find.text('PUÑO'));
      await pumpFor(tester, ses, 0.3);
      expect(st.engine.enemy.hp, lessThan(st.engine.enemy.maxHp));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: los luchadores se dibujan enteros, una sola vez y en alta calidad', (tester) async {
      final (st, ses) = await openHost(tester);
      final hq = find.byWidgetPredicate((w) => w is PokeImage && w.kind == PokeSpriteKind.artwork && w.filterQuality == FilterQuality.high);
      expect(hq, findsNWidgets(4));
      expect(find.byWidgetPredicate((w) => w is PokeImage && w.kind == PokeSpriteKind.animatedFront), findsNothing);
      expect(find.byType(FighterSprite), findsNWidgets(2));
      st.engine.player.x = 50;
      st.engine.enemy.x = 58;
      await tester.tap(find.text('PUÑO'));
      await pumpFor(tester, ses, 0.2);
      expect(find.byType(FighterSprite), findsNWidgets(2));
      expect(find.descendant(of: find.byType(FighterSprite), matching: find.byType(ClipRect)), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: el cuerpo se anima con el combate (se lanza al pegar y vuelve a reposo)', (tester) async {
      final (st, ses) = await openHost(tester);
      st.engine.player.x = 50;
      st.engine.enemy.x = 58;
      RigPose pose() => tester.widget<FighterSprite>(find.byType(FighterSprite).first).pose;
      final idle = pose();
      await tester.tap(find.text('PUÑO'));
      var minDx = 0.0;
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        minDx = math.min(minDx, pose().dx);
      }
      expect(minDx, lessThan(idle.dx - 0.04));
      await pumpFor(tester, ses, 1.5);
      expect(pose().dx.abs(), lessThan(0.02));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: el reloj corre', (tester) async {
      final (st, ses) = await openHost(tester);
      await pumpFor(tester, ses, 1.5);
      expect(st.engine.timeLeft, lessThan(DuelTuning.duration - 1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: el analógico mueve en proporción a lo que lo arrastras', (tester) async {
      final (st, ses) = await openHost(tester);
      st.engine.enemy.x = 95;
      final center = tester.getCenter(find.byType(DuelJoystick));
      Future<double> run(double dx) async {
        st.engine.player.x = 30;
        final g = await tester.startGesture(center);
        await g.moveBy(Offset(dx, 0));
        await pumpFor(tester, ses, 0.4);
        await g.up();
        await pumpFor(tester, ses, 0.1);
        return st.engine.player.x - 30;
      }

      final half = await run(18);
      final full = await run(44);
      expect(half, greaterThan(1));
      expect(full, greaterThan(half * 1.5));
      st.engine.player.x = 50;
      final g = await tester.startGesture(center);
      await g.moveBy(const Offset(-40, 0));
      await pumpFor(tester, ses, 0.3);
      expect(st.engine.player.x, lessThan(48));
      await g.up();
      await pumpFor(tester, ses, 0.1);
      final x1 = st.engine.player.x;
      await pumpFor(tester, ses, 0.2);
      expect(st.engine.player.x, closeTo(x1, 0.01));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: ESCUDO se mantiene pulsado', (tester) async {
      final (st, ses) = await openHost(tester);
      final g = await tester.startGesture(tester.getCenter(find.text('ESCUDO')) - const Offset(0, 16));
      await pumpFor(tester, ses, 0.2);
      expect(st.engine.player.guarding, isTrue);
      await g.up();
      await pumpFor(tester, ses, 0.1);
      expect(st.engine.player.guarding, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: PODERES lanza una horda de disparos, gasta stamina y entra en espera', (tester) async {
      final (st, ses) = await openHost(tester);
      st.engine.player.x = 20;
      st.engine.enemy.x = 95;
      await tester.tap(find.text('PODERES'));
      await pumpFor(tester, ses, 0.35);
      expect(st.engine.player.stamina, lessThan(DuelTuning.staminaMax - 10));
      expect(st.engine.player.hordeCd, greaterThan(0));
      expect(st.engine.projectiles.where((p) => p.owner == DuelSide.player).length, greaterThanOrEqualTo(2));
      await pumpFor(tester, ses, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: ESQUIVAR da un impulso invulnerable', (tester) async {
      final (st, ses) = await openHost(tester);
      await tester.tap(find.text('ESQUIVAR'));
      await pumpFor(tester, ses, 0.1);
      expect(st.engine.player.state, DuelState.dodge);
      expect(st.engine.player.invulnerable, greaterThan(0));
      await pumpFor(tester, ses, 0.6);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: ¡ULTRA! solo funciona con la barra llena', (tester) async {
      final (st, ses) = await openHost(tester);
      st.engine.player.x = 40;
      st.engine.enemy.x = 70;
      await tester.tap(find.text('¡ULTRA!'));
      await pumpFor(tester, ses, 0.2);
      expect(st.engine.player.state, isNot(DuelState.ultra));
      st.engine.player.ultra = DuelTuning.ultraMax;
      await pumpFor(tester, ses, 0.1);
      await tester.tap(find.text('¡ULTRA!'));
      await pumpFor(tester, ses, 0.2);
      expect(st.engine.player.state, DuelState.ultra);
      expect(tester.takeException(), isNull);
      await pumpFor(tester, ses, 1.5);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: multitáctil: analógico y botón a la vez', (tester) async {
      final (st, ses) = await openHost(tester);
      st.engine.enemy.x = 90;
      final x0 = st.engine.player.x;
      final stick = await tester.startGesture(tester.getCenter(find.byType(DuelJoystick)));
      await stick.moveBy(const Offset(40, 0));
      final button = await tester.startGesture(tester.getCenter(find.text('ESQUIVAR')) - const Offset(0, 16));
      await pumpFor(tester, ses, 0.2);
      expect(st.engine.player.x, greaterThan(x0));
      expect(st.engine.player.stamina, lessThan(DuelTuning.staminaMax));
      await button.up();
      await stick.up();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: los controles del invitado se aplican en el anfitrión', (tester) async {
      final (st, ses) = await openHost(tester);
      st.engine.player.x = 50;
      st.engine.enemy.x = 58;
      ses.guestLink.pressAttack();
      await pumpFor(tester, ses, 0.4);
      expect(st.engine.player.hp, lessThan(st.engine.player.maxHp), reason: 'el golpe del invitado llegó');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: ganar 2 rondas: coronas, "RONDA 2" y al final VICTORIA con Revancha', (tester) async {
      final (st, ses) = await openHost(tester);
      Future<void> winRound() async {
        st.engine.player.x = 50;
        st.engine.enemy.x = 58;
        st.engine.enemy.hp = 1;
        await tester.tap(find.text('PUÑO'));
        await pumpFor(tester, ses, 2.5);
      }

      await winRound();
      expect(st.match.playerWins, 1);
      expect(find.text('RONDA 2'), findsOneWidget);
      expect(find.text('¡VICTORIA!'), findsNothing);
      expect(ses.finishes, isEmpty, reason: 'aún no acaba el combate');
      await pumpFor(tester, ses, 2.5);
      expect(st.match.round, 2);
      expect(st.engine.over, isFalse);
      expect(st.engine.player.hp, st.engine.player.maxHp);

      await winRound();
      expect(st.match.over, isTrue);
      expect(find.text('¡VICTORIA!'), findsOneWidget);
      expect(find.text('Revancha'), findsOneWidget);
      expect(find.text('2 - 0 en rondas contra Misty'), findsOneWidget);
      expect(ses.finishes, [(0, 'Fin del combate')], reason: 'se informa a la sala una sola vez');

      await tester.tap(find.text('Revancha'));
      await pumpFor(tester, ses, 0.1);
      expect(find.text('¡VICTORIA!'), findsNothing);
      expect(st.match.round, 1);
      expect(st.match.playerWins, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: perder el combate muestra DERROTA y gana el invitado', (tester) async {
      final (st, ses) = await openHost(tester);
      st.match.enemyWins = 1;
      st.engine.player.x = 50;
      st.engine.enemy.x = 58;
      st.engine.player.hp = 1;
      ses.guestLink.pressAttack();
      await pumpFor(tester, ses, 3.5);
      expect(st.engine.winnerSide, DuelSide.enemy);
      expect(find.text('DERROTA'), findsOneWidget);
      expect(ses.finishes, [(1, 'Fin del combate')]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: si el invitado se desconecta avisa y el anfitrión gana por retiro', (tester) async {
      final (st, ses) = await openHost(tester);
      ses.guestPlays = false; // el invitado deja de dar señales
      await pumpFor(tester, ses, 6);
      expect(find.textContaining('Conexión inestable con Misty'), findsOneWidget);
      expect(find.text('¡VICTORIA!'), findsNothing);
      await pumpFor(tester, ses, 10);
      expect(find.text('¡VICTORIA!'), findsOneWidget);
      expect(find.text('Misty se desconectó.'), findsOneWidget);
      expect(find.text('Revancha'), findsNothing);
      expect(ses.finishes, [(0, 'Retiro del rival')]);
      expect(st.engine.over, isFalse, reason: 'no hay KO: se gana por retiro');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$tag: la ayuda "?" se abre sin detener el combate online', (tester) async {
      final (st, ses) = await openHost(tester);
      await tester.tap(find.byTooltip('Tutorial'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Cómo se juega el Duelo'), findsOneWidget);
      final t0 = st.engine.timeLeft;
      await pumpFor(tester, ses, 1);
      expect(st.engine.timeLeft, lessThan(t0 - 0.5), reason: 'el rival no espera a que leas');
      await tester.tap(find.text('¡Entendido!'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Cómo se juega el Duelo'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('bloquea horizontal al entrar, avisa al salir y lo suelta', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ses = _Session();
    await tester.pumpWidget(_hostApp(await _seen(), ses));
    await tester.pump(const Duration(milliseconds: 50));
    expect(BattleOrientation.locks, 1);
    await tester.pumpWidget(const SizedBox());
    expect(BattleOrientation.locks, 0);
    expect(ses.leaves, [true], reason: 'salir a media pelea avisa de que se estaba peleando');
  });

  group('tutorial', () {
    testWidgets('la primera vez el anfitrión no empieza hasta cerrar su tutorial', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final ses = _Session()..guestLink.setReady(true);
      final settings = SettingsProvider();
      await tester.pumpWidget(_hostApp(settings, ses));
      await pumpFor(tester, ses, 0.2);
      final st = tester.state<DuelScreenState>(find.byType(DuelScreen));
      expect(find.text('Cómo se juega el Duelo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await pumpFor(tester, ses, 1);
      expect(st.engine.timeLeft, DuelTuning.duration, reason: 'el reloj espera');

      await tester.tap(find.text('¡Entendido!'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Cómo se juega el Duelo'), findsNothing);
      expect(settings.duelTutorialSeen, isTrue);
      await pumpFor(tester, ses, 1);
      expect(st.engine.timeLeft, lessThan(DuelTuning.duration));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cabe en pantallas bajas con el botón siempre visible', (tester) async {
      tester.view.physicalSize = const Size(640, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final ses = _Session();
      await tester.pumpWidget(_hostApp(SettingsProvider(), ses));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('¡Entendido!')).bottom, lessThanOrEqualTo(300));
      await tester.tap(find.text('¡Entendido!'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Cómo se juega el Duelo'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('el flag del tutorial del Duelo se guarda y es por usuario', () async {
    final s = SettingsProvider();
    expect(s.duelTutorialSeen, isFalse);
    await s.markDuelTutorialSeen();
    final again = SettingsProvider();
    await again.load();
    expect(again.duelTutorialSeen, isTrue);
    await again.switchUser('otro');
    expect(again.duelTutorialSeen, isFalse);
  });

  // -------------------------------------------------------------- invitado

  group('pantalla del invitado (arena espejada)', () {
    /// Anfitrión sin pantalla que alimenta al invitado.
    final hostMatchFor = <_Session, DuelMatch>{};

    Future<(DuelScreenState, _Session, DuelMatch)> openGuest(WidgetTester tester, Size s) async {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final ses = _Session()..guestPlays = false;
      final host = DuelMatch(playerMon: _hostMon, enemyMon: _guestMon, rng: math.Random(3));
      hostMatchFor[ses] = host;
      await tester.pumpWidget(_guestApp(await _seen(), ses));
      await tester.pump(const Duration(milliseconds: 50));
      return (tester.state<DuelScreenState>(find.byType(DuelScreen)), ses, host);
    }

    final ui = DuelUiState();

    /// Avanza la pantalla del invitado y el anfitrión sin pantalla a la vez.
    Future<void> pumpBoth(WidgetTester tester, _Session ses, DuelMatch host, double seconds) async {
      for (var i = 0; i < (seconds / 0.05).round(); i++) {
        ses.now += 0.05;
        final events = host.engine.step(0.05, DuelInput.none, ses.hostLink.guestInput());
        ses.hostLink.addEvents(events);
        ses.hostLink.maybePublish(0.05, host, ui);
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('antes del primer estado muestra "Conectando…"; luego juega', (tester) async {
      final (_, ses, host) = await openGuest(tester, const Size(844, 390));
      expect(find.text('Conectando con Ash…'), findsOneWidget);
      await pumpBoth(tester, ses, host, 0.5);
      expect(find.textContaining('Conectando'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('yo me veo a la izquierda con mi luchador y el rival a la derecha', (tester) async {
      final (st, ses, host) = await openGuest(tester, const Size(844, 390));
      await pumpBoth(tester, ses, host, 0.5);
      // Soy el invitado (Charmander): mi placa va a la izquierda.
      expect(tester.getCenter(find.text('CHARMANDER')).dx, lessThan(tester.getCenter(find.text('SQUIRTLE')).dx));
      // En el motor soy `enemy` (a la derecha), pero en pantalla me veo a la izquierda.
      final sprites = tester.widgetList<FighterSprite>(find.byType(FighterSprite)).toList();
      expect(sprites, hasLength(2));
      final mine = tester.getCenter(find.byWidget(sprites[1])); // enemy = yo
      final theirs = tester.getCenter(find.byWidget(sprites[0]));
      expect(mine.dx, lessThan(theirs.dx));
      expect(st.engine.enemy.x, greaterThan(st.engine.player.x), reason: 'el motor sigue en coordenadas del anfitrión');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('mis botones llegan al anfitrión y mi analógico se traduce a su sentido', (tester) async {
      final (st, ses, host) = await openGuest(tester, const Size(844, 390));
      await pumpBoth(tester, ses, host, 0.5);
      host.engine.player.x = 15;
      host.engine.enemy.x = 60;
      await pumpBoth(tester, ses, host, 0.3);
      final x0 = host.engine.enemy.x;
      // Arrastrar a la IZQUIERDA en pantalla = alejarme del rival = hacia la derecha del motor.
      final g = await tester.startGesture(tester.getCenter(find.byType(DuelJoystick)));
      await g.moveBy(const Offset(-44, 0));
      await pumpBoth(tester, ses, host, 0.5);
      expect(host.engine.enemy.x, greaterThan(x0), reason: 'a la izquierda de mi pantalla es la derecha del motor');
      await g.up();
      await pumpBoth(tester, ses, host, 0.2);

      host.engine.player.x = 50;
      host.engine.enemy.x = 58;
      await pumpBoth(tester, ses, host, 0.3);
      await tester.tap(find.text('PUÑO'));
      await pumpBoth(tester, ses, host, 0.4);
      expect(host.engine.player.hp, lessThan(host.engine.player.maxHp), reason: 'mi puñetazo llegó al anfitrión');
      expect(st.engine.player.hp, closeTo(host.engine.player.hp, 1), reason: 'y lo veo reflejado');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el resultado lo decide el anfitrión: sin Revancha para el invitado', (tester) async {
      final (_, ses, host) = await openGuest(tester, const Size(844, 390));
      ui
        ..showResult = true
        ..matchOver = true
        ..winner = 'enemy';
      host.playerWins = 0;
      host.enemyWins = 2;
      await pumpBoth(tester, ses, host, 0.6);
      expect(find.text('¡VICTORIA!'), findsOneWidget, reason: 'el invitado es el `enemy` del motor');
      expect(find.text('2 - 0 en rondas contra Ash'), findsOneWidget);
      expect(find.text('Revancha'), findsNothing);
      expect(find.text('Salir'), findsWidgets);

      ui.winner = 'player';
      await pumpBoth(tester, ses, host, 0.3);
      expect(find.text('DERROTA'), findsOneWidget);

      // La revancha la empieza el anfitrión: el invitado vuelve a la pelea.
      ui
        ..showResult = false
        ..matchOver = false
        ..winner = null;
      await pumpBoth(tester, ses, host, 0.3);
      expect(find.text('DERROTA'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('si el anfitrión desaparece, el invitado lo avisa', (tester) async {
      final (_, ses, host) = await openGuest(tester, const Size(844, 390));
      await pumpBoth(tester, ses, host, 0.5);
      // El anfitrión deja de publicar.
      for (var i = 0; i < 340; i++) {
        ses.now += 0.05;
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('SIN CONEXIÓN'), findsOneWidget);
      expect(find.text('Se perdió la conexión con Ash.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('640x300: sin overflow y los 5 botones dentro de la pantalla', (tester) async {
      final (_, ses, host) = await openGuest(tester, const Size(640, 300));
      await pumpBoth(tester, ses, host, 0.5);
      for (final t in ['PUÑO', 'PODERES', '¡ULTRA!', 'ESCUDO', 'ESQUIVAR']) {
        final r = tester.getRect(find.text(t));
        expect(r.right, lessThanOrEqualTo(640.5), reason: t);
        expect(r.bottom, lessThanOrEqualTo(300.5), reason: t);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
