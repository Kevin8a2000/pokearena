import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/pokeapi_service.dart';
import 'features/home/home_shell.dart';
import 'features/pokedex/pokedex_provider.dart';

void main() {
  runApp(const PokeArenaApp());
}

class PokeArenaApp extends StatelessWidget {
  const PokeArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Servicio único de PokeAPI, compartido por todos los módulos.
        Provider<PokeApiService>(create: (_) => PokeApiService()),
        // Cada módulo registra aquí su propio provider (equipo, batalla, quiz, perfil).
        ChangeNotifierProvider<PokedexProvider>(
          create: (ctx) => PokedexProvider(ctx.read<PokeApiService>())..load(),
        ),
      ],
      child: MaterialApp(
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
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      ),
    );
  }
}
