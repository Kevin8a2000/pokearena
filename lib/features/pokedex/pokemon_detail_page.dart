import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';
import '../../core/theme/type_colors.dart';

class PokemonDetailPage extends StatefulWidget {
  final int id;
  const PokemonDetailPage({super.key, required this.id});

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  late final Future<PokemonDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<PokeApiService>().fetchPokemonDetail(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: FutureBuilder<PokemonDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return const Center(child: Text('No se pudo cargar el Pokémon'));
          }
          final d = snap.data!;
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
                  '#${d.id.toString().padLeft(3, '0')}  ${capitalize(d.name)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final t in d.types)
                    Chip(
                      label: Text(capitalize(t),
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
              Text('Estadísticas base',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final e in d.stats.entries) _StatBar(name: e.key, value: e.value),
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
          SizedBox(width: 130, child: Text(name)),
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
