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
    _search.clear(); // limpia el texto y luego el estado del provider
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

class _PokemonCard extends StatelessWidget {
  final PokemonSummary pokemon;
  const _PokemonCard({super.key, required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PokemonDetailPage(id: pokemon.id)),
      ),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.network(
                  pokemon.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, child, prog) => prog == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                ),
              ),
            ),
            Text('#${pokemon.id.toString().padLeft(3, '0')}',
                style: Theme.of(context).textTheme.labelSmall),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(prettyName(pokemon.name),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }
}
