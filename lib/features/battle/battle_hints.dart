import 'battle_calculator.dart';

/// Pistas para que el menú de ataques sea fácil de entender: cuánto le hace
/// un golpe al rival y cuál conviene. Lógica pura (sin Flutter) para probarla.

/// Qué tan eficaz es un movimiento contra el rival.
enum EffectivenessTier { immune, weak, normal, strong }

EffectivenessTier effectivenessTier(double e) {
  if (e <= 0) return EffectivenessTier.immune;
  if (e < 1) return EffectivenessTier.weak;
  if (e > 1) return EffectivenessTier.strong;
  return EffectivenessTier.normal;
}

/// Texto corto de la insignia de efectividad.
String effectivenessLabel(double e) => switch (effectivenessTier(e)) {
      EffectivenessTier.immune => 'Sin efecto',
      EffectivenessTier.weak => 'Poco eficaz',
      EffectivenessTier.normal => 'Normal',
      EffectivenessTier.strong => '¡Muy eficaz!',
    };

/// Puntuación esperada de un movimiento: potencia × efectividad × STAB (×1.5
/// si su tipo es uno de los tipos del atacante) × precisión.
double moveScore({
  required BattleMove move,
  required List<String> attackerTypes,
  required double effectiveness,
}) {
  final stab = attackerTypes.map((t) => t.toLowerCase()).contains(move.type.toLowerCase()) ? 1.5 : 1.0;
  return move.power * effectiveness * stab * (move.accuracy.clamp(0, 100) / 100);
}

/// Índice del movimiento más recomendable, o null si ninguno se puede usar.
/// Ignora los que no tienen PP; en un empate gana el de más potencia y luego
/// el primero. [ppLeft] y [effectiveness] van en el mismo orden que [moves].
int? recommendedMove({
  required List<BattleMove> moves,
  required List<int> ppLeft,
  required List<double> effectiveness,
  required List<String> attackerTypes,
}) {
  int? best;
  var bestScore = -1.0;
  for (var i = 0; i < moves.length; i++) {
    final pp = i < ppLeft.length ? ppLeft[i] : moves[i].maxPp;
    if (pp <= 0 || moves[i].isUltimate) continue;
    final e = i < effectiveness.length ? effectiveness[i] : 1.0;
    final score = moveScore(move: moves[i], attackerTypes: attackerTypes, effectiveness: e);
    final better = score > bestScore || (score == bestScore && best != null && moves[i].power > moves[best].power);
    if (better) {
      best = i;
      bestScore = score;
    }
  }
  // Un golpe inmune nunca se recomienda.
  if (best != null && best < effectiveness.length && effectiveness[best] <= 0) return null;
  return best;
}

/// Fracción de PP que queda (0..1).
double ppFraction(int left, int max) => max <= 0 ? 0 : (left / max).clamp(0.0, 1.0).toDouble();

/// ¿Quedan pocos PP? (0 o ≤ 25 %): la barra se pinta en rojo.
bool ppLow(int left, int max) => left <= 0 || ppFraction(left, max) <= 0.25;
