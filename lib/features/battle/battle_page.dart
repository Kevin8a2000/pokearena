import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';
import '../../core/services/score_history_service.dart';
import '../team/team_provider.dart';
import 'battle_provider.dart';

/// MÓDULO: Simulador de batalla (Sprint 3).
/// Elige de tu equipo (o inicial) vs rival salvaje, por turnos.
class BattlePage extends StatelessWidget {
  const BattlePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de batalla')),
      body: Consumer<BattleProvider>(
        builder: (context, b, _) {
          switch (b.phase) {
            case BattlePhase.selecting:
              return const _SelectView();
            case BattlePhase.fighting:
              return const _FightView();
            case BattlePhase.finished:
              return const _ResultView();
          }
        },
      ),
    );
  }
}

class _SelectView extends StatefulWidget {
  const _SelectView();
  @override
  State<_SelectView> createState() => _SelectViewState();
}

class _SelectViewState extends State<_SelectView> {
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final b = context.read<BattleProvider>();
    final team = context.read<TeamProvider>().team;
    if (team.isNotEmpty && b.player == null) {
      b.selectPlayer(team.first);
    }
    if (b.enemy == null && !b.loadingEnemy) {
      b.rollEnemy();
    }
  }

  Future<void> _pickStarter(int id) async {
    final api = context.read<PokeApiService>();
    final b = context.read<BattleProvider>();
    try {
      final d = await api.fetchPokemonDetail(id);
      b.selectPlayer(d);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar ese Pokémon')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();
    final team = context.watch<TeamProvider>().team;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            const Text('Tu luchador',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (team.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: team.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final p = team[i];
                    final sel = b.player?.id == p.id;
                    return ChoiceChip(
                      selected: sel,
                      showCheckmark: false,
                      avatar: Image.network(p.imageUrl, width: 48),
                      label: Text(prettyName(p.name)),
                      onSelected: (_) => b.selectPlayer(p),
                    );
                  },
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final id in [1, 4, 7])
                    FilledButton.tonal(
                      onPressed: () => _pickStarter(id),
                      child: Text(
                        b.player?.id == id
                            ? 'Elegido: ${prettyName(b.player!.name)}'
                            : 'Inicial #$id',
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            const Text('Rival salvaje',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (b.loadingEnemy)
                      const CircularProgressIndicator()
                    else if (b.enemy != null)
                      Image.network(b.enemy!.imageUrl, width: 72, height: 72)
                    else
                      const Icon(Icons.question_mark, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        b.enemy == null
                            ? 'Sin rival'
                            : '#${b.enemy!.id.toString().padLeft(3, '0')} ${prettyName(b.enemy!.name)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Otro rival',
                      onPressed: b.loadingEnemy ? null : b.rollEnemy,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: b.canStart ? b.startBattle : null,
              icon: const Icon(Icons.sports_mma),
              label: const Text('¡A pelear!'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HpBar extends StatelessWidget {
  final int hp;
  final int maxHp;
  const _HpBar({required this.hp, required this.maxHp});

  @override
  Widget build(BuildContext context) {
    final pct = maxHp <= 0 ? 0.0 : hp / maxHp;
    final color = pct > 0.5
        ? Colors.green
        : pct > 0.2
            ? Colors.orange
            : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        Text('$hp / $maxHp PS'),
      ],
    );
  }
}

class _FightView extends StatelessWidget {
  const _FightView();
  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            // Rival arriba
            Row(
              children: [
                Image.network(b.enemy!.imageUrl, width: 96, height: 96),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prettyName(b.enemy!.name),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      _HpBar(hp: b.enemyHp, maxHp: b.enemyMaxHp),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prettyName(b.player!.name),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      _HpBar(hp: b.playerHp, maxHp: b.playerMaxHp),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Image.network(b.player!.imageUrl, width: 96, height: 96),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in b.playerMoves)
                  FilledButton.tonal(
                    onPressed: b.busy ? null : () => b.playerAttack(m),
                    child: Text('${m.name} (${m.power})'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 130,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView(
                reverse: true,
                children: [
                  for (final line in b.log.reversed) Text(line),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatefulWidget {
  const _ResultView();
  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saveOnce();
  }

  Future<void> _saveOnce() async {
    if (_saved) return;
    _saved = true;
    final b = context.read<BattleProvider>();
    final won = b.winner == 'player';
    final score = won ? 100 + b.playerHp : 0;
    try {
      await context
          .read<ScoreHistoryService>()
          .saveScore(gameName: 'Batalla', score: score);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();
    final won = b.winner == 'player';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              won ? Icons.emoji_events : Icons.heart_broken,
              size: 56,
              color: won ? Colors.amber : Colors.grey,
            ),
            Text(
              won ? '¡Victoria!' : 'Derrota...',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: b.backToSelect,
                  child: const Text('Otra batalla'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: b.canStart ? b.startBattle : null,
                  child: const Text('Revancha'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
