import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/models/score_entry.dart';
import '../../core/services/cry_service.dart';
import '../../core/services/score_history_service.dart';
import '../../core/theme/poke_design.dart';
import '../../core/widgets/poke_image.dart';
import '../../core/widgets/poke_widgets.dart';
import '../../core/widgets/pokeball_background.dart';
import '../pokedex/pokedex_provider.dart';
import '../pokedex/pokemon_detail_page.dart';
import '../team/team_provider.dart';
import '../auth/auth_provider.dart';
import '../settings/settings_provider.dart';
import 'favorites_provider.dart';

/// MÓDULO: Perfil y favoritos (Sprint 2, tareas F1 a F5).
/// Incluye:
/// - Selector de tema (Claro / Oscuro / Sistema) con persistencia (F4).
/// - Lista de Pokémon favoritos con navegación al detalle y desmarcado (F3).
/// - Historial de puntajes registrado para el futuro módulo Quiz (F5).
///
/// Diseño "colores Pokémon": fondo marino, tarjeta de entrenador roja/blanca
/// y un gran panel marino con borde dorado para los ajustes.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PokeScaffold(
      centerTitle: true,
      title: const PokeLogoText('Perfil', size: 34, arched: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: const [
              _TrainerHeaderCard(),
              SizedBox(height: 16),
              _WallpaperSection(),
              SizedBox(height: 16),
              _FavoritesSection(),
              SizedBox(height: 16),
              _ScoreHistorySection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado del entrenador: mitad roja / mitad blanca con avatar en aro dorado.
class _TrainerHeaderCard extends StatelessWidget {
  const _TrainerHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            // Mitad roja arriba, blanca abajo (como una Pokébola).
            Positioned.fill(
              child: Column(
                children: [
                  Expanded(child: Container(color: PokeColors.red)),
                  Container(height: 3, color: Colors.black),
                  Expanded(child: Container(color: Colors.white)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _pickAvatar(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: PokeColors.gold, width: 4),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Builder(
                            builder: (context) {
                              final avatarId = context.watch<SettingsProvider>().avatarId;
                              if (avatarId == null) {
                                return const SizedBox(width: 64, height: 64, child: Center(child: PokeBallIcon(size: 48)));
                              }
                              return ClipOval(
                                child: PokeImage(id: avatarId, kind: PokeSpriteKind.artwork, width: 64, height: 64, cacheWidth: 128, preferLocalAvatar: true),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                context.watch<AuthProvider>().currentUser ?? 'Entrenador PokéArena',
                                maxLines: 1,
                                style: pokeText(28, shadows: pokeTextShadow),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Consumer2<FavoritesProvider, TeamProvider>(
                              builder: (context, favs, team, _) {
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _BadgeChip(icon: Icons.favorite, label: '${favs.count} Favs', color: PokeColors.red),
                                    _BadgeChip(icon: Icons.groups, label: '${team.count}/6 Equipo', color: PokeColors.blue),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      PokeRoundButton(
                        icon: Icons.logout,
                        size: 44,
                        tooltip: 'Cerrar sesión',
                        onPressed: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('Tus datos se guardan. Otra persona podrá entrar con su cuenta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BadgeChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: pokeText(14, color: PokeColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// Título de sección dentro de un panel: icono dorado + texto.
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;
  const _SectionTitle(this.icon, this.text, {this.iconColor = PokeColors.goldLight});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: pokeText(21, color: PokeColors.goldLight))),
      ],
    );
  }
}

/// Fondo de la Pokédex: elegir el wallpaper (antes vivía en Ajustes).
class _WallpaperSection extends StatelessWidget {
  const _WallpaperSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return PokePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(Icons.image_outlined, 'Fondo de Pokédex'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.7,
            ),
            itemCount: wallpapers.length,
            itemBuilder: (context, i) {
              final path = wallpapers[i];
              final selected = settings.wallpaper == path;
              return GestureDetector(
                onTap: () => settings.setWallpaper(path),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? PokeColors.goldLight : Colors.black, width: selected ? 4 : 3),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (path == kNavyWallpaper)
                          const PokeballBackground(cell: 56)
                        else
                          Image.asset(
                            path,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(Icons.broken_image, color: Colors.white54),
                            ),
                          ),
                        if (selected)
                          const Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.check_circle, color: PokeColors.goldLight),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Sección de Pokémon favoritos (Requisito F3).
class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, favProvider, _) {
        final favorites = favProvider.favorites;

        return PokePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _SectionTitle(Icons.favorite, 'Mis Favoritos (${favProvider.count})', iconColor: PokeColors.red)),
                  if (favProvider.isLoading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 10),
              if (favorites.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.favorite_border, size: 44, color: Colors.white54),
                      SizedBox(height: 8),
                      Text('No tienes favoritos guardados', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 4),
                      Text(
                        'Toca el corazón en la esquina superior del detalle de cualquier Pokémon para guardarlo aquí.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
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
                    return _FavoriteCard(pokemon: p, onRemove: () => favProvider.removeFavorite(p.id));
                  },
                ),
            ],
          ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: _isHovered ? Matrix4.translationValues(0.0, -6.0, 0.0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: PokeColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _isHovered ? PokeColors.red : Colors.black, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? PokeColors.red.withValues(alpha: 0.4) : Colors.black38,
              blurRadius: _isHovered ? 14 : 4,
              offset: Offset(0, _isHovered ? 6 : 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PokemonDetailPage(id: widget.pokemon.id)));
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
                          child: PokeImage(id: widget.pokemon.id, fit: BoxFit.contain, cacheWidth: 256, placeholderColor: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${widget.pokemon.id.toString().padLeft(3, '0')} ${prettyName(widget.pokemon.name)}',
                        style: pokeText(14, color: PokeColors.ink),
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
                  icon: const Icon(Icons.favorite, color: PokeColors.red),
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
    final historyService = context.read<ScoreHistoryService>();

    return PokePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(Icons.military_tech_outlined, 'Historial de Puntajes'),
          const SizedBox(height: 4),
          const Text(
            'Registro de partidas en minijuegos (módulo Quiz / Sprint 3):',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<ScoreEntry>>(
            future: historyService.getHistory(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Colors.white)));
              }

              final entries = snap.data ?? [];
              if (entries.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Text('Aún no hay partidas jugadas en el Quiz.', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ),
                );
              }

              return Material(
                type: MaterialType.transparency,
                child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white24),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.emoji_events, color: PokeColors.goldLight),
                    title: Text(e.gameName, style: pokeText(17)),
                    subtitle: Text('${e.date.day}/${e.date.month}/${e.date.year}', style: const TextStyle(color: Colors.white70)),
                    trailing: Text('${e.score} pts', style: pokeText(18, color: PokeColors.goldLight)),
                  );
                },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Abre el selector de foto de perfil a pantalla completa.
Future<void> _pickAvatar(BuildContext context) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AvatarPickerPage()));
}

