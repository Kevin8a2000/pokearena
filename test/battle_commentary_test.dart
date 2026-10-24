import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/features/battle/battle_commentary.dart';

void main() {
  test('todos los eventos tienen frase no vacía', () {
    for (final e in BattleEvent.values) {
      final phrase = commentaryFor(
        e,
        attacker: 'Pikachu',
        move: 'Impactrueno',
        incoming: 'Charmander',
        random: Random(7),
      );
      expect(phrase.isNotEmpty, isTrue, reason: 'evento $e sin frase');
    }
  });

  test('el golpe normal menciona atacante y movimiento', () {
    final phrase = commentaryFor(
      BattleEvent.normalHit,
      attacker: 'Pikachu',
      move: 'Impactrueno',
      random: Random(1),
    );
    expect(phrase, contains('Pikachu'));
    expect(phrase, contains('Impactrueno'));
  });

  test('inicio, cambio y poción mencionan al Pokémon', () {
    expect(
      commentaryFor(BattleEvent.start,
          attacker: 'Pikachu',
          incoming: 'Charmander',
          random: Random(1)),
      contains('Charmander'),
    );
    expect(
      commentaryFor(BattleEvent.playerSwitch,
          incoming: 'Bulbasaur', random: Random(1)),
      contains('Bulbasaur'),
    );
    expect(
      commentaryFor(BattleEvent.potion,
          attacker: 'Pikachu', random: Random(1)),
      contains('Pikachu'),
    );
  });
}
