import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/features/battle/battle_calculator.dart';
import 'package:pokearena/features/battle/battle_hints.dart';

BattleMove _mv(String name, String type, int power, {int pp = 20, int acc = 100, bool ult = false}) =>
    BattleMove(name: name, type: type, power: power, maxPp: pp, accuracy: acc, isUltimate: ult);

void main() {
  group('efectividad', () {
    test('niveles y textos por multiplicador', () {
      expect(effectivenessTier(0), EffectivenessTier.immune);
      expect(effectivenessTier(0.25), EffectivenessTier.weak);
      expect(effectivenessTier(0.5), EffectivenessTier.weak);
      expect(effectivenessTier(1), EffectivenessTier.normal);
      expect(effectivenessTier(2), EffectivenessTier.strong);
      expect(effectivenessTier(4), EffectivenessTier.strong);

      expect(effectivenessLabel(0), 'Sin efecto');
      expect(effectivenessLabel(0.5), 'Poco eficaz');
      expect(effectivenessLabel(1), 'Normal');
      expect(effectivenessLabel(2), '¡Muy eficaz!');
      expect(effectivenessLabel(4), '¡Muy eficaz!');
    });
  });

  group('moveScore', () {
    test('potencia × efectividad × STAB × precisión', () {
      final water = _mv('Pistola Agua', 'water', 60, acc: 100);
      // Sin STAB ni ventaja: 60.
      expect(moveScore(move: water, attackerTypes: const ['fire'], effectiveness: 1), 60);
      // Con STAB (×1.5): 90.
      expect(moveScore(move: water, attackerTypes: const ['water'], effectiveness: 1), 90);
      // STAB y súper eficaz: 180.
      expect(moveScore(move: water, attackerTypes: const ['water'], effectiveness: 2), 180);
      // La precisión resta: 60 × 0.5 = 30.
      expect(moveScore(move: _mv('Mala', 'water', 60, acc: 50), attackerTypes: const [], effectiveness: 1), 30);
    });

    test('el STAB no distingue mayúsculas', () {
      expect(moveScore(move: _mv('X', 'Water', 40), attackerTypes: const ['WATER'], effectiveness: 1), 60);
    });
  });

  group('recommendedMove', () {
    final moves = [
      _mv('Placaje', 'normal', 40),
      _mv('Pistola Agua', 'water', 60),
      _mv('Hiperataque', 'normal', 90, acc: 90),
    ];

    test('elige el de mayor puntuación (efectividad + STAB)', () {
      final i = recommendedMove(
        moves: moves,
        ppLeft: const [30, 20, 10],
        effectiveness: const [1, 2, 1],
        attackerTypes: const ['water'],
      );
      expect(i, 1); // 60 × 2 × 1.5 = 180 contra 40 y 81
    });

    test('sin ventajas gana la potencia efectiva (precisión incluida)', () {
      final i = recommendedMove(
        moves: moves,
        ppLeft: const [30, 20, 10],
        effectiveness: const [1, 1, 1],
        attackerTypes: const [],
      );
      expect(i, 2); // 90 × 0.9 = 81 > 60 > 40
    });

    test('ignora los movimientos sin PP', () {
      final i = recommendedMove(
        moves: moves,
        ppLeft: const [30, 0, 10],
        effectiveness: const [1, 2, 1],
        attackerTypes: const ['water'],
      );
      expect(i, 2);
    });

    test('si no queda ningún PP no recomienda nada', () {
      expect(
        recommendedMove(moves: moves, ppLeft: const [0, 0, 0], effectiveness: const [1, 1, 1], attackerTypes: const []),
        isNull,
      );
    });

    test('nunca recomienda un golpe que no hace efecto', () {
      expect(
        recommendedMove(moves: [moves[0]], ppLeft: const [30], effectiveness: const [0], attackerTypes: const []),
        isNull,
      );
    });

    test('no recomienda el movimiento Z (se ofrece aparte)', () {
      final withZ = [...moves, _mv('Z', 'normal', 200, ult: true)];
      final i = recommendedMove(
        moves: withZ,
        ppLeft: const [30, 20, 10, 1],
        effectiveness: const [1, 1, 1, 1],
        attackerTypes: const [],
      );
      expect(i, isNot(3));
    });

    test('en un empate gana el de más potencia y luego el primero', () {
      final tie = [_mv('A', 'normal', 50), _mv('B', 'normal', 100, acc: 50)]; // ambos valen 50
      expect(
        recommendedMove(moves: tie, ppLeft: const [20, 20], effectiveness: const [1, 1], attackerTypes: const []),
        1, // misma puntuación: más potencia
      );
      final same = [_mv('A', 'normal', 50), _mv('B', 'normal', 50)];
      expect(
        recommendedMove(moves: same, ppLeft: const [20, 20], effectiveness: const [1, 1], attackerTypes: const []),
        0,
      );
    });

    test('lista vacía', () {
      expect(recommendedMove(moves: const [], ppLeft: const [], effectiveness: const [], attackerTypes: const []), isNull);
    });
  });

  group('PP', () {
    test('fracción entre 0 y 1', () {
      expect(ppFraction(10, 20), 0.5);
      expect(ppFraction(0, 20), 0);
      expect(ppFraction(25, 20), 1);
      expect(ppFraction(5, 0), 0);
    });

    test('quedan pocos PP con 0 o hasta el 25 %', () {
      expect(ppLow(0, 20), isTrue);
      expect(ppLow(5, 20), isTrue);
      expect(ppLow(6, 20), isFalse);
      expect(ppLow(20, 20), isFalse);
    });
  });
}
