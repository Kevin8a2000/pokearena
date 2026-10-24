import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/gba/gba_intro.dart';
import 'package:pokearena/features/battle/gba/gba_viewport.dart';
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

void main() {
  group('BallPop', () {
    test('la bola se abre, luego sale el Pokémon y al final desaparece', () {
      expect(BallPop.stage(0.1), 1);
      expect(BallPop.stage(0.4), 2);
      expect(BallPop.stage(0.8), -1);
    });

    test('el Pokémon sale después de abrirse la bola', () {
      expect(BallPop.reveal(0), 0);
      expect(BallPop.reveal(BallPop.emergeFrom), 0);
      expect(BallPop.reveal(0.55), greaterThan(0));
      expect(BallPop.reveal(1), 1);
    });

    test('el destello empieza tarde y se apaga', () {
      expect(BallPop.flash(0.1), 0);
      expect(BallPop.flash(0.2), 1);
      expect(BallPop.flash(1), 0);
    });
  });

  group('relevo a mitad del combate', () {
    BattleProvider setup({required bool rich}) {
      final b = BattleProvider(PokeApiService());
      b.setPlayerTeam([_mon(25, 'pikachu'), _mon(7, 'squirtle')]);
      b.enemy = _mon(4, 'charmander');
      b.phase = BattlePhase.fighting;
      b.introRich = rich;
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

    testWidgets('en la vista Normal el Pokémon nuevo sale de una Poké Ball', (tester) async {
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
      final reveals = tester.widgetList<IntroReveal>(find.byType(IntroReveal)).map((r) => r.progress).toList();
      expect(reveals.last, lessThan(1)); // el propio (segundo en el Stack) todavía está saliendo

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(GbaBallPopOverlay), findsNothing);
      for (final r in tester.widgetList<IntroReveal>(find.byType(IntroReveal))) {
        expect(r.progress, 1);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sin entrada de entrenadores (Online / 2.5D) no hay efecto de bola', (tester) async {
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

  group('entrenador elegido (Red / Leaf)', () {
    test('por defecto es Red y se guarda por usuario', () async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsProvider();
      await s.switchUser('ash');
      expect(s.trainerFemale, isFalse);
      await s.setTrainerFemale(true);
      expect(s.trainerFemale, isTrue);

      // Otro usuario no hereda la elección...
      final other = SettingsProvider();
      await other.switchUser('misty');
      expect(other.trainerFemale, isFalse);

      // ...y al volver, el primero la recupera.
      final again = SettingsProvider();
      await again.switchUser('ash');
      expect(again.trainerFemale, isTrue);
    });
  });
}
