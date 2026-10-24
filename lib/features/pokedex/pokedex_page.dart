import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/theme/type_colors.dart';
import '../../core/widgets/poke_image.dart';
import '../../core/widgets/poke_widgets.dart';
import '../../core/widgets/pokeball_background.dart';
import '../settings/settings_provider.dart';
import '../team/team_provider.dart';
import '../wallet/coin_chip.dart';
import '../wallet/wallet_provider.dart';
import 'pokedex_provider.dart';
import 'pokemon_detail_page.dart';

const _generationLabels = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];

const _navy = Color(0xFF0A1330);
const _blue = Color(0xFF2A5DB0);
const _gold = Color(0xFFFFCB05);

/// Icono por tipo en inglés (claves de `typeColors`).
IconData typeIcon(String t) => switch (t.toLowerCase()) {
      'normal' => Icons.circle_outlined,
      'fire' => Icons.local_fire_department,
      'water' => Icons.water_drop,
      'electric' => Icons.bolt,
      'grass' => Icons.eco,
      'ice' => Icons.ac_unit,
      'fighting' => Icons.sports_mma,
      'poison' => Icons.science,
      'ground' => Icons.terrain,
      'flying' => Icons.air,
      'psychic' => Icons.psychology,
      'bug' => Icons.bug_report,
      'rock' => Icons.landscape,
      'ghost' => Icons.nightlight_round,
      'dragon' => Icons.whatshot,
      'dark' => Icons.dark_mode,
      'steel' => Icons.settings,
      'fairy' => Icons.auto_awesome,
      _ => Icons.star,
    };

/// Texto legible sobre [bg]: blanco en fondos oscuros y azul marino en claros.
Color _onColor(Color bg) => ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : const Color(0xFF14224C);

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

class PokedexPage extends StatefulWidget {
  const PokedexPage({super.key});

  @override
  State<PokedexPage> createState() => _PokedexPageState();
}

class _PokedexPageState extends State<PokedexPage> {
  final _search = TextEditingController();

