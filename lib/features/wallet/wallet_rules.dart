import '../battle/battle_provider.dart' show BotDifficulty;

/// Reglas puras del monedero general (Pokédex + Batalla):
/// desbloqueos por ID y premio por victoria clásica.
class WalletRules {
  /// Primeros 30 libres; el resto se canjea con monedas.
  static bool isFree(int id) => id >= 1 && id <= 30;

  /// Precio por generación (IDs de PokeAPI).
  static int priceFor(int id) {
    if (isFree(id)) return 0;
    if (id <= 151) return 100;
    if (id <= 251) return 150;
    if (id <= 386) return 200;
    if (id <= 493) return 250;
    if (id <= 649) return 300;
    if (id <= 721) return 350;
    if (id <= 809) return 400;
    if (id <= 905) return 450;
    return 500;
  }

  /// Monedas por ganar una batalla clásica Vs Bot.
  static int coinsForClassicWin(BotDifficulty difficulty) => switch (
        difficulty) {
      BotDifficulty.easy => 30,
      BotDifficulty.normal => 50,
      BotDifficulty.hard => 80,
    };
}
