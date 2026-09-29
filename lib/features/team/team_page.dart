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

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Sección de integrantes del equipo
                  _TeamSlotsSection(teamProvider: teamProvider),
                  const SizedBox(height: 24),

                  // Sección de análisis de cobertura
                  _TeamCoverageSection(teamProvider: teamProvider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
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
                    'Tu equipo está vacío (0/6)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cómo armar tu equipo:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1. Ve a la pestaña Pokédex (abajo a la izquierda).\n2. Selecciona cualquier Pokémon.\n3. Toca el botón "Agregar al equipo".',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
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

/// Tarjeta individual para un Pokémon en el equipo con animaciones premium al hacer hover:
/// - Elevación suave (traslación Y)
/// - Glow del color del primer tipo del Pokémon
/// - Escala del sprite con curva easeOutBack (efecto rebote)
/// - Fondo degradado sutil hacia el color del tipo
class _PokemonSlotCard extends StatefulWidget {
  final PokemonDetail pokemon;
  final VoidCallback onRemove;

  const _PokemonSlotCard({required this.pokemon, required this.onRemove});

  @override
  State<_PokemonSlotCard> createState() => _PokemonSlotCardState();
}

class _PokemonSlotCardState extends State<_PokemonSlotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _enter(_) => _ctrl.forward();
  void _exit(_) => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typeColor = colorForType(
        widget.pokemon.types.isNotEmpty ? widget.pokemon.types.first : 'normal');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _enter,
      onExit: _exit,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;
          return Transform.translate(
            offset: Offset(0, -7 * t),
            child: Container(
              decoration: BoxDecoration(
                color: Color.lerp(
                  scheme.surface,
                  typeColor.withValues(alpha: 0.15),
                  t,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Color.lerp(
                    scheme.outlineVariant.withValues(alpha: 0.3),
                    typeColor.withValues(alpha: 0.8),
                    t,
                  )!,
                  width: 1 + t * 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.30 * t),
                    blurRadius: 16 * t,
                    spreadRadius: 2 * t,
                    offset: Offset(0, 6 * t),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04 + 0.06 * t),
                    blurRadius: 4 + 6 * t,
                    offset: Offset(0, 2 + 3 * t),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          );
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => PokemonDetailPage(id: widget.pokemon.id)),
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
                      child: AnimatedBuilder(
                        animation: _anim,
                        builder: (context, child) => Transform.scale(
                          // easeOutBack manual: rebota ligeramente más allá de 1.14
                          scale: 1.0 +
                              0.14 *
                                  Curves.easeOutBack
                                      .transform(_anim.value),
                          child: child,
                        ),
                        child: Image.network(
                          widget.pokemon.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) => Text(
                        prettyName(widget.pokemon.name),
                        style: TextStyle(
                          fontWeight: FontWeight.lerp(
                              FontWeight.w600, FontWeight.w800, _anim.value),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final t in widget.pokemon.types)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorForType(t),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeNameEs(t),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
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
                    backgroundColor:
                        Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                    padding: const EdgeInsets.all(4),
                  ),
                  icon: Icon(Icons.close,
                      color: Theme.of(context).colorScheme.error),
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

/// Espacio vacío en la grilla con animación mejorada:
/// - Traslación + glow primario en hover
/// - Ícono "+" que pulsa suavemente con AnimationController
class _EmptySlotCard extends StatefulWidget {
  const _EmptySlotCard();

  @override
  State<_EmptySlotCard> createState() => _EmptySlotCardState();
}

class _EmptySlotCardState extends State<_EmptySlotCard>
    with TickerProviderStateMixin {
  late final AnimationController _hoverCtrl;
  late final Animation<double> _hoverAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnim = CurvedAnimation(
      parent: _hoverCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Pulso suave del ícono + cuando hay hover
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _enter(_) {
    _hoverCtrl.forward();
    _pulseCtrl.repeat(reverse: true);
  }

  void _exit(_) {
    _hoverCtrl.reverse();
    _pulseCtrl.stop();
    _pulseCtrl.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: _enter,
      onExit: _exit,
      child: AnimatedBuilder(
        animation: _hoverAnim,
        builder: (context, child) {
          final t = _hoverAnim.value;
          return Transform.translate(
            offset: Offset(0, -4 * t),
            child: Container(
              decoration: BoxDecoration(
                color: Color.lerp(
                  scheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  scheme.primaryContainer.withValues(alpha: 0.18),
                  t,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Color.lerp(
                    scheme.outlineVariant.withValues(alpha: 0.6),
                    scheme.primary.withValues(alpha: 0.7),
                    t,
                  )!,
                  width: 1 + t * 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.18 * t),
                    blurRadius: 10 * t,
                    offset: Offset(0, 4 * t),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_hoverAnim, _pulseAnim]),
                builder: (context, _) {
                  final scheme = Theme.of(context).colorScheme;
                  return Transform.scale(
                    scale: _pulseAnim.value,
                    child: Icon(
                      Icons.add_circle_outline_rounded,
                      size: 28,
                      color: Color.lerp(
                        scheme.outline,
                        scheme.primary,
                        _hoverAnim.value,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: _hoverAnim,
                builder: (context, _) {
                  final scheme = Theme.of(context).colorScheme;
                  return Text(
                    'Disponible',
                    style: TextStyle(
                      color: Color.lerp(
                        scheme.outline,
                        scheme.primary,
                        _hoverAnim.value,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.lerp(
                        FontWeight.normal,
                        FontWeight.bold,
                        _hoverAnim.value,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
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

        // Grilla con los 18 tipos elementales (adaptativa a pantallas móviles y de escritorio)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 54,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
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

/// Fila/celda de un tipo con su color, multiplicador, estado defensivo y microanimación hover.
class _TypeCoverageTile extends StatefulWidget {
  final String type;
  final double multiplier;
  final TypeCoverageInfo? info;

  const _TypeCoverageTile({
    required this.type,
    required this.multiplier,
    this.info,
  });

  @override
  State<_TypeCoverageTile> createState() => _TypeCoverageTileState();
}

class _TypeCoverageTileState extends State<_TypeCoverageTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final typeColor = colorForType(widget.type);
    final multiplier = widget.multiplier;

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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedSlide(
        offset: _isHovered ? const Offset(0, -0.05) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isHovered
                ? typeColor
                : (multiplier > 1.0
                    ? Colors.redAccent.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
            width: _isHovered ? 2.0 : (multiplier > 1.0 ? 1.5 : 1),
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
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
                typeNameEs(widget.type),
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
      ),
    ),
    );
  }
}
