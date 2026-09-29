import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';
import '../../core/services/score_history_service.dart';
import '../../core/theme/type_colors.dart';
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
    // Diferir al post-frame: pedir el rival notifica listeners y no puede
    // hacerse durante el build (rompía la app al abrir Batalla).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final b = context.read<BattleProvider>();
      final team = context.read<TeamProvider>().team;
      if (team.isNotEmpty && b.player == null) {
        b.selectPlayer(team.first);
      }
      if (b.enemy == null && !b.loadingEnemy) {
        b.rollEnemy();
      }
    });
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

/// Barra de PS con drenaje animado (se vacía suave en vez de saltar).
class _HpBar extends StatefulWidget {
  final int hp;
  final int maxHp;
  const _HpBar({required this.hp, required this.maxHp});

  @override
  State<_HpBar> createState() => _HpBarState();
}

class _HpBarState extends State<_HpBar> {
  double _shown = 1.0;

  double get _target =>
      widget.maxHp <= 0 ? 0.0 : widget.hp / widget.maxHp;

  @override
  void initState() {
    super.initState();
    _shown = _target;
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final color = target > 0.5
        ? Colors.green
        : target > 0.2
            ? Colors.orange
            : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: _shown, end: target),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          onEnd: () => _shown = target,
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: color,
              ),
            );
          },
        ),
        Text('${widget.hp} / ${widget.maxHp} PS'),
      ],
    );
  }
}

/// Arena de combate animada: fondo estadio, flotación idle, embestida al
/// atacar, sacudida + flash rojo al recibir, número de daño flotante,
/// pancarta de súper-efectivo/crítico y screen-shake.
class _FightView extends StatefulWidget {
  const _FightView();
  @override
  State<_FightView> createState() => _FightViewState();
}

