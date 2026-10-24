import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/features/splash/onboarding_page.dart';
import 'package:pokearena/features/splash/splash_sequence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('carga real y botón JUGAR al terminar', (t) async {
    SharedPreferences.setMockInitialValues(
        {'pokearena_onboarding_done': true});
    await t.pumpWidget(
      const MaterialApp(
        home: SplashSequence(
            warmupCount: 2, warmupImages: false, child: Text('JUEGO')),
      ),
    );
    expect(find.text('Vive batallas épicas'), findsOneWidget);
    expect(find.text('JUGAR'), findsNothing);
    // La carga corre sola (sin red en tests: falla rápido y avanza).
    await t.pump(const Duration(seconds: 6));
    expect(find.text('JUGAR'), findsOneWidget);
    await t.tap(find.text('JUGAR'));
    await t.pump();
    expect(find.text('JUEGO'), findsOneWidget);
  });

  testWidgets('primera vez pasa por onboarding tras JUGAR', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(
      const MaterialApp(
        home: SplashSequence(
            warmupCount: 1, warmupImages: false, child: Text('JUEGO')),
      ),
    );
    await t.pump(const Duration(seconds: 6));
    expect(find.text('JUGAR'), findsOneWidget);
    await t.tap(find.text('JUGAR'));
    await t.pump();
    expect(find.text('Explora la Pokédex'), findsOneWidget);
    expect(find.text('JUEGO'), findsNothing);
  });

  testWidgets('onboarding muestra Empezar en la última página', (t) async {
    SharedPreferences.setMockInitialValues({});
    var done = false;
    await t.pumpWidget(
      MaterialApp(
        home: OnboardingPage(onFinish: () => done = true),
      ),
    );
    expect(find.text('Siguiente'), findsOneWidget);
    // Avanza a la última página.
    await t.tap(find.text('Siguiente'));
    await t.pumpAndSettle();
    await t.tap(find.text('Siguiente'));
    await t.pumpAndSettle();
    expect(find.text('Empezar'), findsOneWidget);
    await t.tap(find.text('Empezar'));
    await t.pumpAndSettle();
    expect(done, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pokearena_onboarding_done'), isTrue);
  });
}
