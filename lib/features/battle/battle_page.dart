import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';
import '../../core/services/score_history_service.dart';
import '../../core/services/sound_service.dart';import '../../core/theme/type_colors.dart';
import '../../core/theme/poke_design.dart';
import '../../core/widgets/mode_illustrations.dart';
import '../../core/widgets/poke_image.dart';
import '../../core/widgets/poke_widgets.dart';
import '../wallet/coin_chip.dart';
import '../wallet/wallet_provider.dart';
import '../wallet/wallet_rules.dart';
import 'arena_background.dart';
import 'battle_terrain.dart';
import 'gba/gba_terrains.dart';
import '../team/team_provider.dart';
import '../online/online_lobby_screen.dart';
import 'battle_fx.dart';
import 'battle_mode_card.dart';
import 'battle_provider.dart';
import 'battle_tutorial.dart';
import 'gba/gba_emulator_screen.dart';
import 'battle_sound.dart';
import 'horde_fight_view.dart';
import 'vs_intro.dart';

/// MÓDULO: Simulador de batalla (Sprint 3 + vista GBA del Sprint 5 + 2.5D del Sprint 6).
/// Elige de tu equipo (o inicial) vs rival salvaje, por turnos.
class BattlePage extends StatelessWidget {
  const BattlePage({super.key});

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Consumer<BattleProvider>(
      builder: (context, b, _) {
        // GBA y 2.5D a pantalla completa en horizontal: sin AppBar.
        final fullGba = landscape &&
            b.phase == BattlePhase.fighting &&
            (b.gbaMode || b.hordeMode);
        return Scaffold(
          // La selección dibuja su propia cabecera (portada o preparación).
          appBar: fullGba || b.phase == BattlePhase.selecting
              ? null
              : AppBar(title: const Text('Simulador de batalla')),
          body: switch (b.phase) {
            BattlePhase.selecting => const _SelectView(),
            BattlePhase.fighting => b.hordeMode
                ? const HordeFightView()
                : b.gbaMode
                    ? const GbaEmulatorScreen()
                    : const _FightView(),
            BattlePhase.finished => const _ResultView(),
          },
        );
      },
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
  bool? _mode; // null = portada (elegir modo); si no, setup de ese modo.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final b = context.read<BattleProvider>();
      final team = context.read<TeamProvider>().team;
      if (team.isNotEmpty && b.playerTeam.isEmpty) {
        b.setPlayerTeam(team.take(3).toList());
      }
      if (b.enemyTeam.isEmpty && !b.loadingEnemy) {
        b.rollEnemyTeam(size: b.enemyCount);
      }
    });
  }

  Future<void> _pickStarter(int id) async {
    final api = context.read<PokeApiService>();
    final b = context.read<BattleProvider>();
    // Candado general: bloqueado no entra al equipo de batalla.
    if (!context.read<WalletProvider>().isUnlocked(id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bloqueado: desbloquéalo con monedas')),
        );
      }
      return;
    }
    try {
      final d = await api.fetchPokemonDetail(id);
      final current = List<PokemonDetail>.of(b.playerTeam);
      if (current.any((p) => p.id == d.id)) return;
      if (current.length >= 3) current.removeAt(0);
      current.add(d);
      b.setPlayerTeam(current);
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
    // Terrenos propios de cada modo: el 2.5D usa sus 18 con foto y el
    // Normal su lista GBA de 10 pintados por código.
    final isHorde = _mode == true;
    final terrains = isHorde
        ? battleTerrains.where((t) => t.forHorde).toList()
        : gbaTerrains.where((t) => t.forNormal).toList();

    if (_mode == null) return _cover(context);
    return PokeScaffold(
      centerTitle: true,
      title: const FittedBox(fit: BoxFit.scaleDown, child: PokeLogoText('Simulador de batalla', size: 38)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => setState(() => _mode = null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, size: 20, color: Color(0xFFFF8A75)),
                        const SizedBox(width: 6),
                        Text('Elegir modo', style: pokeText(18, color: const Color(0xFFFF8A75))),
                      ],
                    ),
                  ),
                ),
              ),
              Text(_mode! ? 'Modo Batalla 2.5D' : 'Modo Batalla Normal', style: pokeText(26)),
              const SizedBox(height: 10),
              PokePanel(
                color: const Color(0xFF2B57A6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tu equipo (hasta 3)', style: pokeText(21)),
                    const SizedBox(height: 8),
                    if (team.isNotEmpty)
                      LayoutBuilder(
                        builder: (context, c) {
                          final w = (c.maxWidth - 8) / 2;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final p in team.take(6))
                                SizedBox(
                                  width: w,
                                  child: _FighterPick(
                                    pokemon: p,
                                    selected: b.playerTeam.any((e) => e.id == p.id),
                                    onTap: () {
                                      final current = List<PokemonDetail>.of(b.playerTeam);
                                      if (current.any((e) => e.id == p.id)) {
                                        current.removeWhere((e) => e.id == p.id);
                                      } else {
                                        if (current.length >= 3) current.removeAt(0);
                                        current.add(p);
                                      }
                                      b.setPlayerTeam(current);
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in [1, 4, 7])
                            PokeButton(
                              height: 40,
                              fontSize: 16,
                              label: b.playerTeam.any((e) => e.id == id) ? 'Elegido #$id' : 'Inicial #$id',
                              onPressed: () => _pickStarter(id),
                            ),
                        ],
                      ),
                    if (b.playerTeam.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Elegidos: ${b.playerTeam.map((p) => prettyName(p.name)).join(', ')}',
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Dificultad del Bot', style: pokeText(22)),
              const SizedBox(height: 8),
              PokeSegmented<BotDifficulty>(
                segments: const [
                  PokeSegment(BotDifficulty.easy, 'Fácil'),
                  PokeSegment(BotDifficulty.normal, 'Normal'),
                  PokeSegment(BotDifficulty.hard, 'Difícil'),
                ],
                selected: b.difficulty,
                onChanged: b.setDifficulty,
              ),
              const SizedBox(height: 16),
              Text('Terreno de batalla', style: pokeText(22)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                ),
                itemCount: terrains.length,
                itemBuilder: (context, i) {
                  final t = terrains[i];
                  final sel = isHorde ? b.terrainId == t.id : b.gbaTerrainId == t.id;
                  return GestureDetector(
                    onTap: () => isHorde ? b.setTerrain(t.id) : b.setGbaTerrain(t.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: sel ? const Color(0xFFFFD6D0) : Colors.black, width: sel ? 4 : 3),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            // Miniatura del campo: foto del terreno; si falta,
                            // respaldo con el pintado procedural de siempre.
                            Positioned.fill(
                              child: Image.asset(
                                t.bgAsset ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => CustomPaint(painter: _TerrainThumb(t)),
                              ),
                            ),
                            if (sel)
                              const Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(Icons.check_circle, color: Colors.white, size: 26, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                              ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]),
                                ),
                                child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: pokeText(19, shadows: pokeTextShadow)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Equipo rival (Bot)', style: pokeText(22)),
              const SizedBox(height: 8),
              PokePanel(
                child: Row(
                  children: [
                    if (b.loadingEnemy)
                      const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Colors.white))
                    else if (b.enemyTeam.isNotEmpty)
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final e in b.enemyTeam) _EnemyChip(pokemon: e)],
                        ),
                      )
                    else
                      const Icon(Icons.question_mark, size: 48, color: Colors.white),
                    const SizedBox(width: 8),
                    PokeRoundButton(
                      icon: Icons.refresh,
                      size: 52,
                      tooltip: 'Otro equipo rival',
                      onPressed: b.loadingEnemy ? null : () => b.rollEnemyTeam(size: b.enemyCount),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Ajustes de Combate', style: pokeText(22)),
              const SizedBox(height: 8),
              // Formato del combate (clásico y horda): 1v1, 2v2 o 3v3.
              _CountStepper(label: 'Mis luchadores', value: b.playerCount, onChanged: b.setPlayerCount),
              const SizedBox(height: 8),
              _CountStepper(
                label: 'Rivales',
                value: b.enemyCount,
                onChanged: (v) {
                  b.setEnemyCount(v);
                  b.rollEnemyTeam(size: v);
                },
              ),
              const SizedBox(height: 16),
              PokeButton(
                expanded: true,
                height: 60,
                fontSize: 24,
                icon: Icons.sports_mma,
                label: '¡A pelear ${b.playerCount}v${b.enemyCount}!',
                onPressed: b.canStart ? () => startBattleWithTutorial(context, b) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Portada: título, moneda y las 3 tarjetas de modo (diseño "colores Pokémon").
  Widget _cover(BuildContext context) {
    return PokeScaffold(
      centerTitle: true,
      title: const FittedBox(fit: BoxFit.scaleDown, child: PokeLogoText('Simulador de batalla', size: 38)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              const Row(
                children: [
                  CoinChip(golden: true),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Gana batallas para desbloquear avatares', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Modos de batalla', style: pokeText(24)),
              const SizedBox(height: 10),
              BattleModeCard(
                title: 'Normal',
                subtitle: 'Vista GBA clásica',
                colors: const [Color(0xFF5AA2F2), Color(0xFF2F63CF)],
                pokeballTexture: true,
                illustration: const GbaIllustration(),
                onTap: () => _enter(false),
              ),
              const SizedBox(height: 14),
              BattleModeCard(
                title: '2.5D',
                subtitle: 'Arena con perspectiva',
                colors: const [Color(0xFF7ED06A), Color(0xFF3E9B49)],
                illustration: const ArenaIllustration(),
                onTap: () => _enter(true),
              ),
              const SizedBox(height: 14),
              BattleModeCard(
                title: 'Online',
                subtitle: 'Duelo en tiempo real con un amigo (sala con código)',
                colors: const [Color(0xFFFFA53A), Color(0xFFEF6C00)],
                illustration: const OnlineIllustration(),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const OnlineLobbyScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Entra al modo (false = Normal, true = 2.5D): fija la vista,
  /// relanza el rival y muestra su configuración con sus terrenos.
  void _enter(bool horde) {
    final b = context.read<BattleProvider>();
    if (b.hordeMode != horde) {
      b.setHordeMode(horde);
      b.rollEnemyTeam(size: b.enemyCount);
    }
    setState(() => _mode = horde);
  }
}

/// Selector de cantidad de luchadores (1-3): − rojo, número y + verde.
class _CountStepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _CountStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  Widget _btn(String tooltip, IconData icon, Color color, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2.5),
              boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 2))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PokePanel(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, style: pokeText(20)))),
          _btn('Menos', Icons.remove, PokeColors.red, value > 1 ? () => onChanged(value - 1) : null),
          SizedBox(width: 34, child: Text('$value', textAlign: TextAlign.center, style: pokeText(22))),
          _btn('Más', Icons.add, const Color(0xFF2E9E4A), value < 3 ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

/// Tarjeta de luchador del color de su tipo: Pokémon + nombre. El
/// seleccionado se marca con borde blanco y un ✓; se eleva al pasar el cursor.
class _FighterPick extends StatefulWidget {
  final PokemonDetail pokemon;
  final bool selected;
  final VoidCallback onTap;
  const _FighterPick({
    required this.pokemon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FighterPick> createState() => _FighterPickState();
}

class _FighterPickState extends State<_FighterPick> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final base = colorForType(widget.pokemon.types.isEmpty ? 'normal' : widget.pokemon.types.first);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color.lerp(base, Colors.white, 0.2)!, base]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.selected ? Colors.white : Colors.black, width: widget.selected ? 3.5 : 2.5),
            boxShadow: [BoxShadow(color: widget.selected ? Colors.white54 : Colors.black45, blurRadius: widget.selected ? 8 : 3, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              AnimatedScale(
                scale: _hover ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: PokeImage(id: widget.pokemon.id, width: 48, height: 48, cacheWidth: 128, placeholderColor: Colors.white54),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(prettyName(widget.pokemon.name), maxLines: 1, style: pokeText(19, shadows: pokeTextShadow)),
                ),
              ),
              if (widget.selected) const Icon(Icons.check_circle, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini tarjeta de un rival: Pokémon sobre el color de su tipo y su nombre.
class _EnemyChip extends StatelessWidget {
  final PokemonDetail pokemon;
  const _EnemyChip({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final base = colorForType(pokemon.types.isEmpty ? 'normal' : pokemon.types.first);
    return Container(
      width: 76,
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(base, Colors.white, 0.25)!, base]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 2.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PokeImage(id: pokemon.id, width: 52, height: 52, cacheWidth: 128, placeholderColor: Colors.white54),
          FittedBox(fit: BoxFit.scaleDown, child: Text(prettyName(pokemon.name), maxLines: 1, style: pokeText(14, shadows: pokeTextShadow))),
        ],
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

/// Arena de combate: fondo estadio estático, avatar con gesto de
/// lanzamiento (físico embiste / rango carga + salto), sacudida suave
/// + flash al recibir, daño flotante y pancarta de efectividad.
class _Pose {
  final Offset offset;
  final double scaleX;
  final double scaleY;
  final double rotation;
  final double charge;
  const _Pose({
    required this.offset,
    required this.scaleX,
    required this.scaleY,
    required this.rotation,
    required this.charge,
  });
}

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
  int _hapticSeq = 0;

  @override
  void initState() {
    super.initState();
    // Idle muy lento y sutil: solo respiración, sin desplazamiento.
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _attack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
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

    // Dispara la animación de ataque + vibración cuando llega un golpe nuevo.
    if (b.attackSeq != _prevSeq) {
      _prevSeq = b.attackSeq;
      _attack.forward(from: 0);
      if (b.attackSeq != _hapticSeq) {
        _hapticSeq = b.attackSeq;
        if (b.lastMiss) {
          HapticFeedback.selectionClick();
        } else if (b.lastCrit || b.lastUltimate || b.lastEffectiveness >= 2) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      }
    }

    final attackerIsPlayer = b.lastAttacker == 'player';
    final defenderIsPlayer = b.lastAttacker == 'enemy';
    final playerFainted = b.winner == 'enemy';
    final enemyFainted = b.winner == 'player';
    // En pantallas angostas (teléfonos) se compacta: menos espacios,
    // sprites y registro más chicos para que los botones no queden cortados.
    final compact = MediaQuery.widthOf(context) < 420;
    final gap = compact ? 5.0 : 8.0;
    final spriteSize = compact ? 84.0 : 104.0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: EdgeInsets.all(compact ? 10 : 16),
          children: [
            // Comentarista con voz (bocadillo animado).
            const _CommentaryBubble(),
            // ---- ARENA ----
            AnimatedBuilder(
              animation: Listenable.merge([_idle, _attack]),
              builder: (context, _) {
                final a = _attack.value; // 0..1 por golpe
                final isRanged =
                    b.lastMoveType.toLowerCase() != 'normal';
                final playerAttacking =
                    b.attackSeq > 0 && attackerIsPlayer && a < 1.0;
                final enemyAttacking = b.attackSeq > 0 &&
                    b.lastAttacker == 'enemy' &&
                    a < 1.0;
                // Sacudida suave del que recibe (sin desplazar la arena).
                final playerShake =
                    (b.attackSeq > 0 && defenderIsPlayer) ? _shake(a) : 0.0;
                final enemyShake =
                    (b.attackSeq > 0 && attackerIsPlayer) ? _shake(a) : 0.0;
                // Respiración + flotación idle: movimiento propio continuo.
                final breath =
                    1.0 + 0.015 * math.sin(_idle.value * 2 * math.pi);
                final enemyBob = math.sin(_idle.value * 2 * math.pi) * 2.2;
                final playerBob =
                    math.sin(_idle.value * 2 * math.pi + math.pi) * 2.2;
                // Poses de ataque del avatar (gesto de lanzar).
                final playerPose = _attackPose(
                  a: playerAttacking ? a : 0.0,
                  active: playerAttacking,
                  isRanged: isRanged,
                  // El jugador mira hacia arriba-izquierda.
                  dirX: -1.0,
                  dirY: -0.45,
                  breath: breath,
                );
                final enemyPose = _attackPose(
                  a: enemyAttacking ? a : 0.0,
                  active: enemyAttacking,
                  isRanged: isRanged,
                  // El rival mira hacia abajo-derecha.
                  dirX: 1.0,
                  dirY: 0.45,
                  breath: breath,
                );
                // El golpe impacta a mitad del vuelo del proyectil.
                final flash = (b.attackSeq > 0 && a > 0.45 && a < 0.9)
                    ? 1 - (a - 0.45) / 0.45
                    : 0.0;
                // Arena estática: sin screen-shake (pedido UX).

                final terrain = b.terrain;
                final wave = _idle.value * 2 * math.pi;

                return Container(
                    padding: EdgeInsets.all(compact ? 8 : 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [terrain.skyTop, terrain.skyBottom],
                      ),
                    ),
                    child: Stack(
                      children: [
                        ArenaBackground(
                          terrain: terrain,
                          borderRadius: 12,
                        ),
                        // Estadio: gradas con público (ola) + piso del terreno.
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CustomPaint(
                              painter: _StadiumPainter(
                                terrain: terrain,
                                wave: wave,
                              ),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            // Rival arriba-izquierda, PS sobre su cabeza.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _headHpCard(
                                      name: prettyName(b.enemy!.name),
                                      hp: b.enemyHp,
                                      maxHp: b.enemyMaxHp,
                                    ),
                                    const SizedBox(height: 2),
                                    // Bocadillo del rival: dice su poder al
                                    // atacar o reacciona al recibir.
                                    SizedBox(
                                      height: 36,
                                      child: Center(
                                        child: enemyAttacking && a < 0.6
                                            ? SpeechBubble(
                                                text:
                                                    '¡${b.lastMoveName}!',
                                                color: colorForType(
                                                    b.lastMoveType),
                                              )
                                            : (attackerIsPlayer &&
                                                    a > 0.5 &&
                                                    a < 0.95
                                                ? SpeechBubble(
                                                    text:
                                                        defenderReaction(
                                                      miss: b.lastMiss,
                                                      crit: b.lastCrit,
                                                      effectiveness: b
                                                          .lastEffectiveness,
                                                    ),
                                                    color: Colors.red,
                                                  )
                                                : const SizedBox
                                                    .shrink()),
                                      ),
                                    ),
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        _fighterSprite(
                                          id: b.enemy!.id,
                                          pose: enemyPose,
                                          shakeX: enemyShake,
                                          flash: attackerIsPlayer
                                              ? flash
                                              : 0.0,
                                          fainted: enemyFainted,
                                          size: spriteSize,
                                          chargeColor: colorForType(
                                              b.lastMoveType),
                                          kind: PokeSpriteKind
                                              .animatedFront,
                                          idleBob: enemyBob,
                                          isAttacker:
                                              enemyAttacking && a < 0.3,
                                        ),
                                        // Daño sobre el rival (antes salía
                                        // sobre el jugador).
                                        if (attackerIsPlayer &&
                                            b.attackSeq > 0 &&
                                            a > 0.45)
                                          Positioned(
                                            top: -6 - (a - 0.45) * 60,
                                            left: 0,
                                            right: 0,
                                            child: Opacity(
                                              opacity:
                                                  ((1.0 - a) / 0.55)
                                                      .clamp(0.0, 1.0),
                                              child: Text(
                                                '-${b.lastDamage}',
                                                textAlign:
                                                    TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  color: b.lastEffectiveness >=
                                                          2.0
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
                                const Spacer(),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    terrain.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Nombre del poder usado + pancarta de impacto.
                            SizedBox(
                              height: 52,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (b.attackSeq > 0 && a < 0.9)
                                      Text(
                                        '¡${attackerIsPlayer ? prettyName(b.player!.name) : prettyName(b.enemy!.name)} usa ${b.lastMoveName}!',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    _impactBanner(b, a),
                                  ],
                                ),
                              ),
                            ),
                            // Jugador abajo-derecha, PS sobre su cabeza.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Spacer(),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    _headHpCard(
                                      name: prettyName(b.player!.name),
                                      hp: b.playerHp,
                                      maxHp: b.playerMaxHp,
                                    ),
                                    const SizedBox(height: 2),
                                    // Bocadillo del jugador: dice su poder o
                                    // reacciona al recibir el del rival.
                                    SizedBox(
                                      height: 36,
                                      child: Center(
                                        child: playerAttacking && a < 0.6
                                            ? SpeechBubble(
                                                text:
                                                    '¡${b.lastMoveName}!',
                                                color: colorForType(
                                                    b.lastMoveType),
                                              )
                                            : (defenderIsPlayer &&
                                                    a > 0.5 &&
                                                    a < 0.95
                                                ? SpeechBubble(
                                                    text:
                                                        defenderReaction(
                                                      miss: b.lastMiss,
                                                      crit: b.lastCrit,
                                                      effectiveness: b
                                                          .lastEffectiveness,
                                                    ),
                                                    color: Colors.red,
                                                  )
                                                : const SizedBox
                                                    .shrink()),
                                      ),
                                    ),
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        _fighterSprite(
                                          id: b.player!.id,
                                          pose: playerPose,
                                          shakeX: playerShake,
                                          flash: defenderIsPlayer
                                              ? flash
                                              : 0.0,
                                          fainted: playerFainted,
                                          size: spriteSize,
                                          chargeColor:
                                              colorForType(b.lastMoveType),
                                          kind: PokeSpriteKind.animatedBack,
                                          idleBob: playerBob,
                                          isAttacker:
                                              playerAttacking && a < 0.3,
                                        ),
                                    // Número de daño flotante (solo cuando
                                    // el jugador RECIBE el golpe rival).
                                    if (defenderIsPlayer &&
                                        b.attackSeq > 0 &&
                                        a > 0.45)
                                      Positioned(
                                        top: -6 - (a - 0.45) * 60,
                                        left: 0,
                                        right: 0,
                                        child: Opacity(
                                          opacity: ((1.0 - a) / 0.55)
                                              .clamp(0.0, 1.0),
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
                        // Proyectil del poder volando atacante → defensor.
                        if (b.attackSeq > 0 && a <= 0.55)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.lerp(
                                attackerIsPlayer
                                    ? const Alignment(0.75, 0.75)
                                    : const Alignment(-0.75, -0.75),
                                attackerIsPlayer
                                    ? const Alignment(-0.75, -0.75)
                                    : const Alignment(0.75, 0.75),
                                (a / 0.55).clamp(0.0, 1.0),
                              )!,
                              child: MoveProjectile(
                                type: b.lastMoveType,
                                color:
                                    colorForType(b.lastMoveType),
                                progress:
                                    (a / 0.55).clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                        // Estallido en el impacto (lado del que recibe).
                        if (b.attackSeq > 0 && a > 0.5 && a < 0.9)
                          Positioned.fill(
                            child: Align(
                              alignment: attackerIsPlayer
                                  ? const Alignment(-0.75, -0.75)
                                  : const Alignment(0.75, 0.75),
                              child: ImpactBurst(
                                color:
                                    colorForType(b.lastMoveType),
                                t: (a - 0.5) / 0.4,
                              ),
                            ),
                          ),
                        // K.O. dramático antes del resultado.
                        if (b.winner != null) ...[
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                          const Positioned.fill(
                            child: Center(child: _KoStamp()),
                          ),
                        ],
                        // Entrada VS: overlay 1.4s con los 2 luchadores.
                        if (b.entering)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _VsAvatar(id: b.player!.id),
                                  const Text(
                                    'VS',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  _VsAvatar(id: b.enemy!.id),
                                ],
                              ),
                            ),
                          ),
                        // Destello de color (pantalla VS) justo al empezar.
                        if (b.vsFlash)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: VsFlashOverlay(index: b.vsFlashIndex, onDone: b.clearVsFlash),
                            ),
                          ),
                      ],
                    ),
                  );
              },
            ),
            SizedBox(height: compact ? 4 : 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    b.botThinking
                        ? '🤖 El Bot está pensando...'
                        : b.busy
                            ? 'Rival atacando...'
                            : '¡Tu turno! Elige un ataque',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: b.voiceEnabled
                      ? 'Silenciar narrador'
                      : 'Activar narrador',
                  iconSize: 20,
                  icon: Icon(
                    b.voiceEnabled
                        ? Icons.record_voice_over
                        : Icons.voice_over_off,
                    color: b.voiceEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  onPressed: () => b.setVoice(!b.voiceEnabled),
                ),
                IconButton(
                  tooltip: b.battleCriesEnabled
                      ? 'Silenciar gritos en batalla'
                      : 'Activar gritos en batalla',
                  iconSize: 20,
                  icon: Icon(
                    b.battleCriesEnabled
                        ? Icons.volume_up
                        : Icons.volume_off,
                    color: b.battleCriesEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  onPressed: () =>
                      b.setBattleCries(!b.battleCriesEnabled),
                ),
                IconButton(
                  tooltip: 'Vista consola GBA',
                  iconSize: 20,
                  icon: const Icon(
                    Icons.gamepad,
                    color: Colors.grey,
                  ),
                  onPressed: () => b.setGbaMode(true),
                ),
                IconButton(
                  tooltip: 'Cómo se juega',
                  iconSize: 20,
                  icon: const Icon(
                    Icons.help_outline,
                    color: Colors.grey,
                  ),
                  onPressed: () => showBattleTutorial(context),
                ),
              ],
            ),
            SizedBox(height: gap),
            // Equipos colapsables: la pantalla queda limpia para pelear.
            ExpansionTile(
              initiallyExpanded: !compact,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                '⚔️ Equipos y poderes rivales',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              children: [
                // Banca: cambiar de luchador (cuesta el turno).
                if (b.playerTeam.length > 1)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const Text('Tu banca:',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      for (var i = 0; i < b.playerTeam.length; i++)
                        ChoiceChip(
                          label: Text(
                            '${prettyName(b.playerTeam[i].name)} '
                            '(${b.playerTeamHp[i]}/${b.playerTeamMaxHp[i]})',
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: i == b.playerActive,
                          onSelected: b.playerTeamHp[i] <= 0 ||
                                  i == b.playerActive ||
                                  b.busy ||
                                  b.botThinking
                              ? null
                              : (_) => b.switchPlayerFighter(i),
                        ),
                    ],
                  ),
                SizedBox(height: gap),
                // Equipo rival restante.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    const Text('Bot:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    for (var i = 0; i < b.enemyTeam.length; i++)
                      Chip(
                        label: Text(
                          '${prettyName(b.enemyTeam[i].name)} '
                          '(${b.enemyTeamHp[i]}/${b.enemyTeamMaxHp[i]})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: i == b.enemyActive
                            ? Theme.of(context)
                                .colorScheme
                                .errorContainer
                            : null,
                      ),
                  ],
                ),
                SizedBox(height: gap),
                // Poderes del rival a la vista.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Rival:',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    for (final m in b.enemyMoves)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              colorForType(m.type).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: colorForType(m.type)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          '${m.name} ${m.power}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: gap),
              ],
            ),
            // Carga ultimate + pociones.
            _ChargeBar(
              charge: b.playerCharge,
              ready: b.playerCharge >= 100,
              potions: b.playerPotions,
              onPotion: (b.busy || b.botThinking || b.entering)
                  ? null
                  : b.usePotion,
            ),
            SizedBox(height: gap),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < b.playerMoves.length; i++)
                  Builder(builder: (context) {
                    final m = b.playerMoves[i];
                    final left = (b.playerPp.isNotEmpty &&
                            b.playerActive < b.playerPp.length &&
                            i < b.playerPp[b.playerActive].length)
                        ? b.playerPp[b.playerActive][i]
                        : m.maxPp;
                    final out = left <= 0;
                    return FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorForType(m.type)
                            .withValues(alpha: out ? 0.12 : 0.28),
                      ),
                      onPressed: (b.busy ||
                              b.botThinking ||
                              b.entering ||
                              out)
                          ? null
                          : () {
                              BattleSound.playSelect();
                              b.playerAttack(m);
                            },
                      child: Text(
                        '${m.name} (${m.power}) · $left/${m.maxPp}',
                        style: TextStyle(
                          color: out ? Colors.grey : null,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                // Ultimate: solo cuando la carga llega a 100.
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: b.playerCharge >= 100
                        ? Colors.amber
                        : Colors.grey.shade400,
                  ),
                  onPressed: (b.busy ||
                          b.botThinking ||
                          b.entering ||
                          b.playerCharge < 100)
                      ? null
                      : () => b.playerUltimate(),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    b.playerCharge >= 100
                        ? '¡Movimiento Z! (120)'
                        : 'Z ${b.playerCharge.round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            Container(
              height: compact ? 84 : 110,
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

  /// Sacudida suave del que recibe: empieza al impactar (a=0.5),
  /// amplitud pequeña para no mover brusco la escena.
  double _shake(double a) {
    if (a < 0.5) return 0.0;
    final t = (a - 0.5) / 0.5; // 0..1
    return 3.0 * (1 - t) * math.sin((a - 0.5) * 28);
  }

  /// Pose de ataque del avatar: gesto de lanzar sin desplazar la arena.
  /// - Contacto (normal: Placaje/Hiperataque): se agacha atrás y embiste
  ///   unos px hacia el rival con squash & stretch + leve inclinación.
  /// - Rango (otros tipos): se queda en su sitio, hace sentadilla y
  ///   saltito de lanzamiento + aura de carga del color del tipo.
  _Pose _attackPose({
    required double a,
    required bool active,
    required bool isRanged,
    required double dirX,
    required double dirY,
    required double breath,
  }) {
    if (!active || a <= 0.0 || a >= 1.0) {
      return _Pose(
        offset: Offset.zero,
        scaleX: breath,
        scaleY: breath,
        rotation: 0.0,
        charge: 0.0,
      );
    }
    if (!isRanged) {
      // Físico: anticipación 0-0.28, embestida 0.28-0.55, retorno.
      if (a < 0.28) {
        final t = a / 0.28;
        final ease = t * t;
        return _Pose(
          offset: Offset(dirX * -7 * ease, 3 * ease),
          scaleX: breath * (1 + 0.07 * ease),
          scaleY: breath * (1 - 0.08 * ease),
          rotation: dirX * -0.06 * ease,
          charge: 0.0,
        );
      } else if (a < 0.55) {
        final t = (a - 0.28) / 0.27;
        final out = math.sin(t * math.pi / 2); // salida rápida
        // Embestida con contacto: llega hasta el rival (44px).
        return _Pose(
          offset: Offset(
            dirX * (-7 + 44 * out),
            dirY * 18 * out,
          ),
          scaleX: breath * (1.12 - 0.03 * t),
          scaleY: breath * (0.92 + 0.03 * t),
          rotation: dirX * 0.15 * out,
          charge: 0.0,
        );
      } else {
        final t = (a - 0.55) / 0.45;
        final back = 1 - t * t;
        return _Pose(
          offset: Offset(dirX * 37 * back, dirY * 18 * back),
          scaleX: breath * (1 + 0.04 * back),
          scaleY: breath * (1 - 0.03 * back),
          rotation: dirX * 0.05 * back,
          charge: 0.0,
        );
      }
    } else {
      // Rango: carga 0-0.3, lanzamiento 0.3-0.55, reposo.
      if (a < 0.3) {
        final t = a / 0.3;
        final ease = t * t;
        return _Pose(
          offset: Offset(0, 5 * ease),
          scaleX: breath * (1 + 0.08 * ease),
          scaleY: breath * (1 - 0.09 * ease),
          rotation: 0.0,
          charge: ease,
        );
      } else if (a < 0.55) {
        final t = (a - 0.3) / 0.25;
        final hop = math.sin(t * math.pi);
        return _Pose(
          offset: Offset(dirX * 6 * t, -11 * hop),
          scaleX: breath * (1.06 + 0.04 * hop),
          scaleY: breath * (1.06 + 0.04 * hop),
          rotation: dirX * 0.10 * hop,
          charge: 1 - t * 0.6,
        );
      } else {
        final t = (a - 0.55) / 0.45;
        final back = 1 - t;
        return _Pose(
          offset: Offset(dirX * 6 * back * back, 0),
          scaleX: breath * (1 + 0.02 * back),
          scaleY: breath * (1 + 0.02 * back),
          rotation: 0.0,
          charge: 0.4 * back,
        );
      }
    }
  }

  Widget _fighterSprite({
    required int id,
    required _Pose pose,
    required double shakeX,
    required double flash,
    required bool fainted,
    required double size,
    required Color chargeColor,
    PokeSpriteKind kind = PokeSpriteKind.animatedFront,
    double idleBob = 0.0,
    bool isAttacker = false,
  }) {
    // Caída de KO animada: gira, baja y se atenúa al debilitarse.
    // idleBob: flotación continua (movimiento propio barato).
    // isAttacker: anticipación visible (crece + brilla antes de lanzar).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: fainted ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInCubic,
      builder: (context, ko, _) => Opacity(
        opacity: (fainted ? 0.3 : 1.0) * (1 - 0.55 * ko),
        child: Transform.translate(
          // Solo el avatar se mueve: arena quieta. Sacudida mínima.
          offset: Offset(
            pose.offset.dx + shakeX,
            pose.offset.dy + ko * 26 + idleBob,
          ),
          child: Transform.rotate(
            angle: pose.rotation + ko * 1.1,
            child: Transform.scale(
              scaleX: pose.scaleX *
                  (1 - 0.25 * ko) *
                  (isAttacker ? 1.08 : 1.0),
              scaleY: pose.scaleY *
                  (1 - 0.25 * ko) *
                  (isAttacker ? 1.08 : 1.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Aura de carga del poder (solo en gesto de rango).
                if ((pose.charge > 0.05 || isAttacker) && !fainted)
                  Container(
                    width: size *
                        (0.9 +
                            (pose.charge > 0.05 ? pose.charge : 0.5) *
                                0.25),
                    height: size *
                        (0.9 +
                            (pose.charge > 0.05 ? pose.charge : 0.5) *
                                0.25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chargeColor.withValues(
                          alpha: 0.28 *
                              (pose.charge > 0.05
                                  ? pose.charge
                                  : 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: chargeColor.withValues(
                              alpha: 0.55 *
                                  (pose.charge > 0.05
                                      ? pose.charge
                                      : 0.5)),
                          blurRadius: 18 *
                              (pose.charge > 0.05
                                  ? pose.charge
                                  : 0.5),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                PokeImage(
                  id: id,
                  kind: kind,
                  width: size,
                  height: size,
                ),
                if (flash > 0.05)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red
                            .withValues(alpha: 0.38 * flash),
                        borderRadius:
                            BorderRadius.circular(size / 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// Pose del avatar en cada frame de ataque.

  /// PS compactos flotando sobre la cabeza del luchador.
  Widget _headHpCard({required String name, required int hp, required int maxHp}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          _HpBar(hp: hp, maxHp: maxHp),
        ],
      ),
    );
  }

  /// Estadio con gradas, público haciendo la ola y piso del terreno.
  /// Todo dibujado por código (sin assets), ~100 puntitos baratos.
  // (Pintor en [_StadiumPainter] al final de este estado.)

  Widget _impactBanner(BattleProvider b, double a) {    if (b.attackSeq == 0 || a > 0.8) return const SizedBox.shrink();
    String? text;
    Color bg = Colors.black87;
    if (b.lastMiss) {
      text = '¡FALLÓ!';
      bg = Colors.blueGrey;
    } else if (b.lastUltimate) {
      text = '¡MOVIMIENTO Z!';
      bg = Colors.amber.shade700;
    } else if (b.lastCrit) {
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

/// Pinta el estadio: franjas de gradas con público (puntitos que
/// hacen la ola con [wave]), reflectores de noche y elipse del piso.
class _StadiumPainter extends CustomPainter {
  final BattleTerrain terrain;
  final double wave;
  const _StadiumPainter({required this.terrain, required this.wave});

  @override
  void paint(Canvas canvas, Size size) {
    final standsH = size.height * 0.52;
    // Gradas: 3 franjas.
    final standPaint = Paint()..color = terrain.stands;
    for (var i = 0; i < 3; i++) {
      final y = standsH * i / 3;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, standsH / 3 - 3),
        standPaint,
      );
    }
    // Público: puntitos alternados que suben/bajan con la ola.
    const gap = 15.0;
    var row = 0;
    for (var y = 8.0; y < standsH - 4; y += gap) {
      var col = 0;
      for (var x = 8.0; x < size.width - 4; x += gap) {
        final jump = math.sin(wave + x * 0.25 + row * 0.9) * 2.4;
        final dot = Paint()
          ..color = (row + col).isEven ? terrain.crowdA : terrain.crowdB;
        canvas.drawCircle(Offset(x, y + jump), 3.0, dot);
        col++;
      }
      row++;
    }
    // Reflectores de noche.
    if (terrain.night) {
      final glow = Paint()
        ..color = Colors.white.withValues(alpha: 0.85);
      final halo = Paint()
        ..color = Colors.white.withValues(alpha: 0.18);
      for (final fx in [size.width * 0.08, size.width * 0.92]) {
        canvas.drawCircle(Offset(fx, 10), 16, halo);
        canvas.drawCircle(Offset(fx, 10), 6, glow);
      }
    }
    // Piso: elipse + línea central del terreno.
    final floorPaint = Paint()
      ..color = terrain.floor.withValues(alpha: 0.85);
    final floorRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 26),
      width: size.width - 40,
      height: 52,
    );
    canvas.drawOval(floorRect, floorPaint);
    final linePaint = Paint()
      ..color = terrain.floorLine.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(floorRect.deflate(8), linePaint);
  }

  @override
  bool shouldRepaint(covariant _StadiumPainter old) =>
      old.wave != wave || old.terrain.id != terrain.id;
}

/// Miniatura del campo de batalla para el selector de terreno:
/// cielo, gradas con público, piso con línea y reflectores de noche.
/// Versión estática y barata del [_StadiumPainter].
class _TerrainThumb extends CustomPainter {
  final BattleTerrain terrain;
  const _TerrainThumb(this.terrain);

  @override
  void paint(Canvas canvas, Size size) {
    // Cielo.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [terrain.skyTop, terrain.skyBottom],
        ).createShader(Offset.zero & size),
    );
    // Gradas: 2 franjas superiores.
    final standsH = size.height * 0.44;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, standsH),
      Paint()..color = terrain.stands,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, standsH / 2, size.width, 1.5),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.25),
    );
    // Público: puntitos alternados deterministas.
    var row = 0;
    for (var y = 5.0; y < standsH - 2; y += 9) {
      var col = 0;
      for (var x = 5.0; x < size.width - 2; x += 9) {
        canvas.drawCircle(
          Offset(x, y),
          2.0,
          Paint()
            ..color =
                (row + col).isEven ? terrain.crowdA : terrain.crowdB,
        );
        col++;
      }
      row++;
    }
    // Reflectores de noche.
    if (terrain.night) {
      for (final fx in [size.width * 0.1, size.width * 0.9]) {
        canvas.drawCircle(
            Offset(fx, 8),
            9,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.20));
        canvas.drawCircle(
            Offset(fx, 8),
            3.5,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9));
      }
    }
    // Piso: elipse + línea.
    final floorRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 10),
      width: size.width - 16,
      height: 24,
    );
    canvas.drawOval(
        floorRect, Paint()..color = terrain.floor.withValues(alpha: 0.9));
    canvas.drawOval(
        floorRect.deflate(4),
        Paint()
          ..color = terrain.floorLine.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _TerrainThumb old) =>
      old.terrain.id != terrain.id;
}

/// Barra de carga Z + botón de poción.
class _ChargeBar extends StatelessWidget {
  final double charge;
  final bool ready;
  final int potions;
  final VoidCallback? onPotion;
  const _ChargeBar({
    required this.charge,
    required this.ready,
    required this.potions,
    required this.onPotion,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 14,
                      color: ready ? Colors.amber.shade700 : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    ready ? '¡Z LISTO!' : 'Carga Z ${charge.round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ready ? Colors.amber.shade800 : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (charge / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  color: ready ? Colors.amber : Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(
          onPressed: (potions <= 0 || onPotion == null) ? null : onPotion,
          icon: const Icon(Icons.medication, size: 16),
          label: Text('Poción x$potions', style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

/// Bocadillo del comentarista: avatar + frase animada por evento.
/// La voz (si está activa) dice la frase en español.
class _CommentaryBubble extends StatelessWidget {
  const _CommentaryBubble();

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();
    if (b.commentary.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              Icons.record_voice_over,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                alignment: Alignment.centerLeft,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Container(
                key: ValueKey(b.commentarySeq),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '🎙️ ${b.commentary}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar de la entrada VS con rebote.
class _VsAvatar extends StatelessWidget {
  final int id;
  const _VsAvatar({required this.id});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, v, _) => Transform.scale(
        scale: v.clamp(0.0, 1.0),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: PokeImage(
            id: id,
            width: 72,
            height: 72,
            cacheWidth: 192,
            placeholderColor: Colors.grey,
          ),
        ),
      ),
    );
  }
}

/// Sello de K.O. con entrada elástica sobre la arena.
class _KoStamp extends StatelessWidget {
  const _KoStamp();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, v, _) => Transform.scale(
        scale: 0.4 + 0.6 * v,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber, width: 3),
          ),
          child: const Text(
            '¡K.O.!',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
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
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti =
        ConfettiController(duration: const Duration(seconds: 3));
    _saveOnce();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _saveOnce() async {
    if (_saved) return;
    _saved = true;
    final b = context.read<BattleProvider>();
    final won = b.winner == 'player';
    // Puntaje: base 100 por ganar + PS restantes + bonus por dificultad.
    final bonus = switch (b.difficulty) {
      BotDifficulty.easy => 0,
      BotDifficulty.normal => 50,
      BotDifficulty.hard => 120,
    };
    final remaining =
        b.playerTeamHp.fold<int>(0, (a, hp) => a + hp);
    final score = won ? 100 + remaining + bonus : 0;
    final wallet = context.read<WalletProvider>();
    try {
      await context
          .read<ScoreHistoryService>()
          .saveScore(gameName: 'Batalla Vs Bot', score: score);
      // Monedero general: ganar da monedas según dificultad.
      if (won) {
        await wallet.addCoins(
          WalletRules.coinsForClassicWin(b.difficulty),
        );
      }
    } catch (_) {}
    if (!mounted) return;
    if (won) {
      _confetti.play();
      SoundService.win();
    } else {
      SoundService.lose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BattleProvider>();
    final won = b.winner == 'player';
    // Scroll + compacto en horizontal para que nunca se recorte
    // (poca altura en web/móvil apaisado).
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(landscape ? 12 : 20),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    won ? Icons.emoji_events : Icons.heart_broken,
                    size: landscape ? 40 : 56,
                    color: won ? Colors.amber : Colors.grey,
                  ),
                  Text(
                    won ? '¡Victoria!' : 'Derrota...',
                    style: TextStyle(
                        fontSize: landscape ? 20 : 26,
                        fontWeight: FontWeight.bold),
                  ),
                Text(
                  won
                      ? 'Bot ${difficultyLabel(b.difficulty)} derrotado '
                        '(${b.playerTeam.length}v${b.enemyTeam.length})'
                      : 'El Bot te ganó... ¡cambia tu equipo!',
                  textAlign: TextAlign.center,
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
            ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.yellow,
                Colors.green
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
