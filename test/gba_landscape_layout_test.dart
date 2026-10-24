import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/gba/gba_controls.dart';
import 'package:pokearena/features/battle/gba/gba_emulator_screen.dart';
import 'package:pokearena/features/battle/gba/gba_touch_menu.dart';
import 'package:pokearena/features/battle/gba/gba_viewport.dart';
import 'package:provider/provider.dart';

PokemonDetail _mon(int id, String name) => PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: const ['water'],
      stats: const {'hp': 50, 'attack': 50, 'defense': 50, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

const _sizes = [Size(844, 390), Size(800, 360), Size(700, 320), Size(640, 300), Size(1024, 600)];

void main() {
  group('GbaLandscapeLayout.compute', () {
    test('la escena ocupa toda el área disponible', () {
      for (final s in _sizes) {
        final l = GbaLandscapeLayout.compute(s);
        expect(l.viewport, Offset.zero & s, reason: '$s');
        // El lienzo de diseño escalado cubre exactamente el área (sin deformar).
        expect(l.designW * l.scale, closeTo(s.width, 0.01), reason: '$s');
        expect(l.designH * l.scale, closeTo(s.height, 0.01), reason: '$s');
      }
    });

    test('en pantallas alargadas el lienzo se ensancha y mantiene el alto base', () {
      final l = GbaLandscapeLayout.compute(const Size(844, 390));
      expect(l.designH, closeTo(GbaLandscapeLayout.baseH, 0.01));
      expect(l.designW, closeTo(844 / (390 / 270), 0.01));
      expect(l.designW, greaterThan(GbaLandscapeLayout.baseW));
      expect(l.scale, closeTo(390 / 270, 0.0001));
    });

    test('en una pantalla 4:3 el lienzo es el base', () {
      final l = GbaLandscapeLayout.compute(const Size(800, 600));
      expect(l.designW, closeTo(GbaLandscapeLayout.baseW, 0.01));
      expect(l.designH, closeTo(GbaLandscapeLayout.baseH, 0.01));
    });

    test('nunca se dibuja más pequeño que el lienzo base', () {
      for (final s in [..._sizes, const Size(500, 600), const Size(300, 200)]) {
        final l = GbaLandscapeLayout.compute(s);
        expect(l.designW, greaterThanOrEqualTo(GbaLandscapeLayout.baseW - 0.01), reason: '$s');
        expect(l.designH, greaterThanOrEqualTo(GbaLandscapeLayout.baseH - 0.01), reason: '$s');
      }
    });

    test('con un área diminuta no desaparece ni da tamaños negativos', () {
      final l = GbaLandscapeLayout.compute(const Size(200, 100));
      expect(l.viewport.width, greaterThan(0));
      expect(l.viewport.height, greaterThan(0));
      expect(l.scale, greaterThan(0));
    });
  });

  group('GbaEmulatorScreen', () {
    BattleProvider setup() {
      final b = BattleProvider(PokeApiService());
      b.setPlayerTeam([_mon(7, 'squirtle'), _mon(25, 'pikachu')]);
      b.enemyTeam = [_mon(4, 'charmander')];
      b.enemyTeamHp = [100];
      b.enemyTeamMaxHp = [100];
      b.phase = BattlePhase.fighting;
      return b;
    }

    Widget host(BattleProvider b) => ChangeNotifierProvider<BattleProvider>.value(
          value: b,
          child: const MaterialApp(home: GbaEmulatorScreen()),
        );

    for (final s in _sizes) {
      testWidgets('horizontal ${s.width.toInt()}x${s.height.toInt()}: escena a pantalla completa con el menú táctil encima y sin overflow', (tester) async {
        tester.view.physicalSize = s;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(host(setup()));
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Sin controles de consola: solo el menú táctil.
        expect(find.byType(GbaDPad), findsNothing);
        expect(find.byType(GbaABButtons), findsNothing);
        expect(find.byType(GbaRetroMenu), findsNothing);
        expect(find.byType(GbaTouchBar), findsOneWidget);

        // La escena llena toda la pantalla.
        final scene = tester.getRect(find.byType(GbaViewport));
        expect(scene.width, closeTo(s.width, 0.5));
        expect(scene.height, closeTo(s.height, 0.5));
        expect(scene.topLeft, Offset.zero);

        // Los 4 botones quedan abajo a la derecha, dentro de la escena.
        final bar = tester.getRect(find.byType(GbaTouchBar));
        expect(bar.bottom, closeTo(s.height, 0.5));
        expect(bar.right, lessThanOrEqualTo(s.width + 0.5));
        expect(tester.getCenter(find.text('LUCHAR')).dx, greaterThan(scene.width * 0.5));
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('vertical 420x800 conserva el diseño de siempre', (tester) async {
      const s = Size(420, 800);
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(setup()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('GAME BOY ADVANCE'), findsWidgets); // título arriba y abajo
      final scene = tester.getRect(find.byType(GbaViewport));
      expect(scene.width, closeTo(s.width - 16 - 8, 2)); // pantalla a lo ancho (menos el marco)
      expect(tester.getCenter(find.byType(GbaDPad)).dy, greaterThan(scene.bottom)); // carcasa debajo
      await tester.pumpWidget(const SizedBox());
    });


    testWidgets('la escena sigue a pantalla completa mientras el combate está ocupado', (tester) async {
      for (final s in const [Size(844, 390), Size(420, 800)]) {
        tester.view.physicalSize = s;
        tester.view.devicePixelRatio = 1.0;
        final b = setup();
        await tester.pumpWidget(host(b));
        await tester.pump();

        b
          ..busy = true
          ..notifyListeners();
        await tester.pump();
        final scene = tester.getRect(find.byType(GbaViewport));
        expect(scene.width, greaterThan(100), reason: '$s');
        expect(scene.height, greaterThan(100), reason: '$s');
        expect(scene.left.isNaN || scene.top.isNaN, isFalse, reason: '$s');
        if (s.width > s.height) expect(scene.size, s, reason: 'horizontal: llena la pantalla');
        expect(tester.takeException(), isNull);

        b
          ..busy = false
          ..notifyListeners();
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
      }
      addTearDown(tester.view.reset);
    });
  });
}
