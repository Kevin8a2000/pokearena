import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/services/sound_service.dart';
import 'package:pokearena/core/widgets/poke_image.dart';
import 'package:pokearena/core/widgets/pokeball_background.dart';
import 'package:pokearena/features/pokedex/pokedex_page.dart';
import 'package:pokearena/features/pokedex/pokedex_provider.dart';
import 'package:pokearena/features/settings/settings_provider.dart';
import 'package:pokearena/features/team/team_provider.dart';
import 'package:pokearena/features/wallet/coin_chip.dart';
import 'package:pokearena/features/wallet/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio falso (sin internet) con 8 Pokémon y sus tipos.
class FakeApi extends PokeApiService {
  static const _types = <String, Set<int>>{
    'grass': {1, 2, 3},
    'poison': {1, 2, 3},
    'fire': {4, 5, 6},
    'flying': {6},
    'water': {7, 8},
  };

  @override
  Future<List<PokemonSummary>> fetchAllPokemon() async => const [
        PokemonSummary(id: 1, name: 'bulbasaur'),
        PokemonSummary(id: 2, name: 'ivysaur'),
        PokemonSummary(id: 3, name: 'venusaur'),
        PokemonSummary(id: 4, name: 'charmander'),
        PokemonSummary(id: 5, name: 'charmeleon'),
        PokemonSummary(id: 6, name: 'charizard'),
        PokemonSummary(id: 7, name: 'squirtle'),
        PokemonSummary(id: 8, name: 'wartortle'),
      ];

  @override
  Future<Set<int>> fetchIdsByType(String type) async => _types[type] ?? {};

