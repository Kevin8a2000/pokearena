import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/battle/battle_fx_extra.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/gba/gba_intro.dart';
import 'package:pokearena/features/battle/gba/gba_sprites.dart';
import 'package:pokearena/features/battle/horde_fight_view.dart';
import 'package:pokearena/features/battle/horde_intro.dart';
import 'package:provider/provider.dart';

PokemonDetail _mon(int id, String name, [List<String> types = const ['normal']]) => PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: types,
      stats: const {'hp': 50, 'attack': 50, 'defense': 50, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

const _sizes = [Size(360, 300), Size(700, 420), Size(300, 200)];

void main() {
  group('geometría del escenario', () {
    test('los centros de los rivales caen dentro del escenario y de izquierda a derecha', () {
      for (final s in _sizes) {
        for (var n = 1; n <= 3; n++) {
          final centers = [for (var i = 0; i < n; i++) hordeCenter(i, n, s.width, s.height)];
          for (final c in centers) {
            expect(c.dx, inInclusiveRange(0, s.width), reason: '$n rivales en $s');
            expect(c.dy, inInclusiveRange(0, s.height), reason: '$n rivales en $s');
          }
          for (var i = 1; i < n; i++) {
            expect(centers[i].dx, greaterThan(centers[i - 1].dx));
          }
        }
      }
    });

    test('con un solo rival queda centrado y por encima del jugador', () {
      for (final s in _sizes) {
        final c = hordeCenter(0, 1, s.width, s.height);
        expect(c.dx, closeTo(s.width / 2, 0.001));
        expect(c.dy, lessThan(hordePlayerCenter(s.width, s.height).dy));
      }
    });

    test('el centro del jugador está abajo a la izquierda', () {
      for (final s in _sizes) {
        final c = hordePlayerCenter(s.width, s.height);
        expect(c.dx, lessThan(s.width / 2));
        expect(c.dy, greaterThan(s.height / 2));
        final size = hordePlayerSize(s.width, s.height);
        // El sprite (cuadrado de lado `size`) cabe dentro del escenario.
        expect(c.dx - size / 2, greaterThanOrEqualTo(0));
        expect(c.dy + size / 2, lessThanOrEqualTo(s.height));
      }
    });

    test('el centro coincide con la posición real del Align (child centrado por (w-size)/2)', () {
      // Align(x, y) coloca el hijo con left = (w - size)/2 * (1 + x).
      const w = 360.0, h = 300.0;
      final slot = hordeSlots(3)[0];
      final size = hordeEnemySize(slot, w, h);
      final left = (w - size) / 2 * (1 + slot.x);
      final top = (h - size) / 2 * (1 + slot.y);
      final c = hordeCenter(0, 3, w, h);
      expect(c.dx, closeTo(left + size / 2, 0.001));
      expect(c.dy, closeTo(top + size / 2, 0.001));
    });
  });

  group('HordeIntro', () {
    test('las bolas se lanzan escalonadas y cada rival sale después de la suya', () {
      for (var k = 1; k < 3; k++) {
        expect(HordeIntro.releaseAt(k), greaterThan(HordeIntro.releaseAt(k - 1)));
        expect(HordeIntro.emergeAt(k), greaterThan(HordeIntro.emergeAt(k - 1)));
      }
      for (var k = 0; k < 3; k++) {
        expect(HordeIntro.landAt(k), greaterThan(HordeIntro.releaseAt(k)));
        expect(HordeIntro.emergeAt(k), greaterThan(HordeIntro.landAt(k)));
        expect(HordeIntro.cryAt(k), greaterThan(HordeIntro.emergeAt(k)));
      }
    });

    test('la bola de cada rival: oculta, en vuelo, se abre y desaparece', () {
      const k = 1;
      expect(HordeIntro.ballStage(0, k), -1);
      expect(HordeIntro.ballStage(HordeIntro.releaseAt(k) + 10.0, k), 0);
      expect(HordeIntro.ballStage(HordeIntro.landAt(k) + 10.0, k), 1);
      expect(HordeIntro.ballStage(HordeIntro.landAt(k) + HordeIntro.stageMs + 10.0, k), 2);
      expect(HordeIntro.ballStage(HordeIntro.landAt(k) + HordeIntro.stageMs * 3 + 10.0, k), -1);
      expect(HordeIntro.ballFlight(HordeIntro.releaseAt(k).toDouble(), k), 0);
      expect(HordeIntro.ballFlight(HordeIntro.landAt(k).toDouble(), k), 1);
    });

    test('cada rival aparece del 0 al 1 después de abrirse su bola', () {
      for (var k = 0; k < 3; k++) {
        expect(HordeIntro.reveal(HordeIntro.landAt(k).toDouble(), k), 0);
        expect(HordeIntro.reveal((HordeIntro.emergeAt(k) + HordeIntro.emergeMs).toDouble(), k), 1);
        expect(HordeIntro.flash(HordeIntro.emergeAt(k).toDouble(), k), 1);
        expect(HordeIntro.flash(HordeIntro.emergeAt(k) + 400.0, k), 0);
      }
    });

    test('el entrenador rival entra, se queda mientras lanza y se va después de la última bola', () {
      for (var n = 1; n <= 3; n++) {
        expect(HordeIntro.rivalOffset(0, n), 1);
        expect(HordeIntro.rivalOffset(HordeIntro.rivalInMs.toDouble(), n), 0);
        expect(HordeIntro.rivalOffset(HordeIntro.releaseAt(n - 1).toDouble(), n), 0);
        expect(HordeIntro.rivalOffset((HordeIntro.rivalOutAt(n) + HordeIntro.rivalOutMs).toDouble(), n), 1);
      }
    });

    test('la entrada total no baja de la de GBA y termina después de la última aparición', () {
      for (var n = 1; n <= 5; n++) {
        final total = HordeIntro.total(n);
        expect(total, greaterThanOrEqualTo(IntroTimeline.total));
        expect(total, greaterThan(HordeIntro.emergeAt(n - 1) + HordeIntro.emergeMs));
      }
      expect(HordeIntro.total(5), greaterThanOrEqualTo(HordeIntro.total(1)));
    });

    test('el jugador reutiliza la línea de tiempo de GBA (sale antes que el último rival)', () {
      expect(IntroTimeline.emergeAt, lessThan(HordeIntro.emergeAt(2)));
    });
  });

  group('overlay', () {
    for (final n in [1, 2, 3]) {
      for (final ms in <double>[0, 400, 800, 1000, 1300, 1600, 1900, 2300, 2800, 3300]) {
        testWidgets('se dibuja sin errores con $n rivales a los $ms ms', (tester) async {
          const s = Size(360, 300);
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                width: s.width,
                height: s.height,
                child: HordeIntroOverlay(
                  ms: ms,
                  female: n == 2,
                  tier: n - 1,
                  seed: 7,
                  playerTarget: hordePlayerCenter(s.width, s.height),
                  enemyTargets: [for (var i = 0; i < n; i++) hordeCenter(i, n, s.width, s.height)],
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('con las hojas cargadas también se dibuja', (tester) async {
      await tester.runAsync(GbaSprites.load);
      for (final ms in <double>[0, 700, 1200, 1700, 2500]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 360,
              height: 300,
              child: HordeIntroOverlay(
                ms: ms,
                female: true,
                tier: 2,
                seed: 3,
                playerTarget: hordePlayerCenter(360, 300),
                enemyTargets: [for (var i = 0; i < 3; i++) hordeCenter(i, 3, 360, 300)],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('HordeFightView', () {
    BattleProvider setup({int enemies = 3, bool rich = false}) {
      final b = BattleProvider(PokeApiService());
      b.setPlayerTeam([_mon(25, 'pikachu'), _mon(7, 'squirtle')]);
      final team = [for (var i = 0; i < enemies; i++) _mon(4 + i, 'rival$i')];
      b.enemyTeam = team;
      b.enemyTeamHp = [for (final _ in team) 100];
      b.enemyTeamMaxHp = [for (final _ in team) 100];
      b.setHordeMode(true);
      b.phase = BattlePhase.fighting;
      b.introRich = rich;
      b.introTotalMs = HordeIntro.total(enemies);
      return b;
    }

    Widget host(BattleProvider b) => ChangeNotifierProvider<BattleProvider>.value(
          value: b,
          child: const MaterialApp(
            home: Scaffold(body: SizedBox(width: 420, height: 800, child: HordeFightView())),
          ),
        );

    for (final n in [1, 2, 3]) {
      testWidgets('sin entrada se monta con $n rivales y todo está visible', (tester) async {
        final b = setup(enemies: n);
        await tester.pumpWidget(host(b));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(HordeIntroOverlay), findsNothing);
        final reveals = tester.widgetList<IntroReveal>(find.byType(IntroReveal)).map((r) => r.progress).toList();
        expect(reveals.length, n + 1); // n rivales + el jugador
        expect(reveals.every((p) => p == 1), isTrue);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('durante la entrada: overlay visible, Pokémon ocultos y salen al avanzar', (tester) async {
      final b = setup(rich: true)..entering = true;
      await tester.pumpWidget(host(b));
      await tester.pump();
      expect(find.byType(HordeIntroOverlay), findsOneWidget);
      var reveals = tester.widgetList<IntroReveal>(find.byType(IntroReveal)).map((r) => r.progress).toList();
      expect(reveals.every((p) => p == 0), isTrue); // todavía nadie salió de su bola

      await tester.pump(const Duration(milliseconds: 2900));
      reveals = tester.widgetList<IntroReveal>(find.byType(IntroReveal)).map((r) => r.progress).toList();
      expect(reveals.every((p) => p > 0), isTrue); // ya salieron todos (rivales y jugador)

      // Al terminar `entering` queda todo completo y sin overlay.
      b
        ..entering = false
        ..notifyListeners();
      await tester.pump();
      expect(find.byType(HordeIntroOverlay), findsNothing);
      for (final r in tester.widgetList<IntroReveal>(find.byType(IntroReveal))) {
        expect(r.progress, 1);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('un golpe súper eficaz muestra ráfaga de sprites y banner, sin errores', (tester) async {
      await tester.runAsync(GbaSprites.load);
      final b = setup()
        ..attackSeq = 1
        ..lastAttacker = 'player'
        ..lastMoveType = 'fire'
        ..lastDamage = 40
        ..lastEffectiveness = 2.0
        ..lastCrit = true;
      await tester.pumpWidget(host(b));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 420)); // a ≈ 0.65 de 650 ms
      expect(find.byType(SpriteBurst), findsOneWidget);
      expect(find.text('¡Golpe crítico! ¡Es muy eficaz!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el rival ataca al jugador: también hay ráfaga y el jugador parpadea sin errores', (tester) async {
      final b = setup()
        ..attackSeq = 1
        ..lastAttacker = 'enemy'
        ..lastMoveType = 'water'
        ..lastDamage = 12
        ..lastEffectiveness = 1.0;
      await tester.pumpWidget(host(b));
      await tester.pump();
      for (final ms in [200, 150, 100, 100, 100]) {
        await tester.pump(Duration(milliseconds: ms));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('un fallo no muestra ráfaga ni banner', (tester) async {
      final b = setup()
        ..attackSeq = 1
        ..lastAttacker = 'player'
        ..lastMoveType = 'water'
        ..lastMiss = true;
      await tester.pumpWidget(host(b));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 420));
      expect(find.byType(SpriteBurst), findsNothing);
      expect(find.textContaining('eficaz'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('al relevar al jugador la Poké Ball se abre sobre su sitio', (tester) async {
      final b = setup(rich: true);
      await tester.pumpWidget(host(b));
      await tester.pump();
      expect(find.byType(GbaBallPopOverlay), findsNothing);

      b
        ..playerActive = 1
        ..notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(GbaBallPopOverlay), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(GbaBallPopOverlay), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sin entrada rica (vista moderna / Online) no hay efecto de relevo', (tester) async {
      final b = setup(rich: false);
      await tester.pumpWidget(host(b));
      await tester.pump();
      b
        ..playerActive = 1
        ..notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(GbaBallPopOverlay), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('BattleProvider', () {
    test('la entrada empieza apagada y su duración por defecto es la de GBA', () {
      final b = BattleProvider(PokeApiService());
      expect(b.introRich, isFalse);
      expect(b.introTotalMs, IntroTimeline.total);
    });
  });
}
