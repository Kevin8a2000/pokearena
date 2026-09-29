import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/models/type_relations.dart';
import 'package:pokearena/features/battle/battle_calculator.dart';

PokemonDetail _mon({
  required int id,
  required List<String> types,
  int attack = 60,
  int defense = 60,
  int hp = 60,
}) {
  return PokemonDetail(
    id: id,
    name: 'poke$id',
    height: 10,
    weight: 100,
    types: types,
    stats: {'attack': attack, 'defense': defense, 'hp': hp, 'speed': 50},
  );
}

void main() {
  test('daño neutro sin STAB es base', () {
    final atk = _mon(id: 1, types: ['grass']);
    final def = _mon(id: 2, types: ['normal']);
    final dmg = calculateDamage(
      attacker: atk,
      defender: def,
      move: const BattleMove(name: 'X', type: 'normal', power: 40),
      relations: const {},
    );
    expect(dmg, greaterThan(0));
  });

  test('STAB x1.5 aumenta el daño', () {
    final atk = _mon(id: 1, types: ['fire']);
    final def = _mon(id: 2, types: ['normal']);
    final noStab = calculateDamage(
      attacker: atk,
      defender: def,
      move: const BattleMove(name: 'X', type: 'normal', power: 40),
      relations: const {},
    );
    final stab = calculateDamage(
      attacker: atk,
      defender: def,
      move: const BattleMove(name: 'Y', type: 'fire', power: 40),
      relations: const {},
    );
    expect(stab, greaterThan(noStab));
  });

  test('super efectivo x2 duplica aprox', () {
    final atk = _mon(id: 1, types: ['water']);
    final def = _mon(id: 2, types: ['grass']);
    const rel = {
      'grass': TypeRelations(
        typeName: 'grass',
        doubleDamageFrom: ['fire'],
      ),
    };
    final neutral = calculateDamage(
      attacker: atk,
      defender: def,
      move: const BattleMove(name: 'N', type: 'normal', power: 40),
      relations: rel,
    );
    final superEff = calculateDamage(
      attacker: atk,
      defender: def,
      move: const BattleMove(name: 'F', type: 'fire', power: 40),
      relations: rel,
    );
    expect(superEff, greaterThanOrEqualTo(neutral * 2 - 2));
  });

  test('inmunidad x0 hace 0 daño', () {
    final atk = _mon(id: 1, types: ['normal']);
    final def = _mon(id: 2, types: ['ghost']);
    const rel = {
      'ghost': TypeRelations(
        typeName: 'ghost',
        noDamageFrom: ['normal'],
      ),
    };
    final dmg = calculateDamage(
      attacker: atk,
      defender: def,
      move: const BattleMove(name: 'N', type: 'normal', power: 40),
      relations: rel,
    );
    expect(dmg, 0);
  });

  test('doble debilidad x4', () {
    final def = _mon(id: 2, types: ['grass', 'bug']);
    const rel = {
      'grass': TypeRelations(
        typeName: 'grass',
        doubleDamageFrom: ['fire'],
      ),
      'bug': TypeRelations(
        typeName: 'bug',
        doubleDamageFrom: ['fire'],
      ),
    };
    expect(
      effectivenessFor(
        attackType: 'fire',
        defenderTypes: def.types,
        relations: rel,
      ),
      4.0,
    );
  });
}
