import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/models/score_entry.dart';
import '../../core/services/score_history_service.dart';
import '../pokedex/pokemon_detail_page.dart';
import '../team/team_provider.dart';
import 'favorites_provider.dart';
import 'theme_provider.dart';

/// MÓDULO: Perfil y favoritos (Sprint 2, tareas F1 a F5).
/// Incluye:
/// - Selector de tema (Claro / Oscuro / Sistema) con persistencia (F4).
/// - Lista de Pokémon favoritos con navegación al detalle y desmarcado (F3).
/// - Historial de puntajes registrado para el futuro módulo Quiz (F5).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil y Ajustes'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: const [
              // Tarjeta de bienvenida del entrenador
              _TrainerHeaderCard(),
              SizedBox(height: 20),

              // Selector de tema (F4)
              _ThemeSelectorSection(),
              SizedBox(height: 24),

              // Lista de favoritos (F3)
              _FavoritesSection(),
              SizedBox(height: 24),

              // Historial de puntajes (F5)
              _ScoreHistorySection(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado con información general del perfil del usuario.
class _TrainerHeaderCard extends StatelessWidget {
  const _TrainerHeaderCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.catching_pokemon, size: 38, color: scheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrenador PokéArena',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Consumer2<FavoritesProvider, TeamProvider>(
                    builder: (context, favs, team, _) {
                      return Wrap(
                        spacing: 8,
                        children: [
                          _BadgeChip(
                            icon: Icons.favorite,
                            label: '${favs.count} Favs',
                            color: Colors.redAccent,
                          ),
                          _BadgeChip(
                            icon: Icons.groups,
                            label: '${team.count}/6 Equipo',
                            color: scheme.primary,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

/// Selector de tema de la aplicación (Requisito F4).
class _ThemeSelectorSection extends StatelessWidget {
  const _ThemeSelectorSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.palette_outlined, size: 20),
            const SizedBox(width: 8),
            Text(
              'Tema de la aplicación',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Personaliza el aspecto visual. El tema elegido se guarda para futuras sesiones:',
          style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 12),
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            return SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Claro'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Oscuro'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('Sistema'),
                ),
              ],
              selected: {themeProvider.themeMode},
              onSelectionChanged: (newSelection) {
                themeProvider.setThemeMode(newSelection.first);
              },
            );
          },
        ),
      ],
    );
  }
}

/// Sección de Pokémon favoritos (Requisito F3).
class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Consumer<FavoritesProvider>(
      builder: (context, favProvider, _) {
        final favorites = favProvider.favorites;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite, size: 20, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Mis Favoritos (${favProvider.count})',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (favProvider.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (favorites.isEmpty)
              Card(
                elevation: 0,
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.favorite_border, size: 44, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No tienes favoritos guardados',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Toca el corazón en la esquina superior del detalle de cualquier Pokémon para guardarlo aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisExtent: 170,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final p = favorites[index];
                  return _FavoriteCard(
                    pokemon: p,
                    onRemove: () => favProvider.removeFavorite(p.id),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Tarjeta de favorito con microanimación de escala y elevación al pasar el cursor (hover).
class _FavoriteCard extends StatefulWidget {
  final PokemonSummary pokemon;
  final VoidCallback onRemove;

  const _FavoriteCard({required this.pokemon, required this.onRemove});

  @override
  State<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<_FavoriteCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: _isHovered
            ? Matrix4.translationValues(0.0, -6.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered
                ? Colors.redAccent.withValues(alpha: 0.6)
                : scheme.outlineVariant.withValues(alpha: 0.3),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PokemonDetailPage(id: widget.pokemon.id),
              ),
            );
          },
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AnimatedScale(
                          scale: _isHovered ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: Image.network(
                            widget.pokemon.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${widget.pokemon.id.toString().padLeft(3, '0')} ${prettyName(widget.pokemon.name)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  iconSize: 20,
                  tooltip: 'Quitar de favoritos',
                  icon: const Icon(Icons.favorite, color: Colors.redAccent),
                  onPressed: widget.onRemove,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Historial de puntajes (Requisito F5).
/// Lee los puntajes guardados por ScoreHistoryService (para uso del módulo Quiz en Sprint 3).
class _ScoreHistorySection extends StatelessWidget {
  const _ScoreHistorySection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final historyService = context.read<ScoreHistoryService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.military_tech_outlined, size: 20),
            const SizedBox(width: 8),
            Text(
              'Historial de Puntajes',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Registro de partidas en minijuegos (módulo Quiz / Sprint 3):',
          style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 10),

        FutureBuilder<List<ScoreEntry>>(
          future: historyService.getHistory(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
            }

            final entries = snap.data ?? [];
            if (entries.isEmpty) {
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Aún no hay partidas jugadas en el Quiz.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = entries[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.emoji_events, color: Colors.amber),
                  title: Text(e.gameName),
                  subtitle: Text('${e.date.day}/${e.date.month}/${e.date.year}'),
                  trailing: Text(
                    '${e.score} pts',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
