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
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
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

/// Tarjeta de Pokémon con animaciones hover premium:
/// - Elevación + traslación vertical suave
/// - Escala del sprite con curva easeOutBack
/// - Glow del color del tipo en el borde
/// - Fondo degradado sutil del color del tipo al hacer hover
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
    final scheme = Theme.of(context).colorScheme;
    // Usa el color primario del tema para el glow en la lista
    // (PokemonSummary no incluye tipos; el tipo real se carga en PokemonDetailPage)
    final glowColor = Theme.of(context).colorScheme.primary;

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
              offset: Offset(0, -6 * t),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    scheme.surfaceContainerHighest,
                    glowColor.withValues(alpha: 0.14),
                    t,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color.lerp(
                      scheme.outlineVariant.withValues(alpha: 0.0),
                      glowColor.withValues(alpha: 0.65),
                      t,
                    )!,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.22 * t),
                      blurRadius: 16 * t,
                      spreadRadius: 2 * t,
                      offset: Offset(0, 6 * t),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06 + 0.08 * t),
                      blurRadius: 4 + 8 * t,
                      offset: Offset(0, 2 + 4 * t),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedBuilder(
                    animation: _hoverAnim,
                    builder: (context, child) => Transform.scale(
                      scale: 1.0 + 0.12 * _hoverAnim.value,
                      child: child,
                    ),
                    child: Image.network(
                      widget.pokemon.imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (c, child, prog) => prog == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
              Text(
                '#${widget.pokemon.id.toString().padLeft(3, '0')}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedBuilder(
                  animation: _hoverAnim,
                  builder: (context, child) => Text(
                    prettyName(widget.pokemon.name),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.lerp(
                        FontWeight.w500,
                        FontWeight.w700,
                        _hoverAnim.value,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
