import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import 'pokedex_provider.dart';
import 'pokemon_detail_page.dart';

class PokedexPage extends StatefulWidget {
  const PokedexPage({super.key});

  @override
  State<PokedexPage> createState() => _PokedexPageState();
}

class _PokedexPageState extends State<PokedexPage> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final pos = _controller.position;
      if (pos.pixels >= pos.maxScrollExtent - 300) {
        context.read<PokedexProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PokedexProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pokédex')),
      body: Builder(builder: (_) {
        if (p.items.isEmpty && p.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (p.items.isEmpty && p.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo cargar la lista'),
                const SizedBox(height: 8),
                FilledButton(onPressed: p.loadMore, child: const Text('Reintentar')),
              ],
            ),
          );
        }
        return GridView.builder(
          controller: _controller,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: p.items.length + (p.hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= p.items.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return _PokemonCard(pokemon: p.items[i]);
          },
        );
      }),
    );
  }
}

class _PokemonCard extends StatelessWidget {
  final PokemonSummary pokemon;
  const _PokemonCard({required this.pokemon});

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
                      : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                ),
              ),
            ),
            Text('#${pokemon.id.toString().padLeft(3, '0')}',
                style: Theme.of(context).textTheme.labelSmall),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(capitalize(pokemon.name),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }
}
