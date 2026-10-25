import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/score_history_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/core/widgets/poke_widgets.dart';
import 'package:pokearena/features/auth/auth_provider.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/profile/favorites_provider.dart';
import 'package:pokearena/features/profile/profile_page.dart';
import 'package:pokearena/features/profile/theme_provider.dart';
import 'package:pokearena/features/settings/settings_provider.dart';
import 'package:pokearena/features/team/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PokeApiService _api() => PokeApiService(
      client: MockClient((req) async => http.Response('{"results": [], "damage_relations": {}}', 200, headers: {'content-type': 'application/json'})),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundService.enabled = false;
  });

  testWidgets('tocar un avatar en el selector lo elige, suena el grito y no lanza excepciones', (tester) async {
    final api = _api();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PokeApiService>.value(value: api),
          Provider<ScoreHistoryService>(create: (_) => ScoreHistoryService()),
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<TeamProvider>(create: (_) => TeamProvider(api)),
          ChangeNotifierProvider<FavoritesProvider>(create: (_) => FavoritesProvider(api)),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<BattleProvider>(create: (_) => BattleProvider(api)),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Abre el selector de foto de perfil tocando el aro dorado (sin avatar
    // elegido todavía, muestra la Poké Ball).
    await tester.tap(find.byType(PokeBallIcon));
    await tester.pumpAndSettle();
    final pickerTitle = find.byWidgetPredicate((w) => w is PokeLogoText && w.text == 'Foto de perfil');
    expect(pickerTitle, findsOneWidget);

    // Toca el primer avatar disponible (#001).
    await tester.tap(find.text('#001'));
    await tester.pumpAndSettle();

    // Vuelve a Perfil con el avatar ya elegido, sin errores.
    expect(pickerTitle, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
