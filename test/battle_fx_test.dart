import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/battle/battle_fx.dart';
import 'package:pokearena/features/battle/battle_provider.dart';

void main() {
  test('cada tipo cae en su forma de proyectil', () {
    expect(moveShapeFor('fire'), MoveShape.flame);
    expect(moveShapeFor('water'), MoveShape.drop);
    expect(moveShapeFor('electric'), MoveShape.bolt);
    expect(moveShapeFor('grass'), MoveShape.leaf);
    expect(moveShapeFor('ice'), MoveShape.shard);
    expect(moveShapeFor('rock'), MoveShape.rock);
    expect(moveShapeFor('flying'), MoveShape.wind);
    expect(moveShapeFor('psychic'), MoveShape.orb);
    expect(moveShapeFor('normal'), MoveShape.star);
    expect(moveShapeFor('FIRE'), MoveShape.flame);
  });

  test('reacción del defensor según el resultado', () {
    expect(
        defenderReaction(miss: true, crit: false, effectiveness: 1.0),
        '¡Fallo!');
    expect(
        defenderReaction(miss: false, crit: true, effectiveness: 1.0),
        contains('crítico'));
    expect(
        defenderReaction(miss: false, crit: false, effectiveness: 2.0),
        '¡Súper efectivo!');
    expect(
        defenderReaction(miss: false, crit: false, effectiveness: 0.0),
        isNotEmpty);
  });

  test('balance alarga la pelea (más PS, menos daño)', () {
    expect(BattleProvider.hpMultiplier, greaterThan(1.0));
    expect(BattleProvider.damageScale, lessThan(1.0));
    final b = BattleProvider(PokeApiService());
    // HP base 50 → con multiplicador queda por encima.
    expect(BattleProvider.hpMultiplier * 50, greaterThan(50));
    expect(b.playerPotions, 2);
  });
}
