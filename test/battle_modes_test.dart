import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/features/battle/battle_page.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/team/team_provider.dart';
import 'package:pokearena/features/settings/settings_provider.dart';
import 'package:pokearena/features/wallet/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PokeApiService _api() => PokeApiService(
      client: MockClient((req) async => http.Response('{"damage_relations": {}}', 200, headers: {'content-type': 'application/json'})),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundService.enabled = false;
  });

  Future<void> open(WidgetTester tester) async {
    final api = _api();
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PokeApiService>.value(value: api),
          ChangeNotifierProvider<TeamProvider>(create: (_) => TeamProvider(api)),
          ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider()),
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<BattleProvider>(create: (_) => BattleProvider(api)),
        ],
        child: const MaterialApp(home: BattlePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('la portada tiene Normal y 2.5D', (tester) async {
    await open(tester);
    expect(find.text('Modos de batalla'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('2.5D'), findsOneWidget);
  });

  for (final mode in ['Normal', '2.5D']) {
    testWidgets('$mode es solo contra el Bot: sin botón de batalla online', (tester) async {
      await open(tester);
      await tester.tap(find.text(mode));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.wifi), findsNothing);
      expect(find.text('Batalla Online (rival real)'), findsNothing);
      expect(find.textContaining('A pelear'), findsOneWidget);
    });
  }
}
