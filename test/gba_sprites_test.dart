import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/features/battle/gba/gba_sprites.dart';

const _trainersPath = 'assets/images/battle/trainers.png';
const _ballsPath = 'assets/images/battle/poke_balls.png';

Future<({Uint8List px, int w, int h})> _decode(String path, List<int> markers) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final img = (await codec.getNextFrame()).image;
  final px = Uint8List.fromList((await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List());
  GbaSprites.keyOut(px, markers);
  return (px: px, w: img.width, h: img.height);
}

int _opaque(({Uint8List px, int w, int h}) s, ui.Rect r) {
  var n = 0;
  for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
    for (var x = r.left.toInt(); x < r.right.toInt(); x++) {
      if (s.px[(y * s.w + x) * 4 + 3] != 0) n++;
    }
  }
  return n;
}

void main() {
  group('regiones', () {
    test('espalda de Red y Leaf: 5 cuadros de 64x64 con paso 65', () {
      final r0 = GbaSprites.trainerBack(female: false, frame: 0);
      expect(r0, const ui.Rect.fromLTWH(8, 967, 64, 64));
      final l4 = GbaSprites.trainerBack(female: true, frame: 4);
      expect(l4, const ui.Rect.fromLTWH(8 + 65 * 4, 1032, 64, 64));
    });

    test('el cuadro de lanzamiento se limita a 0..4', () {
      expect(GbaSprites.trainerBack(female: false, frame: 99), GbaSprites.trainerBack(female: false, frame: 4));
      expect(GbaSprites.trainerBack(female: false, frame: -3), GbaSprites.trainerBack(female: false, frame: 0));
    });

    test('Poké Ball roja: cerrada, abriéndose y abierta', () {
      expect(GbaSprites.ball(stage: 0), const ui.Rect.fromLTWH(34, 21, 12, 12));
      expect(GbaSprites.ball(stage: 1), const ui.Rect.fromLTWH(34, 38, 12, 13));
      expect(GbaSprites.ball(stage: 2), const ui.Rect.fromLTWH(34, 55, 12, 16));
    });

    test('entrenadores de frente: cantidades y elección estable', () {
      expect(GbaSprites.frontCount(0), 46); // comunes
      expect(GbaSprites.frontCount(1), 3); // Rival
      expect(GbaSprites.frontCount(2), 12); // líderes + Alto Mando
      expect(GbaSprites.trainerFront(tier: 1, seed: 7), GbaSprites.trainerFront(tier: 1, seed: 7));
      // La misma semilla en otra dificultad da otra fila.
      expect(GbaSprites.trainerFront(tier: 0, seed: 0).top, isNot(GbaSprites.trainerFront(tier: 2, seed: 0).top));
    });

    test('todos los entrenadores de frente caen dentro de la hoja (536x1400)', () {
      for (var tier = 0; tier < 3; tier++) {
        for (var s = 0; s < GbaSprites.frontCount(tier); s++) {
          final r = GbaSprites.trainerFront(tier: tier, seed: s);
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(536));
          expect(r.bottom, lessThanOrEqualTo(1400));
        }
      }
    });

    test('una semilla de cada nivel elige filas distintas dentro de su tipo', () {
      final tops = {for (var s = 0; s < 46; s++) GbaSprites.trainerFront(tier: 0, seed: s).top};
      expect(tops.length, 6); // 6 filas de entrenadores comunes
    });
  });

  group('marcadores', () {
    test('keyOut deja (0,0,0,0) solo en los colores marcador', () {
      final px = Uint8List.fromList([
        0xFF, 0x7F, 0x27, 0xFF, // naranja marcador
        0xFF, 0xA6, 0xA6, 0xFF, // rosa marcador
        0xC5, 0x39, 0x39, 0xFF, // sprite
      ]);
      GbaSprites.keyOut(px, [...GbaSprites.trainerMarkers, ...GbaSprites.ballMarkers]);
      expect(px.sublist(0, 4), [0, 0, 0, 0]);
      expect(px.sublist(4, 8), [0, 0, 0, 0]);
      expect(px.sublist(8, 12), [0xC5, 0x39, 0x39, 0xFF]);
    });
  });

  // Se salta si las hojas no están en el proyecto (la batalla se dibuja sin ellas).
  group('hojas reales',
      skip: (File(_trainersPath).existsSync() && File(_ballsPath).existsSync()) ? null : 'faltan las hojas de assets/images/battle', () {
    testWidgets('entrenadores: sin marcador, sin color en lo transparente y con dibujo', (tester) async {
      await tester.runAsync(() async {
        final s = await _decode(_trainersPath, GbaSprites.trainerMarkers);
        expect(s.w, 536);
        expect(s.h, 1400);

        bool dirty(ui.Rect r) {
          for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
            for (var x = r.left.toInt(); x < r.right.toInt(); x++) {
              final i = (y * s.w + x) * 4;
              final rgb = (s.px[i] << 16) | (s.px[i + 1] << 8) | s.px[i + 2];
              if (GbaSprites.trainerMarkers.contains(rgb) && s.px[i + 3] != 0) return true;
              if (s.px[i + 3] == 0 && rgb != 0) return true; // premultiplicado inválido
            }
          }
          return false;
        }

        for (final female in [false, true]) {
          for (var f = 0; f < GbaSprites.throwFrames; f++) {
            final r = GbaSprites.trainerBack(female: female, frame: f);
            expect(dirty(r), isFalse, reason: 'espalda ${female ? 'Leaf' : 'Red'} cuadro $f');
            expect(_opaque(s, r), greaterThan(300), reason: 'espalda ${female ? 'Leaf' : 'Red'} cuadro $f vacío');
            expect(_opaque(s, r), lessThan(64 * 64), reason: 'sin fondo transparente');
          }
        }
        for (var tier = 0; tier < 3; tier++) {
          for (var seed = 0; seed < GbaSprites.frontCount(tier); seed++) {
            final r = GbaSprites.trainerFront(tier: tier, seed: seed);
            expect(dirty(r), isFalse, reason: 'frente tier $tier #$seed');
            expect(_opaque(s, r), greaterThan(300), reason: 'frente tier $tier #$seed vacío');
          }
        }
      });
    });

    testWidgets('Poké Balls: las tres fases tienen dibujo y el fondo rosa desaparece', (tester) async {
      await tester.runAsync(() async {
        final s = await _decode(_ballsPath, GbaSprites.ballMarkers);
        expect(s.w, 192);
        expect(s.h, 100);
        for (var type = 0; type < 12; type++) {
          for (var stage = 0; stage < 3; stage++) {
            final r = GbaSprites.ball(type: type, stage: stage);
            expect(_opaque(s, r), greaterThan(40), reason: 'bola $type fase $stage vacía');
            for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
              for (var x = r.left.toInt(); x < r.right.toInt(); x++) {
                final i = (y * s.w + x) * 4;
                if (s.px[i + 3] == 0) expect(s.px[i] | s.px[i + 1] | s.px[i + 2], 0);
              }
            }
          }
        }
      });
    });

    testWidgets('load() deja ambas hojas listas', (tester) async {
      await tester.runAsync(GbaSprites.load);
      expect(GbaSprites.trainersLoaded, isTrue);
      expect(GbaSprites.ballsLoaded, isTrue);
      expect(GbaSprites.trainers!.width, 536);
      expect(GbaSprites.balls!.width, 192);
    });
  });
}
