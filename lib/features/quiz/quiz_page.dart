import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/models/score_entry.dart';
import '../../core/services/score_history_service.dart';
import 'quiz_provider.dart';

/// MÓDULO: ¿Quién es ese Pokémon? (Sprint 3).
/// 10 rondas, 4 opciones, 15s por ronda. Guarda en el historial (F5).
class QuizPage extends StatelessWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Quién es ese Pokémon?')),
      body: Consumer<QuizProvider>(
        builder: (context, q, _) {
          if (q.loading && !q.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (q.error != null && !q.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(q.error!),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: q.load,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          switch (q.phase) {
            case QuizPhase.idle:
              return _StartView(onStart: q.startGame);
            case QuizPhase.playing:
            case QuizPhase.revealing:
              return const _GameView();
            case QuizPhase.finished:
              return _FinishView(
                score: q.score,
                correct: q.correctCount,
                onReplay: q.startGame,
              );
          }
        },
      ),
    );
  }
}

class _StartView extends StatelessWidget {
  final VoidCallback onStart;
  const _StartView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final history = context.read<ScoreHistoryService>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.quiz, size: 64),
              const SizedBox(height: 12),
              const Text(
                'Adivina la silueta',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '10 rondas · 4 opciones · 15 segundos por ronda.\n10 pts + bonus de tiempo por acierto.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<ScoreEntry>>(
                future: history.getHistory(gameName: 'Quiz'),
                builder: (context, snap) {
                  final best = (snap.data ?? []).fold<int>(
                    0,
                    (m, e) => e.score > m ? e.score : m,
                  );
                  return Text('Mejor puntaje: $best pts');
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Jugar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameView extends StatelessWidget {
  const _GameView();

  @override
  Widget build(BuildContext context) {
    final q = context.watch<QuizProvider>();
    final current = q.current!;
    final revealing = q.phase == QuizPhase.revealing;
    final progress = q.secondsLeft / QuizProvider.secondsPerRound;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Text(
                  'Ronda ${q.round}/${QuizProvider.totalRounds}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${q.score} pts',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Text('${q.secondsLeft}s restantes'),
            const SizedBox(height: 12),
            // Silueta: negra jugando, revelada al responder.
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: revealing
                    ? Image.network(current.imageUrl, height: 180)
                    : ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.black,
                          BlendMode.srcIn,
                        ),
                        child: Image.network(current.imageUrl, height: 180),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            if (revealing)
              Text(
                prettyName(current.name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.2,
              ),
              itemCount: q.options.length,
              itemBuilder: (context, i) {
                final opt = q.options[i];
                Color? bg;
                if (revealing) {
                  if (opt.id == current.id) {
                    bg = Colors.green;
                  } else if (q.picked?.id == opt.id) {
                    bg = Colors.redAccent;
                  }
                }
                return FilledButton.tonal(
                  style: bg == null
                      ? null
                      : FilledButton.styleFrom(backgroundColor: bg),
                  onPressed: revealing ? null : () => q.reveal(opt),
                  child: Text(
                    prettyName(opt.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            if (revealing)
              FilledButton(
                onPressed: q.next,
                child: Text(
                  q.round >= QuizProvider.totalRounds
                      ? 'Ver resultado'
                      : 'Siguiente',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla final: guarda UNA vez en el historial y muestra leaderboard.
class _FinishView extends StatefulWidget {
  final int score;
  final int correct;
  final VoidCallback onReplay;
  const _FinishView({
    required this.score,
    required this.correct,
    required this.onReplay,
  });

  @override
  State<_FinishView> createState() => _FinishViewState();
}

class _FinishViewState extends State<_FinishView> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saveOnce();
  }

  Future<void> _saveOnce() async {
    if (_saved) return;
    _saved = true;
    try {
      await context
          .read<ScoreHistoryService>()
          .saveScore(gameName: 'Quiz', score: widget.score);
    } catch (_) {
      // El resultado se muestra igual aunque falle el guardado.
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final history = context.read<ScoreHistoryService>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          children: [
            const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
            const SizedBox(height: 8),
            Text(
              '${widget.score} pts',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.correct}/${QuizProvider.totalRounds} aciertos',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: widget.onReplay,
                  icon: const Icon(Icons.replay),
                  label: const Text('Jugar de nuevo'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: history.clearHistory,
                  child: const Text('Borrar ranking'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Ranking local',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            FutureBuilder<List<ScoreEntry>>(
              future: history.getHistory(gameName: 'Quiz'),
              builder: (context, snap) {
                final entries = snap.data ?? [];
                if (entries.isEmpty) {
                  return const Text('Sin partidas guardadas.');
                }
                return Column(
                  children: [
                    for (var i = 0; i < entries.length.clamp(0, 5); i++)
                      ListTile(
                        dense: true,
                        leading: Text('#${i + 1}'),
                        title: Text('${entries[i].score} pts'),
                        subtitle: Text(
                          '${entries[i].date.day}/${entries[i].date.month}/${entries[i].date.year}',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
