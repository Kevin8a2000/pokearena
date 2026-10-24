import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/theme/poke_design.dart';
import '../../core/theme/type_colors.dart';
import '../../core/widgets/poke_image.dart';
import '../../core/widgets/poke_widgets.dart';
import '../../core/widgets/pokeball_background.dart';
import '../home/home_shell.dart';
import '../pokedex/pokemon_detail_page.dart';
import '../settings/settings_provider.dart';
import '../wallet/coin_chip.dart';
import 'team_coverage_calculator.dart';
import 'team_provider.dart';

/// MÓDULO: Equipo y cobertura de tipos (Sprint 2, tareas E1 a E6)
/// Permite gestionar hasta 6 integrantes y calcula en tiempo real
/// las debilidades y resistencias defensivas combinadas ante los 18 tipos elementales.
///
/// Diseño "colores Pokémon": fondo marino con Pokébolas, título amarillo,
/// tarjetas por tipo con aro de Pokébola, huecos "Disponible" y panel azul de
/// cobertura con borde dorado.
class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      var seen = true;
      try {
        seen = context.read<SettingsProvider>().teamTutorialSeen;
      } catch (_) {}
      if (!seen) _showTeamHelp(context, markSeen: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PokeScaffold(
      title: Consumer<TeamProvider>(
        builder: (context, team, _) => PokeLogoText('Mi Equipo (${team.count}/${TeamProvider.maxTeamSize})', size: 34),
      ),
      actions: [
        const CoinChip(golden: true),
        Tooltip(
          message: 'Cómo funciona',
          child: GestureDetector(
            onTap: () => _showTeamHelp(context),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.help_outline, color: Colors.white, size: 32, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
            ),
          ),
        ),
        Consumer<TeamProvider>(
          builder: (context, team, _) {
            if (team.isEmpty) return const SizedBox.shrink();
            return Tooltip(
              message: 'Vaciar equipo',
              child: GestureDetector(
                onTap: () => _confirmClearTeam(context, team),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, color: PokeColors.redLight, size: 36, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                ),
              ),
            );
          },
        ),
      ],
      body: Consumer<TeamProvider>(
        builder: (context, teamProvider, _) {
          if (teamProvider.isLoadingTeam) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  _TeamSlotsSection(teamProvider: teamProvider),
                  const SizedBox(height: 20),
                  _TeamCoverageSection(teamProvider: teamProvider),
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
        backgroundColor: PokeColors.navyPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: PokeColors.gold, width: 2.5)),
        title: Text('¿Vaciar equipo?', style: pokeText(24, color: PokeColors.goldLight)),
        content: const Text('Se quitarán todos los Pokémon de tu equipo actual.', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
          PokeButton(
            label: 'Vaciar',
            height: 40,
            fontSize: 16,
            onPressed: () {
              provider.clearTeam();
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}

/// Explica los huecos del equipo y cómo leer la Cobertura Defensiva.
/// [markSeen]: true cuando se abre sola la primera vez (la marca como vista
/// al cerrarla); desde el icono `?` se puede reabrir siempre sin marcar nada.
void _showTeamHelp(BuildContext context, {bool markSeen = false}) {
  SettingsProvider? settings;
  if (markSeen) {
    try {
      settings = context.read<SettingsProvider>();
    } catch (_) {}
  }
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: PokeColors.navyPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: PokeColors.gold, width: 2.5)),
      title: Text('Cómo funciona tu equipo', style: pokeText(22, color: PokeColors.goldLight)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Arma tu equipo (hasta 6)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              const Text(
                'Toca un hueco "Disponible" para ir a la Pokédex y elegir un Pokémon. Toca la ✕ de una tarjeta para quitar a ese Pokémon, o el bote de basura de arriba para vaciar todo el equipo.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 16),
              const Text('Cobertura Defensiva', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              const Text(
                'Es el daño que recibiría tu equipo COMPLETO si lo atacaran con cada tipo elemental, combinando las resistencias y debilidades de todos tus Pokémon a la vez. Te sirve para ver qué tipos te dejan expuesto antes de entrar a pelear.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 8),
              const _CoverageLegend(),
              const SizedBox(height: 6),
              const Text(
                'x1 = daño normal · más de x1 = te pegan más fuerte (débil) · menos de x1 = te pegan menos (resistes) · x0 = ese tipo no te hace nada.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
      actions: [
        PokeButton(
          label: '¡Entendido!',
          height: 40,
          fontSize: 16,
          onPressed: () {
            settings?.markTeamTutorialSeen();
            Navigator.of(ctx).pop();
          },
        ),
      ],
    ),
  );
}

/// Los 6 espacios del equipo (2 columnas): Pokémon o hueco "Disponible".
class _TeamSlotsSection extends StatelessWidget {
  final TeamProvider teamProvider;
  const _TeamSlotsSection({required this.teamProvider});

  @override
  Widget build(BuildContext context) {
    final team = teamProvider.team;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (team.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PokePanel(
              child: Column(
                children: [
                  Text('Tu equipo está vacío (0/6)', style: pokeText(20, color: PokeColors.goldLight)),
                  const SizedBox(height: 6),
                  const Text('Cómo armar tu equipo:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    '1. Ve a la pestaña Pokédex (abajo a la izquierda).\n2. Selecciona cualquier Pokémon.\n3. Toca el botón "Agregar al equipo".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, cons) {
            final cols = cons.maxWidth < 600 ? 2 : 3;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: cols == 2 ? 1.02 : 1.1,
              ),
              itemCount: TeamProvider.maxTeamSize,
              itemBuilder: (context, index) {
                if (index < team.length) {
                  final pokemon = team[index];
                  return _PokemonSlotCard(key: ValueKey(pokemon.id), pokemon: pokemon, onRemove: () => teamProvider.removePokemon(pokemon.id));
                }
                return _EmptySlotCard(light: (index - team.length).isOdd, onTap: () => HomeShell.goToTab(context, 0));
              },
            );
          },
        ),
      ],
    );
  }
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

/// Tarjeta de un Pokémon del equipo: color de su tipo, borde oscuro, aro de
/// Pokébola, el Pokémon grande, su nombre y las etiquetas de tipo. Mantiene el
/// hover (elevación, brillo y rebote del sprite).
class _PokemonSlotCard extends StatefulWidget {
  final PokemonDetail pokemon;
  final VoidCallback onRemove;
  const _PokemonSlotCard({super.key, required this.pokemon, required this.onRemove});

  @override
  State<_PokemonSlotCard> createState() => _PokemonSlotCardState();
}

class _PokemonSlotCardState extends State<_PokemonSlotCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
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
    final types = widget.pokemon.types;
    final base = colorForType(types.isNotEmpty ? types.first : 'normal');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _enter,
      onExit: _exit,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;
          return Transform.translate(
            offset: Offset(0, -6 * t),
            child: Container(
              decoration: BoxDecoration(
                color: Color.lerp(base, Colors.black, t * 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _darken(base, 0.28), width: 3),
                boxShadow: [
                  const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
                  BoxShadow(color: base.withValues(alpha: 0.25 + 0.3 * t), blurRadius: 10 + 10 * t),
                ],
              ),
              child: child,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PokemonDetailPage(id: widget.pokemon.id))),
            child: LayoutBuilder(
              builder: (context, cons) {
                final w = cons.maxWidth;
                final h = cons.maxHeight;
                return Stack(
                  children: [
                    // Siluetas de Pokémon detrás.
                    Positioned.fill(child: PokemonPattern(cell: h * 0.45, color: const Color(0x2EFFFFFF), seed: widget.pokemon.id)),
                    // Pokémon grande.
                    Positioned(
                      left: w * 0.12,
                      right: w * 0.12,
                      top: h * 0.04,
                      height: h * 0.60,
                      child: AnimatedBuilder(
                        animation: _anim,
                        builder: (context, child) => Transform.scale(scale: 1.0 + 0.10 * Curves.easeOutBack.transform(_anim.value), alignment: Alignment.bottomCenter, child: child),
                        child: PokeImage(id: widget.pokemon.id, fit: BoxFit.contain, cacheWidth: 320, placeholderColor: Colors.white70),
                      ),
                    ),
                    // Nombre y tipos.
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 10,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(prettyName(widget.pokemon.name), maxLines: 1, style: pokeText(22, shadows: pokeTextShadow)),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 5,
                            runSpacing: 3,
                            alignment: WrapAlignment.center,
                            children: [for (var i = 0; i < types.length; i++) TypePill(type: types[i], primary: i == 0, fontSize: 11)],
                          ),
                        ],
                      ),
                    ),
                    // Quitar del equipo.
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Tooltip(
                        message: 'Quitar del equipo',
                        child: GestureDetector(
                          onTap: widget.onRemove,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2))],
                            ),
                            child: const Icon(Icons.close, color: PokeColors.red, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Hueco libre: tarjeta clara con una Pokébola con "+" dorado y "Disponible".
/// Los huecos van alternando gris azulado y azul muy claro (como el diseño).
class _EmptySlotCard extends StatefulWidget {
  final VoidCallback? onTap;
  final bool light;
  const _EmptySlotCard({this.onTap, this.light = false});

  @override
  State<_EmptySlotCard> createState() => _EmptySlotCardState();
}

class _EmptySlotCardState extends State<_EmptySlotCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.light ? const Color(0xFFE6F0FB) : const Color(0xFFCDD3E0);
    final label = widget.light ? PokeColors.goldLight : Colors.white;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: 'Ir a la Pokédex para elegir',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.light ? const Color(0xFF7FA8DC) : const Color(0xFF8D96AA), width: 3),
              boxShadow: [const BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)), if (_hover) BoxShadow(color: PokeColors.gold.withValues(alpha: 0.5), blurRadius: 12)],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned.fill(child: Padding(padding: EdgeInsets.all(6), child: PokeBallIcon(size: 72))),
                        Positioned(
                          right: -6,
                          top: -2,
                          child: Text('+', style: pokeText(46, color: PokeColors.goldLight, shadows: const [Shadow(color: Colors.black87, blurRadius: 0, offset: Offset(2, 2))])),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Disponible', style: pokeText(22, color: label, shadows: const [Shadow(color: Colors.black87, blurRadius: 0, offset: Offset(1.5, 1.5))])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sección de Cobertura de tipos (Requisito E4 y E5): panel azul con borde dorado.
class _TeamCoverageSection extends StatelessWidget {
  final TeamProvider teamProvider;
  const _TeamCoverageSection({required this.teamProvider});

  @override
  Widget build(BuildContext context) {
    return PokePanel(
      color: PokeColors.panelBlue,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('Cobertura Defensiva', style: pokeText(26, color: PokeColors.goldLight, shadows: pokeTextShadow))),
              if (teamProvider.isLoadingCoverage) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Multiplicador de daño recibido frente a cada tipo elemental atacante (combinando las relaciones de todos los Pokémon):',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.25, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          const _CoverageLegend(),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, cons) {
              final cols = cons.maxWidth < 520 ? 2 : (cons.maxWidth / 240).floor().clamp(2, 5);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: 70, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: TeamCoverageCalculator.allPokemonTypes.length,
                itemBuilder: (context, index) {
                  final type = TeamCoverageCalculator.allPokemonTypes[index];
                  return _TypeCoverageTile(
                    type: type,
                    multiplier: teamProvider.combinedMultipliers[type] ?? 1.0,
                    info: teamProvider.detailedCoverage[type],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Leyenda de colores para entender las debilidades y resistencias.
class _CoverageLegend extends StatelessWidget {
  const _CoverageLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendItem(color: Color(0xFFE53935), label: 'Debilidad (> 1x)'),
        _LegendItem(color: Color(0xFF43A047), label: 'Resistencia (< 1x)'),
        _LegendItem(color: Color(0xFF1A2A6C), label: 'Inmunidad (0x)'),
        _LegendItem(color: Color(0xFF9E9E9E), label: 'Neutro (1x)'),
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
        Container(width: 13, height: 13, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.2))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Ficha de un tipo: su píldora de color, el multiplicador y el estado
/// defensivo (Neutro / Resiste / Débil / Inmune).
class _TypeCoverageTile extends StatefulWidget {
  final String type;
  final double multiplier;
  final TypeCoverageInfo? info;
  const _TypeCoverageTile({required this.type, required this.multiplier, this.info});

  @override
  State<_TypeCoverageTile> createState() => _TypeCoverageTileState();
}

class _TypeCoverageTileState extends State<_TypeCoverageTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final typeColor = colorForType(widget.type);
    final m = widget.multiplier;

    final String multText;
    if (m == 0.0) {
      multText = 'x0';
    } else if (m == m.roundToDouble()) {
      multText = 'x${m.toInt()}';
    } else {
      multText = 'x${m.toStringAsFixed(2)}';
    }

    final Color badgeBg;
    final String status;
    if (m == 0.0) {
      badgeBg = const Color(0xFF1A2A6C);
      status = 'Inmune';
    } else if (m > 1.0) {
      badgeBg = m >= 4.0 ? const Color(0xFF8E1B1B) : const Color(0xFFE53935);
      status = m >= 4.0 ? 'Muy Débil' : 'Débil';
    } else if (m < 1.0) {
      badgeBg = m <= 0.25 ? const Color(0xFF2E7D32) : const Color(0xFF43A047);
      status = 'Resiste';
    } else {
      badgeBg = const Color(0xFF9E9E9E);
      status = 'Neutro';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF3E78BF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hover ? PokeColors.goldLight : const Color(0xFF16305F), width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Píldora del tipo con su color.
            Flexible(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _darken(typeColor, 0.3), width: 2),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    typeNameEs(widget.type),
                    style: TextStyle(color: ThemeData.estimateBrightnessForColor(typeColor) == Brightness.dark ? Colors.white : PokeColors.ink, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Multiplicador y estado.
            Flexible(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text(multText, style: pokeText(20, shadows: pokeTextShadow))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white54, width: 1)),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
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
