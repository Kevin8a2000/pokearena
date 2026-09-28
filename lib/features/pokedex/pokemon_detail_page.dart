import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/evolution.dart';
import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';
import '../../core/theme/type_colors.dart';

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
      appBar: AppBar(title: const Text('Detalle')),
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
              SizedBox(
                height: 220,
                child: Image.network(d.imageUrl, fit: BoxFit.contain),
              ),
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

class _EvolutionCard extends StatelessWidget {
  final EvolutionNode node;
  final bool isCurrent;
  const _EvolutionCard({required this.node, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      // Tocar la etapa actual no hace nada; las demás abren su propio detalle.
      onTap: isCurrent
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => PokemonDetailPage(id: node.id)),
              ),
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrent
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Image.network(
              officialArtwork(node.id),
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
            ),
            const SizedBox(height: 4),
            Text(prettyName(node.name),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
