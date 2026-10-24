import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/profile/theme_provider.dart';
import 'package:pokearena/features/profile/voice_provider.dart';
import 'package:pokearena/features/settings/settings_page.dart';
import 'package:pokearena/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Ajustes muestra sección de voz con sliders', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(800, 4000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final voice = VoiceProvider();
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(),
          ),
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(),
          ),
          ChangeNotifierProvider<BattleProvider>(
            create: (_) => BattleProvider(PokeApiService()),
          ),
          ChangeNotifierProvider<VoiceProvider>.value(value: voice),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await t.pump();
    expect(find.text('Voz del narrador'), findsOneWidget);
    expect(find.textContaining('Mujer'), findsOneWidget);
    expect(find.textContaining('Hombre'), findsOneWidget);
    expect(find.textContaining('Probar voz'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2)); // 1 voz (volumen) + 1 música

    // Mover un slider persiste sin lanzar.
    await voice.setVolume(0.5);
    expect(voice.volume, 0.5);
    await voice.setRate(9.0);
    expect(voice.rate, 1.5);
    await voice.setPitch(0.0);
    expect(voice.pitch, 0.5);
  });
}
