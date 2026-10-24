import '../../core/services/sound_service.dart';

/// Fachada de sonido de batalla (usa el servicio global con tonos).
/// Cada golpe suena en 2 fases: silbido al LANZAR + impacto al RECIBIR
/// (~320ms después, cuando el proyectil choca en la animación).
class BattleSound {
  static void toggle(bool v) => SoundService.toggle(v);

  static void playHit(double eff, bool crit, bool ult,
      {String moveType = 'normal', int power = 40}) {
    if (!SoundService.enabled) return;
    // Fase 1: quien ataca lanza.
    SoundService.playWhoosh(moveType);
    // Fase 2: impacto (~400ms, con el choque visual del proyectil).
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!SoundService.enabled) return;
      SoundService.playMove(moveType, power: power);
      if (ult) {
        SoundService.ultimate();
      } else if (crit) {
        SoundService.crit();
      } else if (eff >= 2.0) {
        SoundService.superHit();
      } else if (eff == 0.0) {
        SoundService.miss();
      }
    });
  }

  static void playMiss() {
    if (!SoundService.enabled) return;
    SoundService.playWhoosh('normal');
    Future.delayed(const Duration(milliseconds: 400), () {
      if (SoundService.enabled) SoundService.miss();
    });
  }
  static void playKo() => SoundService.ko();
  static void playPotion() => SoundService.potion();
  static void playSelect() => SoundService.select();
}
