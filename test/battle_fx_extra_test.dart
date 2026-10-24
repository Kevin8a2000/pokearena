import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/battle/battle_fx_extra.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/gba/gba_sprites.dart';
import 'package:pokearena/features/battle/gba/gba_viewport.dart';
import 'package:pokearena/core/theme/type_colors.dart';
import 'package:provider/provider.dart';

const _fxPath = 'assets/images/battle/attack_fx.png';
const _allTypes = [
  'normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'flying', 'poison',
  'ground', 'rock', 'bug', 'ghost', 'steel', 'psychic', 'dragon', 'dark', 'fairy', //
];

PokemonDetail _mon(int id, String name) => PokemonDetail(
      id: id,
      name: name,
      height: 10,
      weight: 100,
      types: const ['normal'],
      stats: const {'hp': 50, 'attack': 50, 'defense': 50, 'special-attack': 50, 'special-defense': 50, 'speed': 50},
    );

void main() {
  group('ScreenShake', () {
    double amp({int damage = 30, int max = 100, bool crit = false, double eff = 1, bool miss = false}) =>
        ScreenShake.amplitude(damage: damage, defenderMaxHp: max, crit: crit, effectiveness: eff, miss: miss);

    test('un fallo o 0 de daño no sacude', () {
      expect(amp(miss: true), 0);
      expect(amp(damage: 0), 0);
    });

    test('crece con el daño, el crítico y la súper efectividad', () {
      expect(amp(damage: 80), greaterThan(amp(damage: 10)));
      expect(amp(crit: true), greaterThan(amp()));
      expect(amp(eff: 2), greaterThan(amp()));
      expect(amp(eff: 0.5), lessThan(amp()));
    });

    test('nunca es negativa ni pasa de 12 px, ni con PS máximos 0', () {
      expect(amp(damage: 9999, crit: true, eff: 4), lessThanOrEqualTo(12));
      expect(amp(max: 0), greaterThanOrEqualTo(0));
    });

    test('solo tiembla durante el impacto y se amortigua', () {
      expect(ScreenShake.offset(0.2, 8), Offset.zero);
      expect(ScreenShake.offset(0.95, 8), Offset.zero);
      expect(ScreenShake.offset(0.6, 0), Offset.zero);
      final early = ScreenShake.offset(0.52, 8).distance;
      final late = ScreenShake.offset(0.9, 8).distance;
      expect(early, greaterThan(late));
      expect(ScreenShake.offset(0.55, 8).distance, lessThanOrEqualTo(8 * 1.2));
    });
  });

  group('banner y ráfaga', () {
    test('texto de efectividad', () {
      expect(effectivenessBanner(effectiveness: 2, miss: false, crit: false), '¡Es muy eficaz!');
      expect(effectivenessBanner(effectiveness: 0.5, miss: false, crit: false), 'No es muy eficaz...');
      expect(effectivenessBanner(effectiveness: 0, miss: false, crit: false), 'No afecta...');
      expect(effectivenessBanner(effectiveness: 1, miss: false, crit: false), isNull);
      expect(effectivenessBanner(effectiveness: 1, miss: false, crit: true), '¡Golpe crítico!');
      expect(effectivenessBanner(effectiveness: 2, miss: false, crit: true), '¡Golpe crítico! ¡Es muy eficaz!');
      expect(effectivenessBanner(effectiveness: 2, miss: true, crit: false), isNull);
    });

    test('más partículas con crítico y súper efectividad', () {
      expect(burstCount(crit: false, effectiveness: 1), 6);
      expect(burstCount(crit: true, effectiveness: 2), greaterThan(burstCount(crit: false, effectiveness: 1)));
      expect(burstCount(crit: false, effectiveness: 0.5), lessThan(6));
      expect(burstCount(crit: true, effectiveness: 4), lessThanOrEqualTo(12));
    });
  });

  group('tabla de efectos', () {
    test('hay sprites para los 18 tipos y todos caen dentro de la hoja (948x835)', () {
      for (final t in _allTypes) {
        final list = GbaFx.forType(t);
        expect(list, isNotEmpty, reason: t);
        for (final r in list) {
          expect(r.left, greaterThanOrEqualTo(0), reason: t);
          expect(r.top, greaterThanOrEqualTo(0), reason: t);
          expect(r.right, lessThanOrEqualTo(948), reason: t);
          expect(r.bottom, lessThanOrEqualTo(835), reason: t);
        }
      }
    });

    test('un tipo desconocido usa el de "normal"', () {
      expect(GbaFx.forType('cosmico'), GbaFx.forType('normal'));
      expect(GbaFx.forType('FIRE'), GbaFx.forType('fire')); // sin importar mayúsculas
    });

    test('el fuego tiene secuencia de 3 cuadros y partículas aparte', () {
      expect(GbaFx.sequenceFor('fire').length, 3);
      expect(GbaFx.particlesFor('fire').length, GbaFx.forType('fire').length - 3);
      expect(GbaFx.sequenceFor('water'), isEmpty);
      expect(GbaFx.particlesFor('water'), GbaFx.forType('water'));
    });

    test('todos los tipos de PokéArena tienen efecto', () {
      for (final t in typeColors.keys) {
        expect(GbaFx.byType.containsKey(t), isTrue, reason: 'sin efecto para $t');
      }
    });
  });

  group('hoja real', skip: File(_fxPath).existsSync() ? null : 'falta $_fxPath', () {
    testWidgets('cada sprite elegido tiene dibujo, sin verde y sin color en lo transparente', (tester) async {
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(await File(_fxPath).readAsBytes());
        final img = (await codec.getNextFrame()).image;
        expect(img.width, 948);
        expect(img.height, 835);
        final px = Uint8List.fromList((await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List());
        GbaSprites.keyOut(px, GbaSprites.fxMarkers);

        for (final e in GbaFx.byType.entries) {
          for (final r in e.value) {
            var opaque = 0;
            for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
              for (var x = r.left.toInt(); x < r.right.toInt(); x++) {
                final i = (y * img.width + x) * 4;
                final rgb = (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
                expect(rgb == 0x22B14C && px[i + 3] != 0, isFalse, reason: '${e.key}: verde en ($x,$y)');
                if (px[i + 3] == 0) expect(rgb, 0, reason: '${e.key}: transparente con color en ($x,$y)');
                if (px[i + 3] != 0) opaque++;
              }
            }
            expect(opaque, greaterThan(15), reason: '${e.key} $r vacío');
          }
        }
      });
    });

    testWidgets('load() también deja lista la hoja de efectos', (tester) async {
      await tester.runAsync(GbaSprites.load);
      expect(GbaSprites.fxLoaded, isTrue);
    });

    for (final type in _allTypes) {
      testWidgets('la ráfaga de $type se dibuja sin errores en todo su recorrido', (tester) async {
        await tester.runAsync(GbaSprites.load);
        for (final t in [0.0, 0.2, 0.5, 0.8, 1.0]) {
          await tester.pumpWidget(
            Directionality(textDirection: TextDirection.ltr, child: Center(child: SpriteBurst(type: type, t: t, size: 110, count: 9))),
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  test('SpriteBurst sin hoja cargada no dibuja nada y no falla', () {
    // Sin cargar GbaSprites (otro isolate de test): el painter sale sin pintar.
    expect(const SpriteBurst(type: 'fire', t: 0.5, size: 100), isA<StatelessWidget>());
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

    testWidgets('sin ataque no hay ráfaga ni banner', (tester) async {
      await tester.pumpWidget(host(setup()));
      await tester.pump();
      expect(find.byType(SpriteBurst), findsNothing);
    });

    testWidgets('un golpe súper eficaz muestra la ráfaga, el banner y sacude la pantalla', (tester) async {
      final b = setup()
        ..attackSeq = 1
        ..lastAttacker = 'player'
        ..lastMoveType = 'fire'
        ..lastDamage = 40
        ..lastEffectiveness = 2.0
        ..lastCrit = true;
      await tester.pumpWidget(host(b));
      await tester.pump(); // arranca la animación de ataque (800 ms)
      await tester.pump(const Duration(milliseconds: 560)); // a ≈ 0.7: ventana de impacto
      expect(find.byType(SpriteBurst), findsOneWidget);
      expect(find.text('¡Golpe crítico! ¡Es muy eficaz!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('un fallo no muestra ráfaga ni banner', (tester) async {
      final b = setup()
        ..attackSeq = 1
        ..lastAttacker = 'enemy'
        ..lastMoveType = 'water'
        ..lastMiss = true;
      await tester.pumpWidget(host(b));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 560));
      expect(find.byType(SpriteBurst), findsNothing);
      expect(find.textContaining('eficaz'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
