import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/music_service.dart';
import 'core/services/pokeapi_service.dart';
import 'core/services/score_history_service.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_shell.dart';
import 'features/splash/splash_sequence.dart';
import 'features/battle/battle_provider.dart';
import 'features/wallet/wallet_provider.dart';
import 'features/pokedex/pokedex_provider.dart';
import 'features/profile/favorites_provider.dart';
import 'features/profile/theme_provider.dart';
import 'features/settings/settings_provider.dart';
import 'features/quiz/quiz_provider.dart';
import 'features/team/team_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MusicService.load();
  // Firebase es opcional: sin red o sin config, la app sigue 100% offline.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  runApp(const PokeArenaApp());
}

class PokeArenaApp extends StatelessWidget {
  const PokeArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Sesión por persona (login local)
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..load(),
        ),
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
        // Equipo y favoritos se cargan tras el login (datos por usuario)
        ChangeNotifierProvider<TeamProvider>(
          create: (ctx) => TeamProvider(ctx.read<PokeApiService>()),
        ),
        ChangeNotifierProvider<FavoritesProvider>(
          create: (ctx) => FavoritesProvider(ctx.read<PokeApiService>()),
        ),
        ChangeNotifierProvider<QuizProvider>(
          create: (ctx) => QuizProvider(ctx.read<PokeApiService>())..load(),
        ),
        ChangeNotifierProvider<BattleProvider>(
          create: (ctx) => BattleProvider(ctx.read<PokeApiService>())
            ..loadSavedTerrain(),
        ),
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..load(),
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
            home: const SplashSequence(child: AuthGate()),
          );
        },
      ),
    );
  }
}

/// Puerta de acceso: sin sesión muestra el login; con sesión carga los
/// datos de ese usuario (equipo, favoritos, historial, batalla limpia)
/// y entra a la app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _loadedFor;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!auth.isLoggedIn) {
      _loadedFor = null;
      return LoginPage(auth: auth);
    }
    if (_loadedFor != auth.currentUser) {
      _loadedFor = auth.currentUser;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final user = auth.currentUser;
        context.read<TeamProvider>().switchUser(user);
        context.read<SettingsProvider>().switchUser(user);
        context.read<FavoritesProvider>().switchUser(user);
        context.read<ScoreHistoryService>().setOwner(user);
        context.read<BattleProvider>().resetTeams();
        context.read<WalletProvider>().switchUser(user);
      });
    }
    return const HomeShell();
  }
}
