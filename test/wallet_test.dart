import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/features/wallet/wallet_provider.dart';
import 'package:pokearena/features/wallet/wallet_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('primeros 30 libres, resto con precio por generación', () {
    expect(WalletRules.isFree(1), isTrue);
    expect(WalletRules.isFree(30), isTrue);
    expect(WalletRules.isFree(31), isFalse);
    expect(WalletRules.priceFor(1), 0);
    expect(WalletRules.priceFor(151), 100);
    expect(WalletRules.priceFor(152), 150);
    expect(WalletRules.priceFor(386), 200);
    expect(WalletRules.priceFor(493), 250);
    expect(WalletRules.priceFor(649), 300);
    expect(WalletRules.priceFor(721), 350);
    expect(WalletRules.priceFor(809), 400);
    expect(WalletRules.priceFor(905), 450);
    expect(WalletRules.priceFor(1025), 500);
  });

  test('canje descuenta y desbloquea', () async {
    SharedPreferences.setMockInitialValues({});
    final w = WalletProvider();
    await w.switchUser('ash');
    expect(w.isUnlocked(94), isFalse);
    // Sin monedas no hay canje.
    expect(await w.unlock(94), isFalse);
    await w.addCoins(200);
    expect(await w.unlock(94), isTrue);
    expect(w.isUnlocked(94), isTrue);
    expect(w.coins, 100);
  });

  test('progreso persiste por usuario y migra la Horda', () async {
    SharedPreferences.setMockInitialValues({
      // Guardado viejo de la Horda: se conserva al migrar.
      'pokearena_horde_save_u_ash':
          '{"coins":70,"unlocked":[1,150],"maxRoundWon":4}',
    });
    final w = WalletProvider();
    await w.switchUser('ash');
    expect(w.coins, 70);
    expect(w.isUnlocked(150), isTrue);
    expect(w.isUnlocked(5), isTrue); // libre por rango

    final w2 = WalletProvider();
    await w2.switchUser('ash');
    expect(w2.coins, 70);
    expect(w2.isUnlocked(150), isTrue);

    final w3 = WalletProvider();
    await w3.switchUser('misty');
    expect(w3.coins, 0);
    expect(w3.isUnlocked(150), isFalse);
  });
}
