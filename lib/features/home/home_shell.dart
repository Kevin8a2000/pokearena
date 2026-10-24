import 'package:flutter/material.dart';

import '../battle/battle_page.dart';
import '../pokedex/pokedex_page.dart';
import '../profile/profile_page.dart';
import '../quiz/quiz_page.dart';
import '../settings/settings_page.dart';
import 'poke_nav_bar.dart';
import '../team/team_page.dart';

/// Contenedor con la barra de navegación. Una pestaña por módulo.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static void goToTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_HomeShellState>()?.goToTab(index);
  }

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
    SettingsPage(),
  ];

  void goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: PokeNavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
