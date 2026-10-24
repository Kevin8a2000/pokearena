import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pokearena/features/auth/auth_provider.dart';

Future<AuthProvider> _freshAuth() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AuthProvider(prefs);
}

void main() {
  test('validación de usuario y clave', () {
    expect(AuthProvider.validateUsername(''), isNotNull);
    expect(AuthProvider.validateUsername('ab'), isNotNull);
    expect(AuthProvider.validateUsername('a' * 17), isNotNull);
    expect(AuthProvider.validateUsername('ash k'), isNotNull);
    expect(AuthProvider.validateUsername('Ash_99'), isNull);
    expect(AuthProvider.validatePassword('123'), isNotNull);
    expect(AuthProvider.validatePassword('1234'), isNull);
    expect(AuthProvider.normalize(' Ash_99 '), 'ash_99');
  });

  test('registro entra y normaliza el usuario', () async {
    final auth = await _freshAuth();
    expect(await auth.register(' Ash ', '1234'), isTrue);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.currentUser, 'ash');
  });

  test('registro duplicado falla', () async {
    final auth = await _freshAuth();
    expect(await auth.register('ash', '1234'), isTrue);
    expect(await auth.register('ASH', 'abcd'), isFalse);
    expect(auth.error, contains('existe'));
  });

  test('login: ok, clave mala y usuario fantasma', () async {
    final auth = await _freshAuth();
    await auth.register('misty', 'agua123');
    await auth.logout();
    expect(auth.isLoggedIn, isFalse);
    expect(await auth.login('misty', 'mal'), isFalse);
    expect(auth.error, contains('incorrecta'));
    expect(await auth.login('brock', 'roca123'), isFalse);
    expect(auth.error, contains('no existe'));
    expect(await auth.login('MISTY', 'agua123'), isTrue);
  });

  test('la sesión persiste entre instancias', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = AuthProvider(prefs);
    await a.register('gary', 'rival123');
    final b = AuthProvider(prefs);
    await b.load();
    expect(b.isLoggedIn, isTrue);
    expect(b.currentUser, 'gary');
    await b.logout();
    final c = AuthProvider(prefs);
    await c.load();
    expect(c.isLoggedIn, isFalse);
  });

  test('misma clave, hash distinto por sal', () async {
    final auth = await _freshAuth();
    await auth.register('uno', 'clave123');
    await auth.register('dos', 'clave123');
    // Ambos entran con la misma clave: la sal no rompe el login.
    await auth.logout();
    expect(await auth.login('uno', 'clave123'), isTrue);
    await auth.logout();
    expect(await auth.login('dos', 'clave123'), isTrue);
  });
}
