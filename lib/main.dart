import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/pokeapi_service.dart';
import 'core/services/score_history_service.dart';
import 'features/home/home_shell.dart';
import 'features/battle/battle_provider.dart';
import 'features/pokedex/pokedex_provider.dart';
import 'features/profile/favorites_provider.dart';
import 'features/profile/theme_provider.dart';
import 'features/quiz/quiz_provider.dart';
import 'features/team/team_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PokeArenaApp());
}

class PokeArenaApp extends StatelessWidget {
  const PokeArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Servicios compartidos de PokeAPI e historial de puntajes
        Provider<PokeApiService>(create: (_) => PokeApiService()),
        Provider<ScoreHistoryService>(create: (_) => ScoreHistoryService()),

        // Providers de estado de cada módulo
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..loadSavedTheme(),
        ),
        ChangeNotifierProvider<PokedexProvider>(
          create: (ctx) => PokedexProvider(ctx.read<PokeApiService>())..load(),
        ),
        ChangeNotifierProvider<TeamProvider>(
          create: (ctx) =>
              TeamProvider(ctx.read<PokeApiService>())..loadSavedTeam(),
        ),
        ChangeNotifierProvider<FavoritesProvider>(
          create: (ctx) =>
              FavoritesProvider(ctx.read<PokeApiService>())..loadFavorites(),
        ),
        ChangeNotifierProvider<QuizProvider>(
          create: (ctx) => QuizProvider(ctx.read<PokeApiService>())..load(),
        ),
        ChangeNotifierProvider<BattleProvider>(
          create: (ctx) => BattleProvider(ctx.read<PokeApiService>()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'PokéArena',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.redAccent,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