  /// Se esconde al deslizar las tarjetas hacia arriba y reaparece al
  /// deslizar hacia abajo (sin importar cuánto se haya bajado), para dejar
  /// más sitio a las tarjetas cuando se quiera.
  bool _headerVisible = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearAll() {
    _search.clear();
    context.read<PokedexProvider>().clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PokedexProvider>();
    final wallpaper = context.watch<SettingsProvider>().wallpaper;
    // Apaisado: la cabecera (título, buscador, filtros) se achica para
    // dejar espacio de verdad a las tarjetas debajo (antes ocupaba casi
    // toda la pantalla y no quedaba sitio para verlas).
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      backgroundColor: _navy,
      body: Stack(
        children: [
          // Fondo: azul marino con Pokébolas (predeterminado) o el elegido en Ajustes.
          Positioned.fill(
            child: wallpaper == kNavyWallpaper
                ? const PokeballBackground()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        wallpaper,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const PokeballBackground(),
                      ),
                      Container(color: Colors.black.withValues(alpha: 0.40)),
                    ],
                  ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _headerVisible
                        ? Column(
                            children: [
                              _Header(compact: landscape),
                              Padding(
                                padding: EdgeInsets.fromLTRB(14, landscape ? 2 : 6, 14, landscape ? 2 : 4),
                                child: _SearchField(controller: _search, onChanged: p.onQueryChanged, compact: landscape),
                              ),
                              _FilterRow(compact: landscape, chips: [
                                _FilterChip(
                                  label: 'Todos los tipos',
                                  color: _blue,
                                  selected: p.selectedType == null,
                                  compact: landscape,
                                  onTap: () => p.selectType(null),
                                ),
                                for (final t in typeColors.keys)
                                  _FilterChip(
                                    label: typeNameEs(t),
                                    color: colorForType(t),
                                    icon: typeIcon(t),
                                    selected: p.selectedType == t,
                                    compact: landscape,
                                    onTap: () => p.selectType(p.selectedType == t ? null : t),
                                  ),
                              ]),
                              _FilterRow(compact: landscape, chips: [
                                _FilterChip(
                                  label: 'Todas las gen.',
                                  color: _blue,
                                  selected: p.selectedGeneration == null,
                                  compact: landscape,
                                  onTap: () => p.selectGeneration(null),
                                ),
                                _GenerationMenu(selected: p.selectedGeneration, onSelected: p.selectGeneration, compact: landscape),
                              ]),
                            ],
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                ),
                Expanded(
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: (n) {
                      if (n.direction == ScrollDirection.reverse && _headerVisible) {
                        setState(() => _headerVisible = false);
                      } else if (n.direction == ScrollDirection.forward && !_headerVisible) {
                        setState(() => _headerVisible = true);
                      }
                      return false;
                    },
                    child: _buildBody(p, landscape),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(PokedexProvider p, bool landscape) {
    if (p.loading && !p.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null && !p.hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            FilledButton(onPressed: p.load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (p.filtering) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = p.visible;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, landscape ? 1 : 2, 16, 0),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: landscape ? 10 : 14, vertical: landscape ? 2 : 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _gold, width: landscape ? 1.5 : 2),
                ),
                child: Text(
                  p.filterError ?? '${items.length} Pokémon',
                  style: TextStyle(
                    color: p.filterError != null ? Theme.of(context).colorScheme.error : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: landscape ? 12 : 15,
                  ),
                ),
              ),
              const Spacer(),
              if (p.hasActiveFilters)
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Limpiar', style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off, size: 48, color: Colors.white70),
                      const SizedBox(height: 8),
                      const Text('Sin resultados', style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _clearAll, child: const Text('Limpiar filtros')),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, cons) {
                    // Móvil: 2 columnas de tarjetas grandes; tablet/web: por ancho.
                    final w = cons.maxWidth;
                    final cols = w < 600 ? 2 : (w / 230).floor().clamp(3, 8);
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(12, landscape ? 4 : 10, 12, 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: cols == 2 ? 1.12 : 1.25,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _PokemonCard(key: ValueKey(items[i].id), pokemon: items[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Cabecera: logo "Pokédex" centrado y la moneda en píldora dorada a la derecha.
/// En [compact] (apaisado) se achica para dejar sitio a las tarjetas.
class _Header extends StatelessWidget {
  final bool compact;
  const _Header({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 32 : 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(child: PokeLogoText('Pokédex', size: compact ? 20 : 38, arched: !compact)),
            const Align(alignment: Alignment.centerRight, child: CoinChip(golden: true)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool compact;
  const _SearchField({required this.controller, required this.onChanged, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: compact ? 14 : 18, color: const Color(0xFF14224C)),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: _blue, size: compact ? 20 : 30),
          hintText: 'Buscar por nombre o número',
          hintStyle: TextStyle(fontSize: compact ? 14 : 18, color: Colors.blueGrey.shade400),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: compact ? 4 : 16),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: _blue, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: _gold, width: 3)),
        ),
      ),
    );
  }
}

/// Fila horizontal de chips con scroll.
class _FilterRow extends StatelessWidget {
  final List<Widget> chips;
  final bool compact;
  const _FilterRow({required this.chips, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 36 : 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 3 : 6),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

/// Chip de filtro con el color del tipo: seleccionado lleva ✓ y borde blanco.
class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.color, required this.selected, required this.onTap, this.icon, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // "Normal" se ve gris claro como en el diseño; el resto, con su color.
    final bg = label == 'Normal' ? const Color(0xFFD9DCE3) : color;
    final fg = _onColor(bg);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? Colors.white : Colors.white.withValues(alpha: 0.18), width: selected ? 2.5 : 1.5),
            boxShadow: [
              if (selected) BoxShadow(color: bg.withValues(alpha: 0.7), blurRadius: 10, spreadRadius: 1),
              const BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Icon(Icons.check, size: compact ? 15 : 20, color: fg)
              else if (icon != null)
                Icon(icon, size: compact ? 15 : 20, color: fg),
              if (selected || icon != null) const SizedBox(width: 6),
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: compact ? 12 : 16)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Gen ▾" en beige: abre el menú de generaciones.
class _GenerationMenu extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onSelected;
  final bool compact;
  const _GenerationMenu({required this.selected, required this.onSelected, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Elegir generación',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (var g = 1; g <= _generationLabels.length; g++) PopupMenuItem(value: g, child: Text('Gen ${_generationLabels[g - 1]}')),
      ],
      child: Container(
        padding: EdgeInsets.only(left: compact ? 10 : 16, right: compact ? 4 : 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1E3C6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected != null ? Colors.white : Colors.white.withValues(alpha: 0.4), width: selected != null ? 2.5 : 1.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected == null ? 'Gen' : 'Gen ${_generationLabels[selected! - 1]}',
              style: TextStyle(color: const Color(0xFF14224C), fontWeight: FontWeight.w800, fontSize: compact ? 12 : 16),
            ),
            Icon(Icons.arrow_drop_down, color: const Color(0xFF14224C), size: compact ? 20 : 28),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de Pokémon: fondo con el color del tipo primario y borde más
/// oscuro, nombre y #número arriba, etiquetas de tipo abajo a la izquierda y
/// el Pokémon grande sobre el aro de Pokébola. Mantiene el hover (elevación +
/// escala + brillo del tipo).
class _PokemonCard extends StatefulWidget {
  final PokemonSummary pokemon;
  const _PokemonCard({super.key, required this.pokemon});

  @override
  State<_PokemonCard> createState() => _PokemonCardState();
}

class _PokemonCardState extends State<_PokemonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _hoverAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _hoverAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter(_) => _controller.forward();

  void _onExit(_) => _controller.reverse();

  Widget _typePill(String t, bool primary) {
    final color = colorForType(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: primary ? Colors.white.withValues(alpha: 0.28) : _darken(color, 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: primary ? 0.0 : 0.55), width: 1.2),
      ),
      child: Text(
        typeNameEs(t),
        maxLines: 1,
        style: TextStyle(color: primary ? Colors.white : _onColor(color), fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Solo re-escucha los tipos de ESTE id para no reconstruir toda la grilla.
    final types = context.select<PokedexProvider, List<String>>((p) => p.typesFor(widget.pokemon.id));
    final baseColor = types.isNotEmpty ? colorForType(types.first) : Colors.blueGrey;
    final locked = !context.select<WalletProvider, bool>((w) => w.isUnlocked(widget.pokemon.id));
    final inTeam = context.select<TeamProvider, bool>((t) => t.isInTeam(widget.pokemon.id));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _onEnter,
      onExit: _onExit,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PokemonDetailPage(id: widget.pokemon.id))),
        child: AnimatedBuilder(
          animation: _hoverAnim,
          builder: (context, child) {
            final t = _hoverAnim.value;
            return Transform.translate(
              offset: Offset(0, -5 * t),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(baseColor, Colors.black, t * 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _darken(baseColor, 0.22), width: 2.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 3)),
                    BoxShadow(color: baseColor.withValues(alpha: 0.25 + 0.25 * t), blurRadius: 10 + 10 * t, spreadRadius: 1 * t),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.5),
            child: LayoutBuilder(
              builder: (context, cons) {
                final w = cons.maxWidth;
                final h = cons.maxHeight;
                return Stack(
                  children: [
                    // Siluetas de Pokémon detrás del Pokémon.
                    Positioned.fill(child: PokemonPattern(cell: h * 0.5, color: const Color(0x2EFFFFFF), seed: widget.pokemon.id)),
                    // Pokémon grande, abajo a la derecha.
                    Positioned(
                      right: 4,
                      bottom: 2,
                      width: w * 0.62,
                      height: h * 0.80,
                      child: AnimatedBuilder(
                        animation: _hoverAnim,
                        builder: (context, child) => Transform.scale(scale: 1.0 + 0.10 * _hoverAnim.value, alignment: Alignment.bottomCenter, child: child),
                        child: PokeImage(id: widget.pokemon.id, fit: BoxFit.contain, cacheWidth: 320),
                      ),
                    ),
                    // Nombre y número.
                    Positioned(
                      left: 12,
                      right: 10,
                      top: 10,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              prettyName(widget.pokemon.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, shadows: [Shadow(color: Colors.black45, blurRadius: 3)]),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '#${widget.pokemon.id.toString().padLeft(3, '0')}',
                            style: const TextStyle(color: Color(0xFFFFE082), fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          if (locked)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.lock, size: 15, color: Colors.white),
                            ),
                          if (inTeam)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.check_circle, size: 15, color: Colors.greenAccent),
                            ),
                        ],
                      ),
                    ),
                    // Etiquetas de tipo (o puntos mientras carga el mapa).
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (types.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(14)),
                              child: const Text('···', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          else
                            for (var i = 0; i < types.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: _typePill(types[i], i == 0),
                              ),
                        ],
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