/// Selector de foto de perfil: cualquiera de los 1025 Pokémon. Los
/// primeros [kLocalAvatarMaxId] funcionan sin internet (PNG guardado en la
/// app, ver `assets/images/avatars/`); del resto se piden por internet
/// igual que el resto de la app — se marcan con la nube para que se note
/// la diferencia.
class _AvatarPickerPage extends StatefulWidget {
  const _AvatarPickerPage();

  @override
  State<_AvatarPickerPage> createState() => _AvatarPickerPageState();
}

class _AvatarPickerPageState extends State<_AvatarPickerPage> {
  static const _total = 1025;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final q = _query.trim();
    final asNumber = int.tryParse(q.replaceFirst('#', ''));
    List<int> ids;
    if (q.isEmpty) {
      ids = List.generate(_total, (i) => i + 1);
    } else if (asNumber != null) {
      ids = asNumber >= 1 && asNumber <= _total ? [asNumber] : const [];
    } else {
      // Buscar por nombre necesita la lista de la Pokédex (con internet);
      // si no cargó, simplemente no hay resultados por nombre todavía.
      final dex = context.watch<PokedexProvider>();
      final qn = q.toLowerCase().replaceAll(' ', '-');
      ids = dex.all.where((p) => p.name.contains(qn)).map((p) => p.id).toList();
    }
    final showNone = q.isEmpty;

    return PokeScaffold(
      title: const PokeLogoText('Foto de perfil', size: 30, arched: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o número...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.cloud_outlined, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Del #${kLocalAvatarMaxId + 1} en adelante hace falta internet · #1-$kLocalAvatarMaxId funcionan sin conexión',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ids.isEmpty
                ? const Center(child: Text('Sin resultados', style: TextStyle(color: Colors.white70)))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: ids.length + (showNone ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (showNone && i == 0) {
                        return _AvatarTile(
                          selected: settings.avatarId == null,
                          label: 'Ninguna',
                          onTap: () {
                            settings.setAvatar(null);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const Icon(Icons.person, color: Colors.white70, size: 32),
                          ),
                        );
                      }
                      final id = ids[i - (showNone ? 1 : 0)];
                      final offline = id <= kLocalAvatarMaxId;
                      return _AvatarTile(
                        selected: settings.avatarId == id,
                        label: '#${id.toString().padLeft(3, '0')}',
                        badge: offline ? null : Icons.cloud_outlined,
                        onTap: () {
                          CryService.playCry(id);
                          settings.setAvatar(id);
                          Navigator.of(context).pop();
                        },
                        child: PokeImage(
                          id: id,
                          kind: PokeSpriteKind.artwork,
                          fit: BoxFit.contain,
                          cacheWidth: 128,
                          preferLocalAvatar: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Una opción del selector: círculo con la imagen, aro dorado si está
/// elegida, y una nubecita si esa en particular necesita internet.
class _AvatarTile extends StatelessWidget {
  final Widget child;
  final bool selected;
  final String label;
  final IconData? badge;
  final VoidCallback onTap;
  const _AvatarTile({
    required this.child,
    required this.selected,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white10,
                    border: Border.all(color: selected ? PokeColors.gold : Colors.white24, width: selected ? 3 : 1),
                  ),
                  child: ClipOval(child: child),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xFF14224C), shape: BoxShape.circle),
                      child: Icon(badge, size: 12, color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
