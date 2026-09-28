import 'package:flutter/material.dart';

import '../battle/battle_page.dart';
import '../pokedex/pokedex_page.dart';
import '../profile/profile_page.dart';
import '../quiz/quiz_page.dart';
import '../team/team_page.dart';

/// Contenedor con la barra de navegación. Una pestaña por módulo.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    PokedexPage(),
    TeamPage(),
    BattlePage(),
    QuizPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.catching_pokemon), label: 'Pokédex'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Equipo'),
          NavigationDestination(icon: Icon(Icons.sports_mma), label: 'Batalla'),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Quiz'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
