import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/widgets/poke_image.dart';
import 'package:pokearena/features/duel/duel_engine.dart';
import 'package:pokearena/features/duel/duel_rig.dart';

RigPose _pose({
  DuelState state = DuelState.idle,
  double stateT = 0,
  double clock = 0,
  double speed = 0,
  bool guarding = false,
  double y = 0,
  double vy = 0,
}) =>
    poseFor(state: state, stateT: stateT, clock: clock, speed: speed, guarding: guarding, y: y, vy: vy);

void main() {
  group('poseFor (postura objetivo del cuerpo entero)', () {
    test('en reposo respira y se balancea suavemente', () {
      final a = _pose(clock: 0.0);
      final b = _pose(clock: 0.5);
      expect(a.sy, isNot(b.sy));
      for (var i = 0; i < 200; i++) {
        final p = _pose(clock: i * 0.05);
        expect(p.sy, inInclusiveRange(0.975, 1.025));
        expect(p.rot.abs(), lessThan(0.02));
        expect(p.dx, 0);
      }
    });

    test('al andar rebota con cada paso y se inclina hacia delante', () {
      var minDy = 0.0;
      for (var i = 0; i < 80; i++) {
        final p = _pose(speed: 1, clock: i * 0.02);
        if (p.dy < minDy) minDy = p.dy;
        expect(p.dy, lessThanOrEqualTo(0.0001), reason: 'solo sube');
        expect(p.rot, lessThan(0), reason: 'hacia delante');
      }
      expect(minDy, lessThan(-0.015), reason: 'hay rebote');
    });

    test('correr se inclina más y rebota más que andar', () {
      double maxBounce(double speed) {
        var m = 0.0;
        for (var i = 0; i < 100; i++) {
          m = math.min(m, _pose(speed: speed, clock: i * 0.01).dy);
        }
        return m;
      }

      expect(_pose(speed: 1.7, clock: 0.1).rot, lessThan(_pose(speed: 1, clock: 0.1).rot));
      expect(maxBounce(1.7), lessThan(maxBounce(1)));
    });

    test('el golpe: se echa atrás al prepararse y se lanza hacia delante al pegar', () {
      final windup = _pose(state: DuelState.attack, stateT: DuelTuning.meleeHitAt * 0.9);
      expect(windup.dx, greaterThan(0), reason: 'atrás');
      expect(windup.sx, lessThan(1));
      var minDx = 0.0, maxSx = 1.0, minRot = 0.0;
      for (var i = 0; i < 30; i++) {
        final p = _pose(state: DuelState.attack, stateT: DuelTuning.meleeHitAt + i * 0.01);
        minDx = math.min(minDx, p.dx);
        maxSx = math.max(maxSx, p.sx);
        minRot = math.min(minRot, p.rot);
      }
      expect(minDx, lessThan(-0.1), reason: 'se lanza');
      expect(maxSx, greaterThan(1.08), reason: 'se estira');
      expect(minRot, lessThan(-0.1), reason: 'inclina hacia delante');
    });

    test('en el aire se estira al subir y se recoge al caer', () {
      final up = _pose(y: 6, vy: 60);
      final down = _pose(y: 6, vy: -60);
      expect(up.sy, greaterThan(down.sy));
      expect(up.sx, lessThan(down.sx));
    });

    test('bloqueo se agacha; esquivar estira; deslizar aplasta; golpe retrocede', () {
      expect(_pose(guarding: true).sy, lessThan(0.95));
      expect(_pose(state: DuelState.dodge).sx, greaterThan(1.1));
      expect(_pose(state: DuelState.slide).sy, lessThan(0.7));
      final hurt = _pose(state: DuelState.hurt, stateT: 0.02);
      expect(hurt.dx, greaterThan(0));
      expect(hurt.rot, greaterThan(0));
      expect(_pose(state: DuelState.hurt, stateT: DuelTuning.hitStun).dx, closeTo(0, 0.001));
    });

    test('la horda empuja con cada disparo y el ULTRA crece', () {
      var lo = 9.0, hi = -9.0;
      for (var i = 0; i < 40; i++) {
        final p = _pose(state: DuelState.skill, stateT: 0.15 + i * 0.01);
        lo = math.min(lo, p.dx);
        hi = math.max(hi, p.dx);
      }
      expect(hi - lo, greaterThan(0.015), reason: 'pulsa al ritmo de los disparos');
      expect(_pose(state: DuelState.ultra, stateT: 0.4).sx, greaterThan(1.03));
    });

    test('nunca deforma de forma extrema: escalas e inclinaciones acotadas y finitas', () {
      for (final s in DuelState.values) {
        for (var i = 0; i < 40; i++) {
          final p = _pose(
            state: s,
            stateT: i * 0.04,
            clock: i * 0.13,
            speed: (i % 5) * 0.4,
            guarding: i % 7 == 0,
            y: i % 4 == 0 ? 5 : 0,
            vy: i % 2 == 0 ? 30 : -30,
          );
          for (final v in [p.dx, p.dy, p.sx, p.sy, p.rot]) {
            expect(v.isFinite, isTrue, reason: '$s $i');
          }
          expect(p.sx, inInclusiveRange(0.8, 1.3), reason: '$s sx');
          expect(p.sy, inInclusiveRange(0.6, 1.25), reason: '$s sy');
          expect(p.rot.abs(), lessThan(0.3), reason: '$s rot');
          expect(p.dx.abs(), lessThan(0.25), reason: '$s dx');
        }
      }
    });
  });

  group('Spring / FighterAnim (movimiento natural)', () {
    test('el muelle converge a su objetivo sin dispararse', () {
      final s = Spring(0);
      var maxPos = 0.0;
      for (var i = 0; i < 400; i++) {
        s.step(1, 1 / 60);
        maxPos = math.max(maxPos, s.pos);
      }
      expect(s.pos, closeTo(1, 0.002));
      expect(s.vel.abs(), lessThan(0.01));
      expect(maxPos, lessThan(1.25), reason: 'rebota un poco, no se pasa mucho');
      expect(maxPos, greaterThan(1.0), reason: 'sí tiene algo de rebote natural');
    });

    test('es estable aunque el frame sea largo', () {
      final s = Spring(0);
      for (var i = 0; i < 100; i++) {
        s.step(1, 0.05);
        expect(s.pos.isFinite, isTrue);
        expect(s.pos.abs(), lessThan(3));
      }
      expect(s.pos, closeTo(1, 0.01));
    });

    test('no salta de golpe: la postura se acerca poco a poco', () {
      final a = FighterAnim();
      const target = RigPose(dx: -0.17, sx: 1.13, sy: 0.93, rot: -0.17);
      a.step(target, 1 / 60, snappy: true);
      expect(a.pose.dx, greaterThan(target.dx), reason: 'aún no ha llegado');
      expect(a.pose.dx, lessThan(0));
      for (var i = 0; i < 60; i++) {
        a.step(target, 1 / 60, snappy: true);
      }
      expect(a.pose.dx, closeTo(target.dx, 0.01));
      expect(a.pose.sx, closeTo(target.sx, 0.01));
    });

    test('al volver a reposo se asienta con una pequeña oscilación', () {
      final a = FighterAnim();
      const strike = RigPose(dx: -0.17, sx: 1.13);
      for (var i = 0; i < 30; i++) {
        a.step(strike, 1 / 60, snappy: true);
      }
      var crossed = false;
      for (var i = 0; i < 90; i++) {
        a.step(RigPose.neutral, 1 / 60);
        if (a.pose.dx > 0.0005) crossed = true;
      }
      expect(crossed, isTrue, reason: 'se pasa un poco antes de asentarse');
      expect(a.pose.dx.abs(), lessThan(0.01));
    });

    test('al aterrizar se aplasta un instante', () {
      final a = FighterAnim();
      for (var i = 0; i < 60; i++) {
        a.step(RigPose.neutral, 1 / 60, y: 10);
      }
      var minSy = 1.0;
      for (var i = 0; i < 30; i++) {
        a.step(RigPose.neutral, 1 / 60, y: 0);
        minSy = math.min(minSy, a.pose.sy);
      }
      expect(minSy, lessThan(0.97));
      expect(a.pose.sy, closeTo(1, 0.03), reason: 'y se recupera');
    });
  });

  group('FighterSprite', () {
    testWidgets('mueve la imagen ENTERA: una sola copia, sin recortes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: FighterSprite(
              size: 120,
              pose: RigPose(dx: -0.1, sx: 1.1, sy: 0.9, rot: -0.15),
              child: PokeImage(id: 1, kind: PokeSpriteKind.artwork, width: 120, height: 120, filterQuality: FilterQuality.high),
            ),
          ),
        ),
      );
      expect(find.byType(PokeImage), findsOneWidget, reason: 'nada de copias recortadas');
      expect(find.byType(ClipRect), findsNothing);
      expect(find.byType(ClipPath), findsNothing);
      expect(tester.getSize(find.byType(FighterSprite)), const Size(120, 120));
      expect(tester.takeException(), isNull);
    });

    testWidgets('conserva la proporción: la escala es uniforme en reposo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: FighterSprite(size: 100, pose: RigPose.neutral, child: SizedBox(width: 100, height: 100, child: ColoredBox(color: Colors.green)))),
        ),
      );
      final t = tester.widget<Transform>(find.descendant(of: find.byType(FighterSprite), matching: find.byType(Transform)).first);
      expect(t.transform.getMaxScaleOnAxis(), closeTo(1, 1e-9));
    });

    testWidgets('pasa por todas las posturas sin errores', (tester) async {
      for (final s in DuelState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: FighterSprite(size: 100, pose: _pose(state: s, stateT: 0.1, clock: 0.5), child: const SizedBox(width: 100, height: 100, child: ColoredBox(color: Colors.green)))),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$s');
      }
    });
  });
}
