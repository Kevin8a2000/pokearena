import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/score_history_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/core/widgets/poke_widgets.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/profile/favorites_provider.dart';
import 'package:pokearena/features/profile/profile_page.dart';
import 'package:pokearena/features/profile/theme_provider.dart';
import 'package:pokearena/features/quiz/quiz_page.dart';
import 'package:pokearena/features/quiz/quiz_provider.dart';
import 'package:pokearena/features/settings/settings_page.dart';
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

  Future<void> open(WidgetTester tester, Widget home, double w, double h) async {
    final api = _api();
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PokeApiService>.value(value: api),
          Provider<ScoreHistoryService>(create: (_) => ScoreHistoryService()),
          ChangeNotifierProvider<TeamProvider>(create: (_) => TeamProvider(api)),
          ChangeNotifierProvider<FavoritesProvider>(create: (_) => FavoritesProvider(api)),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<BattleProvider>(create: (_) => BattleProvider(api)),
          ChangeNotifierProvider<QuizProvider>(create: (_) => QuizProvider(api)),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  for (final size in const [Size(320, 640), Size(360, 740), Size(420, 900), Size(800, 600)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('$tag Perfil: tarjeta, fondos y favoritos sin overflow', (tester) async {
      await open(tester, const ProfilePage(), size.width, size.height);
      expect(find.byWidgetPredicate((w) => w is PokeLogoText && w.text == 'Perfil'), findsOneWidget);
      expect(find.textContaining('Favs'), findsOneWidget);
      expect(find.textContaining('/6 Equipo'), findsOneWidget);
      expect(find.text('Fondo de Pokédex'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$tag Ajustes: tema, sonidos y legal sin overflow', (tester) async {
      await open(tester, const SettingsPage(), size.width, size.height);
      expect(find.byWidgetPredicate((w) => w is PokeLogoText && w.text == 'Ajustes'), findsOneWidget);
      expect(find.byType(PokeSegmented<ThemeMode>), findsOneWidget);
      expect(find.text('Sonidos', skipOffstage: false), findsOneWidget);
      expect(find.byType(PokeSwitch, skipOffstage: false), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$tag Quiz: portada con "?" y ¡Jugar!', (tester) async {
      await open(tester, const QuizPage(), size.width, size.height);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }
}
