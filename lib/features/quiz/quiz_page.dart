import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/models/score_entry.dart';
import '../../core/services/score_history_service.dart';
import '../../core/theme/poke_design.dart';
import '../../core/widgets/poke_image.dart';
import '../../core/widgets/poke_widgets.dart';
import '../../core/widgets/sunburst_background.dart';
import 'quiz_provider.dart';

/// MÓDULO: ¿Quién es ese Pokémon? (Sprint 3).
/// 10 rondas, 4 opciones, 15s por ronda. Guarda en el historial (F5).
///
/// Diseño "colores Pokémon": rayos rojo/amarillo, silueta negra con un "?"
/// blanco, titulares blancos con contorno negro y botones rojos 3D.
class QuizPage extends StatelessWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC400),
      body: Stack(
        children: [
          const Positioned.fill(child: SunburstBackground()),
          SafeArea(
            bottom: false,
            child: Consumer<QuizProvider>(
              builder: (context, q, _) {
                if (q.loading && !q.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (q.error != null && !q.hasData) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PokeOutlinedText(q.error!, size: 22),
                        const SizedBox(height: 12),
                        PokeButton(label: 'Reintentar', onPressed: q.load),
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
                    return _FinishView(score: q.score, correct: q.correctCount, onReplay: q.startGame);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Inicio: silueta con "?", "Adivina la silueta" y el botón "¡Jugar!".
class _StartView extends StatefulWidget {
  final VoidCallback onStart;
  const _StartView({required this.onStart});

  @override
  State<_StartView> createState() => _StartViewState();
}

class _StartViewState extends State<_StartView> {
  /// Pokémon de la silueta de la portada (uno distinto cada vez que se abre).
  late final int _id = math.Random().nextInt(151) + 1;

  @override
  Widget build(BuildContext context) {
    final history = context.read<ScoreHistoryService>();
    // Scroll para que no se desborde en horizontal (poca altura).
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ColorFiltered(
                        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                        child: PokeImage(id: _id, height: 300, cacheWidth: 600, filterQuality: FilterQuality.high, placeholderColor: Colors.black54),
                      ),
                      const PokeOutlinedText('?', size: 150, stroke: Colors.black),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const PokeOutlinedText('Adivina\nla silueta', size: 58),
                const SizedBox(height: 10),
                const Text(
                  '10 rondas · 4 opciones · 15 segundos por ronda.\n10 pts + bonus de tiempo por acierto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, shadows: pokeTextShadow),
                ),
                const SizedBox(height: 6),
                FutureBuilder<List<ScoreEntry>>(
                  future: history.getHistory(gameName: 'Quiz'),
                  builder: (context, snap) {
                    final best = (snap.data ?? []).fold<int>(0, (m, e) => e.score > m ? e.score : m);
                    return Text('Mejor puntaje: $best pts', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, shadows: pokeTextShadow));
                  },
                ),
                const SizedBox(height: 16),
                PokeButton(label: '¡Jugar!', onPressed: widget.onStart, height: 78, fontSize: 38, expanded: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de respuesta: crema; verde al acertar y rojo si fue la elegida y falló.
class _OptionButton extends StatelessWidget {
  final String label;
  final Color? bg;
  final VoidCallback? onTap;
  const _OptionButton({required this.label, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colored = bg != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: bg ?? PokeColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 3))],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, style: pokeText(19, color: colored ? Colors.white : PokeColors.ink, shadows: colored ? pokeTextShadow : null)),
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
                PokeOutlinedText('Ronda ${q.round}/${QuizProvider.totalRounds}', size: 24),
                const Spacer(),
                PokeOutlinedText('${q.score} pts', size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black, width: 2.5), color: Colors.white54),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(value: progress, minHeight: 10, color: PokeColors.red, backgroundColor: Colors.transparent),
              ),
            ),
            const SizedBox(height: 4),
            Text('${q.secondsLeft}s restantes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: pokeTextShadow)),
            const SizedBox(height: 12),
            // Silueta: negra jugando, revelada al responder.
            Container(
              height: 230,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Center(
                child: revealing
                    ? PokeImage(id: current.id, height: 190, cacheWidth: 500, filterQuality: FilterQuality.high, placeholderColor: Colors.grey)
                    : ColorFiltered(
                        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                        child: PokeImage(id: current.id, height: 190, cacheWidth: 500, filterQuality: FilterQuality.high, placeholderColor: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            if (revealing) Center(child: PokeOutlinedText(prettyName(current.name), size: 30)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.9),
              itemCount: q.options.length,
              itemBuilder: (context, i) {
                final opt = q.options[i];
                Color? bg;
                if (revealing) {
                  if (opt.id == current.id) {
                    bg = const Color(0xFF2E9E4A);
                  } else if (q.picked?.id == opt.id) {
                    bg = PokeColors.red;
                  }
                }
                return _OptionButton(label: prettyName(opt.name), bg: bg, onTap: revealing ? null : () => q.reveal(opt));
              },
            ),
            const SizedBox(height: 14),
            if (revealing)
              Center(child: PokeButton(label: q.round >= QuizProvider.totalRounds ? 'Ver resultado' : 'Siguiente', onPressed: q.next, height: 56, fontSize: 24)),
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
  const _FinishView({required this.score, required this.correct, required this.onReplay});

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
      await context.read<ScoreHistoryService>().saveScore(gameName: 'Quiz', score: widget.score);
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
            const Icon(Icons.emoji_events, size: 84, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 0, offset: Offset(3, 3))]),
            Center(child: PokeOutlinedText('${widget.score} pts', size: 58)),
            Center(
              child: Text(
                '${widget.correct}/${QuizProvider.totalRounds} aciertos',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, shadows: pokeTextShadow),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PokeButton(label: 'Jugar de nuevo', onPressed: widget.onReplay, icon: Icons.replay, height: 56, fontSize: 22),
                TextButton(
                  onPressed: history.clearHistory,
                  child: const Text('Borrar ranking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: pokeTextShadow)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PokePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ranking local', style: pokeText(22, color: PokeColors.goldLight)),
                  FutureBuilder<List<ScoreEntry>>(
                    future: history.getHistory(gameName: 'Quiz'),
                    builder: (context, snap) {
                      final entries = snap.data ?? [];
                      if (entries.isEmpty) {
                        return const Padding(padding: EdgeInsets.only(top: 6), child: Text('Sin partidas guardadas.', style: TextStyle(color: Colors.white70)));
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < entries.length.clamp(0, 5); i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  SizedBox(width: 40, child: Text('#${i + 1}', style: pokeText(20, color: PokeColors.goldLight))),
                                  Expanded(child: Text('${entries[i].score} pts', style: pokeText(20))),
                                  Text('${entries[i].date.day}/${entries[i].date.month}/${entries[i].date.year}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
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
