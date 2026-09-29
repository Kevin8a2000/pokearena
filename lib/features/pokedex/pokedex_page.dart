import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/theme/type_colors.dart';
import 'pokedex_provider.dart';
import 'pokemon_detail_page.dart';

const _generationLabels = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];

class PokedexPage extends StatefulWidget {
  const PokedexPage({super.key});

  @override
  State<PokedexPage> createState() => _PokedexPageState();
}

class _PokedexPageState extends State<PokedexPage> {
  final _search = TextEditingController();

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

    return Scaffold(
      appBar: AppBar(title: const Text('Pokédex')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: p.onQueryChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar por nombre o número',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                isDense: true,
              ),
            ),
          ),
          _FilterRow(chips: [
            ChoiceChip(
              label: const Text('Todos los tipos'),
              selected: p.selectedType == null,
              onSelected: (_) => p.selectType(null),
            ),
            for (final t in typeColors.keys)
              ChoiceChip(
                label: Text(typeNameEs(t)),
                selected: p.selectedType == t,
                selectedColor: colorForType(t).withValues(alpha: 0.4),
                onSelected: (sel) => p.selectType(sel ? t : null),
              ),
          ]),
          _FilterRow(chips: [
            ChoiceChip(
              label: const Text('Todas las gen.'),
              selected: p.selectedGeneration == null,
              onSelected: (_) => p.selectGeneration(null),
            ),
            for (var g = 1; g <= _generationLabels.length; g++)
              ChoiceChip(
                label: Text('Gen ${_generationLabels[g - 1]}'),
                selected: p.selectedGeneration == g,
                onSelected: (sel) => p.selectGeneration(sel ? g : null),
              ),
          ]),
          Expanded(child: _buildBody(p)),
        ],
      ),
    );
  }

  Widget _buildBody(PokedexProvider p) {
    if (p.loading && !p.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null && !p.hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.error!),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                p.filterError ?? '${items.length} Pokémon',
                style: TextStyle(
                  color: p.filterError != null
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              const Spacer(),
              if (p.hasActiveFilters)
                TextButton(onPressed: _clearAll, child: const Text('Limpiar')),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off, size: 48),
                      const SizedBox(height: 8),
                      const Text('Sin resultados'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _clearAll,
                        child: const Text('Limpiar filtros'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _PokemonCard(
                    key: ValueKey(items[i].id),
                    pokemon: items[i],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Fila horizontal de chips con scroll.
class _FilterRow extends StatelessWidget {
  final List<Widget> chips;
  const _FilterRow({required this.chips});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

/// Tarjeta estilo DIO (referencia del usuario):
/// fondo con el color del tipo primario, #ID arriba-derecha, nombre
/// arriba-izquierda, badges de tipo a la izquierda y sprite a la derecha
/// sobre círculo blanco semitransparente. Mantiene hover premium
/// (elevación + escala del sprite + glow del tipo).
class _PokemonCard extends StatefulWidget {
  final PokemonSummary pokemon;
  const _PokemonCard({super.key, required this.pokemon});

  @override
  State<_PokemonCard> createState() => _PokemonCardState();
}

class _PokemonCardState extends State<_PokemonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _hoverAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _hoverAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter(_) => _controller.forward();

  void _onExit(_) => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    // Solo re-escucha los tipos de ESTE id para no reconstruir toda la grilla.
    final types = context.select<PokedexProvider, List<String>>(
      (p) => p.typesFor(widget.pokemon.id),
    );
    final baseColor =
        types.isNotEmpty ? colorForType(types.first) : Colors.blueGrey;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _onEnter,
      onExit: _onExit,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PokemonDetailPage(id: widget.pokemon.id),
          ),
        ),
        child: AnimatedBuilder(
          animation: _hoverAnim,
          builder: (context, child) {
            final t = _hoverAnim.value;
            return Transform.translate(
              offset: Offset(0, -5 * t),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(baseColor, Colors.black, t * 0.08),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.35 + 0.25 * t),
                      blurRadius: 8 + 10 * t,
                      spreadRadius: 1 * t,
                      offset: Offset(0, 3 + 4 * t),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Stack(
            children: [
              // Marca de agua Pokébola como la referencia (imagen 2):
              // aro grande delgado + banda central + botón interno,
              // inclinado y casi completo dentro de la tarjeta.
              Positioned(
                right: -10,
                bottom: -12,
                child: Transform.rotate(
                  angle: -0.35,
                  child: const _PokeballWatermark(
                    size: 116,
                    color: Color(0xFFFFFFFF),
                    opacity: 0.35,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            prettyName(widget.pokemon.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${widget.pokemon.id.toString().padLeft(3, '0')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Badges de tipo (o placeholder mientras carga el mapa).
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (types.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '···',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                for (final t in types)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.25),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        typeNameEs(t),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                          const SizedBox(width: 6),
                          // Sprite sobre el círculo.
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _hoverAnim,
                              builder: (context, child) => Transform.scale(
                                scale: 1.0 + 0.12 * _hoverAnim.value,
                                child: child,
                              ),
                              child: Image.network(
                                widget.pokemon.imageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (c, child, prog) =>
                                    prog == null
                                        ? child
                                        : const Center(
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white)),
                                errorBuilder: (c, e, s) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
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

/// Marca de agua con forma de Pokébola (igual a la imagen 2 de referencia).
/// Aro exterior delgado + banda horizontal + botón interno con centro,
/// en blanco semitransparente que sobre el color del tipo se ve gris claro.
class _PokeballWatermark extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _PokeballWatermark({
    required this.size,
    required this.color,
    this.opacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PokeballPainter(color.withValues(alpha: opacity)),
      ),
    );
  }
}

class _PokeballPainter extends CustomPainter {
  final Color color;
  const _PokeballPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Aro exterior GRUESO como la referencia (imagen 1).
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.24;

    canvas.drawCircle(c, r * 0.78, ring);

    // Banda horizontal central gruesa.
    final band = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: c, width: r * 1.56, height: r * 0.20),
      band,
    );

    // Botón interno: aro grueso + punto central grande.
    final innerRing = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.14;
    canvas.drawCircle(c, r * 0.24, innerRing);

    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r * 0.12, dot);
  }

  @override
  bool shouldRepaint(covariant _PokeballPainter old) => old.color != color;
}
