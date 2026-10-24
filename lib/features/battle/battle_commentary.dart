import 'dart:math';

/// Eventos de la batalla que el comentarista narra.
enum BattleEvent {
  start,
  normalHit,
  superEffective,
  notVeryEffective,
  noEffect,
  critical,
  miss,
  potion,
  ultimate,
  playerFaint,
  enemyFaint,
  playerLowHp,
  playerSwitch,
  enemySwitch,
  victory,
  defeat,
}

/// Frases del comentarista por evento. Función pura para poder probarla.
String commentaryFor(
  BattleEvent event, {
  String attacker = '',
  String move = '',
  String incoming = '',
  Random? random,
}) {
  final r = random ?? Random();
  String pick(List<String> options) =>
      options[r.nextInt(options.length)];

  return switch (event) {
    BattleEvent.start =>
      '¡Que comience el combate! ¡${attacker.isEmpty ? 'Luchadores' : attacker} contra $incoming!',
    BattleEvent.normalHit => '¡$attacker usa $move!',
    BattleEvent.superEffective => pick([
        '¡Súper efectivo! ¡Le dolió eso!',
        '¡Eficacísimo! ¡$attacker no se anda con juegos!',
      ]),
    BattleEvent.notVeryEffective => 'Mmm... no es muy efectivo.',
    BattleEvent.noEffect => '¡Oh! ¡No le afecta en absoluto!',
    BattleEvent.critical => pick([
        '¡Golpe crítico! ¡Increíble!',
        '¡Crítico! ¡Qué manera de pegar!',
      ]),
    BattleEvent.miss => pick([
        '¡Oh, no! ¡Falló el ataque!',
        '¡Falló! ¡Ni lo rozó!',
      ]),
    BattleEvent.potion =>
      '¡Poción! ¡$attacker recupera energías!',
    BattleEvent.ultimate =>
      '¡MOVIMIENTO Z! ¡Esto se va a poner feo!',
    BattleEvent.playerFaint =>
      '¡Oh, no! ¡$attacker se debilitó!',
    BattleEvent.enemyFaint =>
      '¡Rival fuera de combate! ¡Buen golpe!',
    BattleEvent.playerLowHp =>
      '¡Cuidado! ¡$attacker está en las últimas!',
    BattleEvent.playerSwitch =>
      '¡Adelante, $incoming! ¡Tú puedes!',
    BattleEvent.enemySwitch =>
      '¡El Bot envía a $incoming!',
    BattleEvent.victory => pick([
        '¡Victoria! ¡Eres imparable!',
        '¡Ganaste! ¡Qué batalla tan emocionante!',
      ]),
    BattleEvent.defeat => pick([
        'Derrota... ¡A entrenar más duro!',
        'Perdiste... ¡La próxima será la vencida!',
      ]),
  };
}
