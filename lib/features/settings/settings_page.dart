import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/music_service.dart';
import '../../core/theme/poke_design.dart';
import '../../core/widgets/poke_widgets.dart';
import '../battle/battle_provider.dart';
import '../battle/battle_tutorial.dart';
import '../profile/theme_provider.dart';
import '../profile/voice_gender_pick.dart';
import '../profile/voice_provider.dart';
import 'settings_provider.dart';
import 'terms_page.dart';

/// Pantalla de Ajustes (pestaña tuerca): fondos, sonidos y legal.
/// Diseño "colores Pokémon": fondo marino y paneles con borde dorado.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final battle = context.watch<BattleProvider>();
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
                      subtitle: 'Efectos y música de la app',
                      value: settings.soundOn,
                      onChanged: (v) async {
                        await settings.setSound(v);
                        // La música obedece al maestro: se calla al apagar y
                        // vuelve al encender, salvo dentro de la arena.
                        if (!v) {
                          await MusicService.stop();
                        } else if (battle.phase != BattlePhase.fighting) {
                          await MusicService.start();
                        }
                      },
                    ),
                    _MusicTile(),
                    PokeSwitchTile(
                      title: 'Gritos en batalla',
                      subtitle: 'Los luchadores suenan al aparecer',
                      value: battle.battleCriesEnabled,
                      onChanged: battle.setBattleCries,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PokePanel(child: _VoiceSection()),
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
                    _NavTile(
                      icon: Icons.school_outlined,
                      title: 'Tutorial de batalla',
                      subtitle: 'Cómo funcionan los ataques y el combate',
                      onTap: () => showBattleTutorial(context),
                    ),
                    _NavTile(
                      icon: Icons.image_outlined,
                      title: 'Créditos de sprites',
                      subtitle: 'Entrenadores, Poké Balls y efectos de la batalla',
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Créditos de sprites'),
                          content: const SingleChildScrollView(
                            child: Text(
                              'Los sprites de la batalla Normal (entrenadores, Poké Balls y '
                              'efectos de ataque) son de Pokémon FireRed/LeafGreen.\n\n'
                              '• Efectos de ataque: ripeados por wormintheworks '
                              '(gmhandbk.webs.com).\n'
                              '• Efectos de movimiento: Neslug.\n'
                              '• Efectos de estadísticas y sprites de entrenadores: LDEJRuff.\n\n'
                              'Pokémon y todos sus personajes pertenecen a Nintendo, '
                              'Game Freak y The Pokémon Company. Uso solo educativo, '
                              'sin fines comerciales.',
                            ),
                          ),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
                        ),
                      ),
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
  final String? subtitle;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Material transparente: el panel pinta su fondo con un DecoratedBox.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(icon, color: PokeColors.goldLight),
        title: Text(title, style: pokeText(18)),
        subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }
}

/// Switch de música de fondo (canal propio, con persistencia).
class _MusicTile extends StatefulWidget {
  @override
  State<_MusicTile> createState() => _MusicTileState();
}

class _MusicTileState extends State<_MusicTile> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PokeSwitchTile(
          title: 'Música de fondo',
          subtitle: 'Tu música en loop desde JUGAR',
          value: MusicService.musicOn,
          onChanged: (v) async {
            await MusicService.setMusic(v);
            if (mounted) setState(() {});
            if (v) await MusicService.start();
          },
        ),
        if (MusicService.musicOn)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                const Icon(Icons.volume_down, size: 20, color: Colors.white),
                Expanded(
                  child: PokeSlider(
                    value: MusicService.volume,
                    onChanged: (v) async {
                      await MusicService.setVolume(v);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                const Icon(Icons.volume_up, size: 20, color: Colors.white),
                SizedBox(
                  width: 48,
                  child: Text('${(MusicService.volume * 100).round()}%', textAlign: TextAlign.end, style: pokeText(15)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Voz del narrador: encender/apagar, elegir voz (mujeres primero) y volumen
/// (antes vivía repartida en Perfil y en esta misma pantalla; ahora es una
/// sola sección reutilizable).
class _VoiceSection extends StatelessWidget {
  const _VoiceSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, vp, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PokeSwitchTile(
              title: 'Voz del narrador',
              icon: Icons.record_voice_over_outlined,
              value: vp.enabled,
              onChanged: vp.setEnabled,
            ),
            if (vp.loading)
              const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(color: PokeColors.red))
            else ...[
              const SizedBox(height: 6),
              const VoiceGenderPick(),
              const SizedBox(height: 8),
              _VoiceSlider(label: 'Volumen', icon: Icons.volume_up, value: vp.volume, min: 0.0, max: 1.0, onChanged: vp.setVolume),
            ],
          ],
        );
      },
    );
  }
}

class _VoiceSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  const _VoiceSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 8),
        SizedBox(
          width: 108,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('$label ${value.toStringAsFixed(2)}', style: pokeText(15)),
          ),
        ),
        Expanded(child: PokeSlider(value: value, min: min, max: max, divisions: 20, onChanged: onChanged)),
      ],
    );
  }
}
