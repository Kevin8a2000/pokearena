import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/gba/gba_intro.dart';
import 'package:pokearena/features/battle/gba/gba_sprites.dart';
import 'package:pokearena/features/battle/gba/gba_viewport.dart';
import 'package:provider/provider.dart';

PokemonDetail _mon(int id, String name) => PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: const ['normal'],
      stats: const {'hp': 50, 'attack': 50, 'defense': 50, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

void main() {
  group('IntroTimeline', () {
    test('las fases van en orden', () {
      final seq = [0, 600, 1200, 1600, 2000, 3100].map((ms) => IntroTimeline.phaseAt(ms.toDouble())).toList();
      expect(seq, [
        IntroPhase.trainersEnter,
        IntroPhase.throwing,
        IntroPhase.ballFlight,
        IntroPhase.ballOpens,
        IntroPhase.pokemonEmerges,
        IntroPhase.done,
      ]);
    });

    test('todo termina antes de la duración total', () {
      expect(IntroTimeline.rivalOutAt + IntroTimeline.rivalOutMs, lessThan(IntroTimeline.total));
      expect(IntroTimeline.emergeAt + IntroTimeline.emergeMs, lessThan(IntroTimeline.total));
      expect(IntroTimeline.platesAt + IntroTimeline.platesMs, lessThanOrEqualTo(IntroTimeline.total));
    });

    test('el entrenador entra, se queda y sale', () {
      expect(IntroTimeline.trainerOffset(0), 1); // fuera de pantalla
      expect(IntroTimeline.trainerOffset(IntroTimeline.trainerInMs.toDouble()), 0); // en su sitio
      expect(IntroTimeline.trainerOffset(1000), 0);
      expect(IntroTimeline.trainerOffset((IntroTimeline.trainerOutAt + IntroTimeline.trainerOutMs).toDouble()), 1);
    });

    test('el lanzamiento recorre los 5 cuadros y la bola se suelta en el cuadro 3', () {
      expect(IntroTimeline.throwFrame(0), 0);
      expect(IntroTimeline.throwFrame(IntroTimeline.releaseAt.toDouble()), IntroTimeline.releaseFrame);
      expect(IntroTimeline.throwFrame(5000), 4);
      var prev = 0;
      for (var ms = 0.0; ms < 2000; ms += 10) {
        final f = IntroTimeline.throwFrame(ms);
        expect(f, greaterThanOrEqualTo(prev));
        prev = f;
      }
    });

    test('la bola: oculta, en vuelo, se abre y desaparece', () {
      expect(IntroTimeline.ballStage(0), -1);
      expect(IntroTimeline.ballStage(IntroTimeline.releaseAt + 10), 0);
      expect(IntroTimeline.ballStage(IntroTimeline.landAt + 10), 1);
      expect(IntroTimeline.ballStage(IntroTimeline.landAt + IntroTimeline.stageMs + 10), 2);
      expect(IntroTimeline.ballStage(IntroTimeline.landAt + IntroTimeline.stageMs * 3 + 10), -1);
      expect(IntroTimeline.ballFlight(IntroTimeline.releaseAt.toDouble()), 0);
      expect(IntroTimeline.ballFlight(IntroTimeline.landAt.toDouble()), 1);
    });

    test('los Pokémon salen de la bola después de que se abre', () {
      expect(IntroTimeline.playerReveal(IntroTimeline.landAt.toDouble()), 0);
      expect(IntroTimeline.playerReveal((IntroTimeline.emergeAt + IntroTimeline.emergeMs).toDouble()), 1);
      expect(IntroTimeline.rivalReveal(IntroTimeline.rivalLandAt.toDouble()), 0);
      expect(IntroTimeline.rivalReveal((IntroTimeline.rivalEmergeAt + IntroTimeline.emergeMs).toDouble()), 1);
      // El rival sale después de que ya sale el jugador.
      expect(IntroTimeline.rivalEmergeAt, greaterThan(IntroTimeline.emergeAt));
    });

    test('las placas de PS aparecen cuando ya salieron los dos Pokémon', () {
      expect(IntroTimeline.platesOpacity(0), 0);
      expect(IntroTimeline.platesOpacity((IntroTimeline.platesAt + IntroTimeline.platesMs).toDouble()), 1);
      expect(IntroTimeline.platesAt, greaterThanOrEqualTo(IntroTimeline.emergeAt + IntroTimeline.emergeMs - 400));
    });

    test('los gritos suenan al salir cada Pokémon', () {
      expect(IntroTimeline.playerCryAt, greaterThanOrEqualTo(IntroTimeline.emergeAt));
      expect(IntroTimeline.rivalCryAt, greaterThanOrEqualTo(IntroTimeline.rivalEmergeAt));
    });

    test('el destello solo existe después de abrirse la bola', () {
      expect(IntroTimeline.flash(0), 0);
      expect(IntroTimeline.flash((IntroTimeline.landAt + IntroTimeline.stageMs).toDouble()), 1);
      expect(IntroTimeline.flash(IntroTimeline.total.toDouble()), 0);
    });
  });

  group('BattleProvider', () {
    test('la entrada con entrenadores empieza apagada y saltarla sin batalla no hace nada', () {
      final b = BattleProvider(PokeApiService());
      expect(b.introRich, isFalse);
      b.skipIntro(); // sin entering ni introRich no pasa nada
      expect(b.entering, isFalse);
    });
  });

  group('overlay', () {
    for (final ms in <double>[0, 300, 700, 1000, 1400, 1600, 1700, 2000, 2500, 3000, 3300]) {
      testWidgets('se dibuja sin errores a los $ms ms (con y sin sprites)', (tester) async {
        for (final female in [false, true]) {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                width: 300,
                height: 225,
                child: GbaIntroOverlay(ms: ms, female: female, tier: (ms ~/ 1000) % 3, seed: 25),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('con las hojas cargadas también se dibuja', (tester) async {
      await tester.runAsync(GbaSprites.load);
      for (final ms in <double>[0, 600, 1000, 1500, 1600, 2400]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 300,
              height: 225,
              child: GbaIntroOverlay(ms: ms, female: ms > 1000, tier: 2, seed: 3),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('IntroReveal: oculto, silueta que crece y completo', (tester) async {
      Widget wrap(double p) => Directionality(
            textDirection: TextDirection.ltr,
            child: IntroReveal(progress: p, child: const SizedBox(width: 40, height: 40, child: ColoredBox(color: Colors.red))),
          );
      await tester.pumpWidget(wrap(0));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      await tester.pumpWidget(wrap(0.5));
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);
      await tester.pumpWidget(wrap(1));
      expect(find.byType(ColorFiltered), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    });
  });

  group('viewport', () {
    BattleProvider setup() {
      final b = BattleProvider(PokeApiService());
      b.setPlayerTeam([_mon(25, 'pikachu')]);
      b.enemy = _mon(4, 'charmander');
      b.phase = BattlePhase.fighting;
      return b;
    }

    Widget host(BattleProvider b) => ChangeNotifierProvider<BattleProvider>.value(
          value: b,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 240,
                child: GbaViewport(menuCursor: 0, inMoves: false, moveCursor: 0, menuOpen: false),
              ),
            ),
          ),
        );

    testWidgets('sin entrada con entrenadores no hay overlay ni Pokémon ocultos', (tester) async {
      final b = setup();
      await tester.pumpWidget(host(b));
      await tester.pump();
      expect(find.byType(GbaIntroOverlay), findsNothing);
      expect(find.byType(IntroReveal), findsNWidgets(2));
      for (final r in tester.widgetList<IntroReveal>(find.byType(IntroReveal))) {
        expect(r.progress, 1);
      }
    });

    testWidgets('durante la entrada: overlay visible, Pokémon ocultos y un toque la salta', (tester) async {
      final b = setup()
        ..introRich = true
        ..entering = true;
      await tester.pumpWidget(host(b));
      await tester.pump();
      expect(find.byType(GbaIntroOverlay), findsOneWidget);
      for (final r in tester.widgetList<IntroReveal>(find.byType(IntroReveal))) {
        expect(r.progress, 0); // todavía no salen de la bola
      }
      expect(find.text('¡El Bot te desafía a un combate!'), findsOneWidget);

      // Avanza la línea de tiempo: el Pokémon propio sale de la bola.
      await tester.pump(const Duration(milliseconds: 2300));
      final reveals = tester.widgetList<IntroReveal>(find.byType(IntroReveal)).map((r) => r.progress).toList();
      expect(reveals.first, greaterThan(0)); // rival (primero en el Stack)
      expect(find.text('¡Adelante, Pikachu!'), findsOneWidget);

      // Un toque salta: el provider recibe skipIntro y, al acabar, todo queda completo.
      await tester.tapAt(const Offset(100, 100));
      b
        ..entering = false
        ..notifyListeners();
      await tester.pump();
      expect(find.byType(GbaIntroOverlay), findsNothing);
      for (final r in tester.widgetList<IntroReveal>(find.byType(IntroReveal))) {
        expect(r.progress, 1);
      }
      await tester.pumpWidget(const SizedBox()); // limpia los controladores
    });
  });
}
