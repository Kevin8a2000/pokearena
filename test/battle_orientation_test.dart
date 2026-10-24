import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/battle/battle_orientation.dart';
import 'package:pokearena/features/battle/battle_provider.dart';

/// Registra las llamadas a `SystemChrome` (el canal de la plataforma).
class _Calls {
  final List<MethodCall> log = [];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      log.add(call);
      return null;
    });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  }

  /// Orientaciones pedidas en cada `setPreferredOrientations`.
  List<List<String>> get orientations => [
        for (final c in log)
          if (c.method == 'SystemChrome.setPreferredOrientations') (c.arguments as List).cast<String>(),
      ];

  List<String> get uiModes => [
        for (final c in log)
          if (c.method == 'SystemChrome.setEnabledSystemUIMode') c.arguments is Map ? (c.arguments as Map)['mode'].toString() : c.arguments.toString(),
      ];

  void clear() => log.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = _Calls();

  setUp(() {
    BattleOrientation.debugReset();
    calls
      ..clear()
      ..install();
  });

  tearDown(() {
    BattleOrientation.debugReset();
    calls.uninstall();
  });

  group('BattleOrientation', () {
    test('lock pide las dos horizontales y el modo inmersivo', () {
      BattleOrientation.lock();
      expect(BattleOrientation.isLocked, isTrue);
      expect(calls.orientations, [
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      ]);
      expect(calls.uiModes.length, 1);
      expect(calls.uiModes.single, contains('immersiveSticky'));
    });

    test('un segundo lock no repite las llamadas al sistema', () {
      BattleOrientation.lock();
      BattleOrientation.lock();
      expect(BattleOrientation.locks, 2);
      expect(calls.orientations.length, 1);
    });

    test('solo se restaura cuando el último consumidor suelta el bloqueo', () {
      BattleOrientation.lock();
      BattleOrientation.lock();
      calls.clear();
      BattleOrientation.release();
      expect(calls.orientations, isEmpty); // todavía queda uno
      expect(BattleOrientation.isLocked, isTrue);
      BattleOrientation.release();
      expect(BattleOrientation.isLocked, isFalse);
      expect(calls.orientations.length, 1);
      expect(calls.orientations.single.length, DeviceOrientation.values.length); // vuelven todas
    });

    test('soltar sin haber bloqueado no hace nada ni deja el contador negativo', () {
      BattleOrientation.release();
      BattleOrientation.release();
      expect(BattleOrientation.locks, 0);
      expect(calls.log, isEmpty);
      BattleOrientation.lock();
      expect(BattleOrientation.locks, 1);
    });
  });

  group('LandscapeLock', () {
    testWidgets('bloquea al montarse y suelta al desmontarse', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LandscapeLock(child: Text('batalla'))));
      expect(find.text('batalla'), findsOneWidget);
      expect(BattleOrientation.isLocked, isTrue);

      await tester.pumpWidget(const MaterialApp(home: Text('fuera')));
      expect(BattleOrientation.isLocked, isFalse);
    });
  });

  group('BattleProvider', () {
    test('backToSelect y resetTeams sin combate activo no tocan la orientación', () {
      final b = BattleProvider(PokeApiService());
      b.backToSelect();
      b.resetTeams();
      expect(BattleOrientation.locks, 0);
      expect(calls.orientations, isEmpty);
    });

    test('startBattle sin equipos no bloquea la orientación', () async {
      final b = BattleProvider(PokeApiService());
      await b.startBattle(); // canStart es false: no hace nada
      expect(BattleOrientation.locks, 0);
    });

    test('un provider que no sostiene el bloqueo no libera el de otro consumidor', () {
      BattleOrientation.lock(); // p. ej. la pantalla online
      final b = BattleProvider(PokeApiService());
      b.backToSelect();
      b.resetTeams();
      expect(BattleOrientation.locks, 1);
      BattleOrientation.release();
      expect(BattleOrientation.locks, 0);
    });
  });
}
