import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/evolution.dart';
import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';
import '../../core/theme/type_colors.dart';
import '../profile/favorites_provider.dart';
import '../team/team_provider.dart';

const _statNamesEs = {
  'hp': 'PS',
  'attack': 'Ataque',
  'defense': 'Defensa',
  'special-attack': 'Ataque esp.',
  'special-defense': 'Defensa esp.',
  'speed': 'Velocidad',
};

class PokemonDetailPage extends StatefulWidget {
  final int id;
  const PokemonDetailPage({super.key, required this.id});

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  late Future<PokemonDetail> _detail;
  late Future<EvolutionNode> _evolution;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Detalle y evolución se piden por separado: si la evolución tarda o falla,
  // el resto de la pantalla igual se muestra.
  void _load() {
    final api = context.read<PokeApiService>();
    _detail = api.fetchPokemonDetail(widget.id);
    _evolution = api.fetchEvolutionChain(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          Consumer<FavoritesProvider>(
            builder: (context, favProvider, _) {
              final isFav = favProvider.isFavorite(widget.id);
              return IconButton(
                tooltip: isFav ? 'Quitar de favoritos' : 'Agregar a favoritos',
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.redAccent : null,
                ),
                onPressed: () {
                  _detail.then((d) {
                    favProvider.toggleFavorite(id: d.id, name: d.name);
                  }).catchError((_) {
                    favProvider.toggleFavorite(
                      id: widget.id,
                      name: 'Pokémon #${widget.id}',
                    );
                  });
                },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<PokemonDetail>(
        future: _detail,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar el Pokémon'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => setState(_load),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final d = snap.data!;
          final textTheme = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AnimatedPokemonArtwork(imageUrl: d.imageUrl),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '#${d.id.toString().padLeft(3, '0')}  ${prettyName(d.name)}',
                  style: textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final t in d.types)
                    Chip(
                      label: Text(typeNameEs(t),
                          style: const TextStyle(color: Colors.white)),
                      backgroundColor: colorForType(t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                    'Altura: ${d.height / 10} m   •   Peso: ${d.weight / 10} kg'),
              ),
              const SizedBox(height: 16),
              // Botón de gestión del equipo (Requisito E2)
              Consumer<TeamProvider>(
                builder: (context, teamProvider, _) {
                  final inTeam = teamProvider.isInTeam(d.id);
                  if (inTeam) {
                    return Center(
                      child: FilledButton.tonalIcon(
                        onPressed: () => teamProvider.removePokemon(d.id),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Quitar del equipo'),
                        style: FilledButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (teamProvider.isFull) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('El equipo ya tiene 6 Pokémon (máximo alcanzado)'),
                            ),
                          );
                          return;
                        }
                        final added = await teamProvider.addPokemon(d);
                        if (context.mounted && added) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${prettyName(d.name)} agregado al equipo (${teamProvider.count}/6)'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(
                        teamProvider.isFull
                            ? 'Equipo completo (6/6)'
                            : 'Agregar al equipo (${teamProvider.count}/6)',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Habilidades', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in d.abilities)
                    Chip(
                      avatar: a.isHidden
                          ? const Icon(Icons.visibility_off, size: 18)
                          : null,
                      label: Text(a.isHidden
                          ? '${prettyName(a.name)} (oculta)'
                          : prettyName(a.name)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Estadísticas base', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final e in d.stats.entries)
                _StatBar(name: _statNamesEs[e.key] ?? e.key, value: e.value),
              const SizedBox(height: 20),
              Text('Evolución', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              _EvolutionSection(
                future: _evolution,
                currentId: d.id,
                onRetry: () => setState(_load),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String name;
  final int value;
  const _StatBar({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(name)),
          SizedBox(width: 36, child: Text('$value')),
          Expanded(
            child: LinearProgressIndicator(
              value: (value / 255).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvolutionSection extends StatelessWidget {
  final Future<EvolutionNode> future;
  final int currentId;
  final VoidCallback onRetry;

  const _EvolutionSection({
    required this.future,
    required this.currentId,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EvolutionNode>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Column(
            children: [
              const Text('No se pudo cargar la evolución'),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          );
        }
        final root = snap.data!;
        if (root.children.isEmpty) {
          return const Center(child: Text('Este Pokémon no evoluciona'));
        }
        return Center(child: _EvolutionTree(node: root, currentId: currentId));
      },
    );
  }
}

/// Dibuja el árbol de evolución de forma recursiva: cada nodo muestra su
/// tarjeta y, debajo, sus evoluciones (varias si la cadena se ramifica).
class _EvolutionTree extends StatelessWidget {
  final EvolutionNode node;
  final int currentId;
  const _EvolutionTree({required this.node, required this.currentId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EvolutionCard(node: node, isCurrent: node.id == currentId),
        if (node.children.isNotEmpty) ...[
          const Icon(Icons.arrow_downward),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in node.children)
                _EvolutionTree(node: c, currentId: currentId),
            ],
          ),
        ],
      ],
    );
  }
}

/// Arte oficial interactivo con microanimación de escala al pasar el cursor (hover).
class _AnimatedPokemonArtwork extends StatefulWidget {
  final String imageUrl;
  const _AnimatedPokemonArtwork({required this.imageUrl});

  @override
  State<_AnimatedPokemonArtwork> createState() =>
      _AnimatedPokemonArtworkState();
}

class _AnimatedPokemonArtworkState extends State<_AnimatedPokemonArtwork> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Center(
        child: SizedBox(
          height: 220,
          child: AnimatedScale(
            scale: _isHovered ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, size: 80),
            ),
          ),
        ),
      ),
    );
  }
}

class _EvolutionCard extends StatefulWidget {
  final EvolutionNode node;
  final bool isCurrent;
  const _EvolutionCard({required this.node, required this.isCurrent});

  @override
  State<_EvolutionCard> createState() => _EvolutionCardState();
}

class _EvolutionCardState extends State<_EvolutionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isInteractive = !widget.isCurrent;

    return MouseRegion(
      cursor: isInteractive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isInteractive) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isInteractive) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: _isHovered
            ? Matrix4.translationValues(0.0, -4.0, 0.0)
            : Matrix4.identity(),
        width: 110,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isCurrent
              ? scheme.primaryContainer
              : (_isHovered
                  ? scheme.primaryContainer.withValues(alpha: 0.3)
                  : scheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(12),
          border: _isHovered
              ? Border.all(
                  color: scheme.primary.withValues(alpha: 0.6),
                  width: 1.5,
                )
              : null,
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // Tocar la etapa actual no hace nada; las demás abren su propio detalle.
          onTap: widget.isCurrent
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PokemonDetailPage(id: widget.node.id),
                    ),
                  ),
          child: Column(
            children: [
              AnimatedScale(
                scale: _isHovered ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Image.network(
                  officialArtwork(widget.node.id),
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                prettyName(widget.node.name),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