class _FightViewState extends State<_FightView>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _attack;
  int _prevSeq = 0;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _attack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _idle.dispose();
    _attack.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();

    // Dispara la animación de ataque cuando llega un golpe nuevo.
    if (b.attackSeq != _prevSeq) {
      _prevSeq = b.attackSeq;
      _attack.forward(from: 0);
    }

    final attackerIsPlayer = b.lastAttacker == 'player';
    final defenderIsPlayer = b.lastAttacker == 'enemy';
    final playerFainted = b.winner == 'enemy';
    final enemyFainted = b.winner == 'player';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            // ---- ARENA ----
            AnimatedBuilder(
              animation: Listenable.merge([_idle, _attack]),
              builder: (context, _) {
                final bob = _idle.value * 2 * 3.14159;
                final a = _attack.value; // 0..1 por golpe
                // Embestida: el atacante se lanza hacia el rival.
                final playerLunge =
                    (b.attackSeq > 0 && attackerIsPlayer) ? _lunge(a) : 0.0;
                final enemyLunge =
                    (b.attackSeq > 0 && !attackerIsPlayer) ? _lunge(a) : 0.0;
                // Sacudida del que recibe + flash.
                final playerShake =
                    (b.attackSeq > 0 && defenderIsPlayer) ? _shake(a) : 0.0;
                final enemyShake =
                    (b.attackSeq > 0 && attackerIsPlayer) ? _shake(a) : 0.0;
                final flash = (b.attackSeq > 0 && a < 0.55)
                    ? (0.55 - a) / 0.55
                    : 0.0;
                // Screen-shake en súper-efectivo.
                final bigHit =
                    b.attackSeq > 0 && b.lastEffectiveness >= 2.0 && a < 0.5;
                final shakeX =
                    bigHit ? 5 * (0.5 - a) * _sin(a * 3.14159 * 6) : 0.0;

                return Transform.translate(
                  offset: Offset(shakeX, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.lightBlue.shade200,
                          Colors.lightBlue.shade50,
                          Colors.green.shade200,
                        ],
                        stops: const [0.0, 0.62, 1.0],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Elipse del suelo.
                        Positioned(
                          bottom: 6,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.green.shade400
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(23),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            // Rival arriba-izquierda.
                            Row(
                              children: [
                                _fighterSprite(
                                  url: b.enemy!.imageUrl,
                                  baseBob: -6 * _sin(bob),
                                  lungeX: enemyLunge * 34,
                                  shakeX: enemyShake,
                                  flash: attackerIsPlayer ? flash : 0.0,
                                  fainted: enemyFainted,
                                  size: 104,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _nameCard(
                                    context,
                                    prettyName(b.enemy!.name),
                                    b.enemyHp,
                                    b.enemyMaxHp,
                                  ),
                                ),
                              ],
                            ),
                            // Pancarta de impacto.
                            SizedBox(
                              height: 34,
                              child: Center(
                                child: _impactBanner(b, a),
                              ),
                            ),
                            // Jugador abajo-derecha.
                            Row(
                              children: [
                                Expanded(
                                  child: _nameCard(
                                    context,
                                    prettyName(b.player!.name),
                                    b.playerHp,
                                    b.playerMaxHp,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _fighterSprite(
                                      url: b.player!.imageUrl,
                                      baseBob: 6 * _sin(bob),
                                      lungeX: -playerLunge * 34,
                                      shakeX: playerShake,
                                      flash: defenderIsPlayer ? flash : 0.0,
                                      fainted: playerFainted,
                                      size: 104,
                                    ),
                                    // Número de daño flotante sobre el que recibe.
                                    if (b.attackSeq > 0 && a < 0.85)
                                      Positioned(
                                        top: -6 - a * 34,
                                        left: 0,
                                        right: 0,
                                        child: Opacity(
                                          opacity: (0.85 - a) / 0.85,
                                          child: Text(
                                            '-${b.lastDamage}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: b.lastEffectiveness >= 2.0
                                                  ? Colors.deepOrange
                                                  : Colors.red.shade700,
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.white,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              b.busy ? 'Rival atacando...' : '¡Tu turno! Elige un ataque',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in b.playerMoves)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorForType(m.type)
                          .withValues(alpha: 0.28),
                    ),
                    onPressed: b.busy ? null : () => b.playerAttack(m),
                    child: Text('${m.name} (${m.power})'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 110,
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

  double _sin(double x) => (x - (x * x * x) / 6);

  /// Curva de embestida: sale rápido y vuelve (0..1..0).
  double _lunge(double a) => a < 0.4 ? a / 0.4 : 1 - (a - 0.4) / 0.6;

  /// Sacudida del golpeado: oscila mientras vuelve la embestida.
  double _shake(double a) =>
      a < 0.35 ? 0.0 : 7 * (1 - (a - 0.35) / 0.65) * _sin(a * 28);

  Widget _fighterSprite({
    required String url,
    required double baseBob,
    required double lungeX,
    required double shakeX,
    required double flash,
    required bool fainted,
    required double size,
  }) {
    return Opacity(
      opacity: fainted ? 0.3 : 1.0,
      child: Transform.translate(
        offset: Offset(lungeX + shakeX, baseBob + (fainted ? 18 : 0)),
        child: Stack(
          children: [
            Image.network(url, width: size, height: size),
            if (flash > 0.05)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.45 * flash),
                    borderRadius: BorderRadius.circular(size / 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nameCard(
      BuildContext context, String name, int hp, int maxHp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          _HpBar(hp: hp, maxHp: maxHp),
        ],
      ),
    );
  }

  Widget _impactBanner(BattleProvider b, double a) {
    if (b.attackSeq == 0 || a > 0.8) return const SizedBox.shrink();
    String? text;
    Color bg = Colors.black87;
    if (b.lastCrit) {
      text = '¡GOLPE CRÍTICO!';
      bg = Colors.deepPurple;
    } else if (b.lastEffectiveness == 0.0) {
      text = 'NO AFECTA...';
      bg = Colors.blueGrey;
    } else if (b.lastEffectiveness >= 2.0) {
      text = '¡SÚPER EFECTIVO!';
      bg = Colors.deepOrange;
    } else if (b.lastEffectiveness < 1.0) {
      text = 'No es muy efectivo...';
      bg = Colors.brown;
    }
    if (text == null) return const SizedBox.shrink();
    final scale = a < 0.25 ? 0.6 + (a / 0.25) * 0.4 : 1.0;
    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
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