  @override
  Future<Set<int>> fetchIdsByGeneration(int generation) async => {1, 2, 3};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundService.enabled = false;
  });

  /// Las filas de filtros son las listas horizontales: así no se confunden los
  /// chips con las etiquetas de tipo de las tarjetas.
  final filterRows = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);
  Finder chip(String label) => find.descendant(of: filterRows, matching: find.text(label));
  Finder chipIcon(IconData icon) => find.descendant(of: filterRows, matching: find.byIcon(icon));
  Future<void> reveal(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(chip(label), 120, scrollable: find.descendant(of: filterRows.first, matching: find.byType(Scrollable)));
    await tester.ensureVisible(chip(label));
    await tester.pump();
  }

  Future<(PokedexProvider, SettingsProvider)> open(WidgetTester tester, {Size size = const Size(420, 900), String? wallpaper}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dex = PokedexProvider(FakeApi());
    final settings = SettingsProvider();
    if (wallpaper != null) await settings.setWallpaper(wallpaper);
    await dex.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PokedexProvider>.value(value: dex),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider()),
          ChangeNotifierProvider<TeamProvider>(create: (_) => TeamProvider(FakeApi())),
        ],
        child: const MaterialApp(home: PokedexPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return (dex, settings);
  }

  group('fondo', () {
    test('el azul marino con Pokébolas es el primero y el predeterminado', () {
      expect(wallpapers.first, kNavyWallpaper);
      expect(SettingsProvider().wallpaper, kNavyWallpaper);
    });

    testWidgets('por defecto se pinta el fondo marino; con otro, la imagen', (tester) async {
      await open(tester);
      expect(find.byType(PokeballBackground), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await open(tester, wallpaper: 'assets/images/wallpaper_3.jpg');
      expect(find.byType(PokeballBackground), findsNothing);
      expect(find.byType(Image), findsWidgets);
    });
  });

  group('cabecera y buscador', () {
    testWidgets('logo, moneda dorada y buscador grande', (tester) async {
      await open(tester);
      expect(find.bySemanticsLabel('Pokédex'), findsOneWidget);
      expect(find.byType(CoinChip), findsOneWidget);
      expect(tester.widget<CoinChip>(find.byType(CoinChip)).golden, isTrue);
      expect(find.text('Buscar por nombre o número'), findsOneWidget);
      // Ya no hay AppBar: la cabecera vive en el cuerpo.
      expect(find.byType(AppBar), findsNothing);
      final field = tester.getRect(find.byType(TextField));
      expect(field.height, greaterThanOrEqualTo(52));
    });

    testWidgets('buscar filtra las tarjetas', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'char');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Charmander'), findsOneWidget);
      expect(find.text('Bulbasaur'), findsNothing);
      expect(find.text('3 Pokémon'), findsOneWidget);
    });
  });

  group('filtros', () {
    testWidgets('chips de tipo con su color, icono y ✓ al seleccionar', (tester) async {
      final (dex, _) = await open(tester);
      expect(find.text('Todos los tipos'), findsOneWidget);
      // Hay dos filas de filtros: tipos y generaciones; cada una con su "todos" marcado.
      expect(chipIcon(Icons.check), findsNWidgets(2));
      expect(chipIcon(Icons.circle_outlined), findsOneWidget, reason: 'icono del tipo Normal');

      await reveal(tester, 'Fuego');
      expect(chip('Fuego'), findsOneWidget);
      expect(chipIcon(Icons.local_fire_department), findsOneWidget);

      // El chip de Fuego usa el color del tipo.
      final fire = tester.widget<AnimatedContainer>(find.ancestor(of: chip('Fuego'), matching: find.byType(AnimatedContainer)).first);
      expect((fire.decoration! as BoxDecoration).color, const Color(0xFFEE8130));

      await tester.tap(chip('Fuego'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(dex.selectedType, 'fire');
      expect(find.text('Charmander'), findsOneWidget);
      expect(find.text('Bulbasaur'), findsNothing);
      expect(find.text('3 Pokémon'), findsOneWidget);
      // El ✓ pasa a Fuego (y "Todos los tipos" deja de estar marcado).
      final fireChip = find.ancestor(of: chip('Fuego'), matching: find.byType(AnimatedContainer)).first;
      expect(find.descendant(of: fireChip, matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(chipIcon(Icons.local_fire_department), findsNothing, reason: 'seleccionado muestra ✓ en lugar del icono');

      // Volver a tocarlo lo quita.
      await tester.tap(chip('Fuego'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(dex.selectedType, isNull);
    });

    testWidgets('generaciones: "Todas las gen." y el menú "Gen ▾"', (tester) async {
      final (dex, _) = await open(tester);
      expect(find.text('Todas las gen.'), findsOneWidget);
      expect(find.text('Gen'), findsOneWidget);
      await tester.tap(find.text('Gen'));
      await tester.pumpAndSettle();
      expect(find.text('Gen I'), findsOneWidget);
      await tester.tap(find.text('Gen I'));
      await tester.pumpAndSettle();
      expect(dex.selectedGeneration, 1);
      expect(find.text('Gen I'), findsOneWidget, reason: 'el botón muestra la generación elegida');
      expect(find.text('3 Pokémon'), findsOneWidget);
    });

    testWidgets('Limpiar quita los filtros', (tester) async {
      final (dex, _) = await open(tester);
      await reveal(tester, 'Fuego');
      await tester.tap(chip('Fuego'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Limpiar'), findsOneWidget);
      await tester.tap(find.text('Limpiar'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(dex.hasActiveFilters, isFalse);
      expect(find.text('8 Pokémon'), findsOneWidget);
    });

    testWidgets('sin resultados ofrece limpiar los filtros', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsOneWidget);
    });
  });

  group('tarjetas', () {
    testWidgets('en móvil son 2 columnas y muestran nombre, número y etiquetas de tipo', (tester) async {
      await open(tester);
      expect(find.text('8 Pokémon'), findsOneWidget);
      expect(find.text('Bulbasaur'), findsOneWidget);
      expect(find.text('#001'), findsOneWidget);
      expect(find.text('Planta'), findsWidgets);
      expect(find.text('Veneno'), findsWidgets);
      // 2 columnas: Bulbasaur e Ivysaur comparten fila.
      final a = tester.getTopLeft(find.text('Bulbasaur'));
      final b = tester.getTopLeft(find.text('Ivysaur'));
      expect(b.dy, closeTo(a.dy, 1));
      expect(b.dx, greaterThan(a.dx + 150));
      expect(find.text('Venusaur'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Venusaur')).dy, greaterThan(a.dy + 100), reason: 'la tercera cae a la fila siguiente');
    });

    testWidgets('el color de la tarjeta es el del tipo primario y el 2º tipo va en su propia píldora', (tester) async {
      await open(tester);
      final card = find.ancestor(of: find.text('Bulbasaur'), matching: find.byType(Container)).evaluate().map((e) => e.widget as Container).firstWhere(
            (c) => c.decoration is BoxDecoration && (c.decoration! as BoxDecoration).border != null,
          );
      final deco = card.decoration! as BoxDecoration;
      expect(deco.color, const Color(0xFF7AC74C), reason: 'planta');
      expect(deco.borderRadius, BorderRadius.circular(18));
      // La píldora de Veneno lleva el tono del tipo veneno.
      final poison = tester.widget<Container>(find.ancestor(of: find.text('Veneno'), matching: find.byType(Container)).first);
      expect(poison.decoration, isA<BoxDecoration>());
    });

    testWidgets('las tarjetas son grandes: el Pokémon ocupa más de la mitad', (tester) async {
      await open(tester);
      final card = tester.getSize(find.ancestor(of: find.text('Bulbasaur'), matching: find.byType(GestureDetector)).first);
      expect(card.width, greaterThan(170));
      expect(card.height, greaterThan(140));
      final art = tester.getSize(find.byType(PokeImage).first);
      expect(art.width, greaterThan(card.width * 0.5));
    });

  });

  for (final size in const [Size(320, 640), Size(420, 900), Size(900, 700), Size(1280, 800)]) {
    testWidgets('sin overflow a ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('8 Pokémon'), findsOneWidget);
      if (size.width >= 900) {
        // En pantallas anchas hay más de 2 columnas.
        final a = tester.getTopLeft(find.text('Bulbasaur'));
        final c = tester.getTopLeft(find.text('Venusaur'));
        expect(c.dy, closeTo(a.dy, 1), reason: 'caben 3 o más por fila');
      }
    });
  }
}
