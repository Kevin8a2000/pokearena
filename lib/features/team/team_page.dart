import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/theme/type_colors.dart';
import '../pokedex/pokemon_detail_page.dart';
import 'team_coverage_calculator.dart';
import 'team_provider.dart';

/// MÓDULO: Equipo y cobertura de tipos (Sprint 2, tareas E1 a E6)
/// Permite gestionar hasta 6 integrantes y calcula en tiempo real
/// las debilidades y resistencias defensivas combinadas ante los 18 tipos elementales.
class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<TeamProvider>(
          builder: (context, teamProvider, _) {
            return Text('Mi Equipo (${teamProvider.count}/${TeamProvider.maxTeamSize})');
          },
        ),
        actions: [
          Consumer<TeamProvider>(
            builder: (context, teamProvider, _) {
              if (teamProvider.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Vaciar equipo',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _confirmClearTeam(context, teamProvider),
              );
            },
          ),
        ],
      ),
      body: Consumer<TeamProvider>(
        builder: (context, teamProvider, _) {
          if (teamProvider.isLoadingTeam) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Sección de integrantes del equipo
              _TeamSlotsSection(teamProvider: teamProvider),
              const SizedBox(height: 24),

              // Sección de análisis de cobertura
              _TeamCoverageSection(teamProvider: teamProvider),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _confirmClearTeam(BuildContext context, TeamProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Vaciar equipo?'),
        content: const Text('Se quitarán todos los Pokémon de tu equipo actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              provider.clearTeam();
              Navigator.of(ctx).pop();
            },
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
  }
}

/// Muestra los 6 espacios del equipo con sus Pokémon o un espacio vacío indicador.
class _TeamSlotsSection extends StatelessWidget {
  final TeamProvider teamProvider;

  const _TeamSlotsSection({required this.teamProvider});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final team = teamProvider.team;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Integrantes', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              '${team.length} de ${TeamProvider.maxTeamSize} seleccionados',
              style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (team.isEmpty)
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.catching_pokemon, size: 50, color: Colors.redAccent),
                  SizedBox(height: 12),
                  Text(
                    'Tu equipo está vacío',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Dirígete a la Pokédex y abre el detalle de cualquier Pokémon para añadirlo a tu equipo (máximo 6).',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemCount: TeamProvider.maxTeamSize,
            itemBuilder: (context, index) {
              if (index < team.length) {
                final pokemon = team[index];
                return _PokemonSlotCard(
                  pokemon: pokemon,
                  onRemove: () => teamProvider.removePokemon(pokemon.id),
                );
              }
              return const _EmptySlotCard();
            },
          ),
      ],
    );
  }
}

/// Tarjeta individual para un Pokémon en el equipo.
class _PokemonSlotCard extends StatelessWidget {
  final PokemonDetail pokemon;
  final VoidCallback onRemove;

  const _PokemonSlotCard({required this.pokemon, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PokemonDetailPage(id: pokemon.id)),
          );
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Image.network(
                      pokemon.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prettyName(pokemon.name),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final t in pokemon.types)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorForType(t),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            typeNameEs(t),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PositionByKey(
              top: 2,
              right: 2,
              child: IconButton(
                iconSize: 20,
                tooltip: 'Quitar del equipo',
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surface.withValues(alpha: 0.8),
                  padding: const EdgeInsets.all(4),
                ),
                icon: Icon(Icons.close, color: scheme.error),
                onPressed: onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper para posicionamiento limpio en Stack.
class PositionByKey extends StatelessWidget {
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final Widget child;

  const PositionByKey({
    super.key,
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(top: top, right: right, bottom: bottom, left: left, child: child);
  }
}

/// Espacio vacío en la grilla de integrantes.
class _EmptySlotCard extends StatelessWidget {
  const _EmptySlotCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: scheme.outline),
            const SizedBox(height: 4),
            Text('Disponible', style: TextStyle(color: scheme.outline, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Sección de Cobertura de tipos (Requisito E4 y E5).
class _TeamCoverageSection extends StatelessWidget {
  final TeamProvider teamProvider;

  const _TeamCoverageSection({required this.teamProvider});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Cobertura Defensiva', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (teamProvider.isLoadingCoverage)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Multiplicador de daño recibido frente a cada tipo elemental atacante (combinando las relaciones de todos los Pokémon):',
          style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 12),

        // Leyenda explicativa de colores
        const _CoverageLegend(),
        const SizedBox(height: 12),

        // Grilla con los 18 tipos elementales
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemCount: TeamCoverageCalculator.allPokemonTypes.length,
          itemBuilder: (context, index) {
            final type = TeamCoverageCalculator.allPokemonTypes[index];
            final multiplier = teamProvider.combinedMultipliers[type] ?? 1.0;
            final info = teamProvider.detailedCoverage[type];

            return _TypeCoverageTile(
              type: type,
              multiplier: multiplier,
              info: info,
            );
          },
        ),
      ],
    );
  }
}

/// Leyenda de colores para entender las debilidades y resistencias.
class _CoverageLegend extends StatelessWidget {
  const _CoverageLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: const [
        _LegendItem(color: Colors.redAccent, label: 'Debilidad (> 1x)'),
        _LegendItem(color: Colors.green, label: 'Resistencia (< 1x)'),
        _LegendItem(color: Colors.blueGrey, label: 'Inmunidad (0x)'),
        _LegendItem(color: Colors.grey, label: 'Neutro (1x)'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// Fila/celda de un tipo con su color, multiplicador y estado defensivo.
class _TypeCoverageTile extends StatelessWidget {
  final String type;
  final double multiplier;
  final TypeCoverageInfo? info;

  const _TypeCoverageTile({
    required this.type,
    required this.multiplier,
    this.info,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = colorForType(type);

    // Formatear el multiplicador
    final String multText;
    if (multiplier == 0.0) {
      multText = 'x0';
    } else if (multiplier == multiplier.roundToDouble()) {
      multText = 'x${multiplier.toInt()}';
    } else {
      multText = 'x${multiplier.toStringAsFixed(2)}';
    }

    // Color del badge según la intensidad del multiplicador
    final Color badgeBg;
    final Color badgeFg;
    final String statusLabel;

    if (multiplier == 0.0) {
      badgeBg = Colors.purple.shade700;
      badgeFg = Colors.white;
      statusLabel = 'Inmune';
    } else if (multiplier > 1.0) {
      badgeBg = multiplier >= 4.0 ? Colors.red.shade900 : Colors.red.shade600;
      badgeFg = Colors.white;
      statusLabel = multiplier >= 4.0 ? 'Muy Débil' : 'Débil';
    } else if (multiplier < 1.0) {
      badgeBg = multiplier <= 0.25 ? Colors.green.shade800 : Colors.green.shade600;
      badgeFg = Colors.white;
      statusLabel = 'Resiste';
    } else {
      badgeBg = Theme.of(context).colorScheme.surfaceContainerHighest;
      badgeFg = Theme.of(context).colorScheme.onSurfaceVariant;
      statusLabel = 'Neutro';
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: multiplier > 1.0
              ? Colors.redAccent.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: multiplier > 1.0 ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Píldora del tipo con su color distintivo
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              typeNameEs(type),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Multiplicador y estado
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  multText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: multiplier > 1.0
                        ? Colors.redAccent
                        : (multiplier < 1.0 ? Colors.green : null),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: badgeFg, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
