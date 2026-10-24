import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/poke_design.dart';
import '../../core/widgets/poke_widgets.dart';
import '../profile/theme_provider.dart';
import 'settings_provider.dart';
import 'terms_page.dart';

/// Pantalla de Ajustes (pestaña tuerca): fondos, sonidos y legal.
/// Diseño "colores Pokémon": fondo marino y paneles con borde dorado.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return PokeScaffold(
      title: const PokeLogoText('Ajustes', size: 40),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              PokePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tema de la aplicación', style: pokeText(26, color: PokeColors.goldLight)),
                    const SizedBox(height: 6),
                    const Text(
                      'Personaliza el aspecto visual. El tema elegido se guarda para futuras sesiones:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return PokeSegmented<ThemeMode>(
                          segments: const [
                            PokeSegment(ThemeMode.light, 'Claro', icon: Icons.light_mode),
                            PokeSegment(ThemeMode.dark, 'Oscuro', icon: Icons.dark_mode),
                            PokeSegment(ThemeMode.system, 'Sistema', icon: Icons.brightness_auto),
                          ],
                          selected: themeProvider.themeMode,
                          onChanged: themeProvider.setThemeMode,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PokePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sonidos', style: pokeText(26, color: PokeColors.goldLight)),
                    const SizedBox(height: 6),
                    PokeSwitchTile(
                      title: 'Sonido general',
                      subtitle: 'Efectos de la app',
                      value: settings.soundOn,
                      onChanged: settings.setSound,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PokePanel(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  children: [
                    _NavTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Política de privacidad',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsPage(kind: TermsKind.privacy))),
                    ),
                    _NavTile(
                      icon: Icons.description_outlined,
                      title: 'Términos y condiciones',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsPage(kind: TermsKind.terms))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('PokéArena v1.0.0 · Proyecto de clase', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de navegación dentro de un panel marino (icono, título, flecha).
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Material transparente: el panel pinta su fondo con un DecoratedBox.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(icon, color: PokeColors.goldLight),
        title: Text(title, style: pokeText(18)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }
}
