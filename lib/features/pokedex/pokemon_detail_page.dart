import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/evolution.dart';
import '../../core/models/pokemon.dart';
import '../../core/services/cry_service.dart';
import '../../core/services/pokeapi_service.dart';
import '../../core/theme/poke_design.dart';
import '../../core/theme/type_colors.dart';
import '../../core/widgets/poke_image.dart';
import '../../core/widgets/poke_widgets.dart';
import '../profile/favorites_provider.dart';
import '../team/team_provider.dart';
import '../wallet/coin_chip.dart';
import '../wallet/wallet_provider.dart';

const _statNamesEs = {
  'hp': 'PS',
  'attack': 'Ataque',
  'defense': 'Defensa',
  'special-attack': 'Ataque esp.',
  'special-defense': 'Defensa esp.',
  'speed': 'Velocidad',
};

/// Colores de las tarjetas de evolución según la etapa (1.ª, 2.ª, 3.ª).
const _stageColors = [Color(0xFFE6CFA8), Color(0xFFE3C45A), Color(0xFFF28B6B)];

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
    return PokeScaffold(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Volver',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 3))],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const PokeLogoText('Detalle', size: 34),
        ],
      ),
      actions: [
        const CoinChip(golden: true),
        Consumer<FavoritesProvider>(
          builder: (context, favProvider, _) {
            final isFav = favProvider.isFavorite(widget.id);
            return IconButton(
              tooltip: isFav ? 'Quitar de favoritos' : 'Agregar a favoritos',
              iconSize: 40,
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? PokeColors.red : Colors.white,
                shadows: const [Shadow(color: Colors.white, blurRadius: 0, offset: Offset(1.5, 1.5)), Shadow(color: Colors.black54, blurRadius: 4)],
              ),
              onPressed: () {
                _detail.then((d) {
                  favProvider.toggleFavorite(id: d.id, name: d.name);
                }).catchError((_) {
                  favProvider.toggleFavorite(id: widget.id, name: 'Pokémon #${widget.id}');
                });
              },
            );
          },
        ),
      ],
      body: FutureBuilder<PokemonDetail>(
        future: _detail,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar el Pokémon', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  PokeButton(label: 'Reintentar', onPressed: () => setState(_load)),
                ],
              ),
            );
          }
          final d = snap.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _AnimatedPokemonArtwork(id: d.id),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: PokeLogoText('#${d.id.toString().padLeft(3, '0')} ${prettyName(d.name)}', size: 38),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [for (final t in d.types) _TypeBadge(type: t)],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Altura: ${d.height / 10} m   •   Peso: ${d.weight / 10} kg',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, shadows: pokeTextShadow),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Gestión del equipo: el candado solo bloquea agregar.
                  // Ver arte, grito, tipos y stats siempre está permitido.
                  Consumer<WalletProvider>(
                    builder: (context, wallet, _) {
                      if (!wallet.isUnlocked(d.id)) {
                        final price = wallet.priceOf(d.id);
                        return PokePanel(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock, size: 28, color: PokeColors.goldLight),
                              const SizedBox(height: 4),
                              const Text(
                                'Avatar bloqueado: puedes verlo y escucharlo, pero no agregarlo al equipo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 10),
                              PokeButton(
                                icon: Icons.lock_open,
                                label: 'Desbloquear ($price 🪙 · tienes ${wallet.coins})',
                                onPressed: () async {
                                  final ok = await wallet.unlock(d.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(ok ? '¡${prettyName(d.name)} desbloqueado!' : 'Te faltan monedas ($price 🪙)')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }
                      return _TeamManageButton(detail: d);
                    },
                  ),
                  const SizedBox(height: 18),
                  PokePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estadísticas base', style: pokeText(20)),
                        const SizedBox(height: 6),
                        for (final e in d.stats.entries) _StatBar(name: _statNamesEs[e.key] ?? e.key, value: e.value),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Evolución', style: pokeText(26, shadows: pokeTextShadow)),
                  const SizedBox(height: 8),
                  _EvolutionSection(future: _evolution, currentId: d.id, onRetry: () => setState(_load)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Píldora de tipo grande (color del tipo, borde oscuro).
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: colorForType(type),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 3))],
      ),
      child: Text(typeNameEs(type), textAlign: TextAlign.center, style: pokeText(18, shadows: pokeTextShadow)),
    );
  }
}

/// Botón de gestión del equipo (Requisito E2), solo para avatares
/// desbloqueados. El candado se evalúa antes de mostrarlo.
class _TeamManageButton extends StatelessWidget {
  final PokemonDetail detail;
  const _TeamManageButton({required this.detail});

  @override
  Widget build(BuildContext context) {
    final d = detail;
    return Consumer<TeamProvider>(
      builder: (context, teamProvider, _) {
        final inTeam = teamProvider.isInTeam(d.id);
        if (inTeam) {
          return Center(
            child: PokeButton(
              icon: Icons.remove_circle_outline,
              label: 'Quitar del equipo',
              color: const Color(0xFF5A6A99),
              darkColor: const Color(0xFF2A3560),
              onPressed: () => teamProvider.removePokemon(d.id),
            ),
          );
        }
        return Center(
          child: PokeButton(
            icon: Icons.group_add_outlined,
            label: teamProvider.isFull ? 'Equipo completo (6/6)' : 'Agregar al equipo (${teamProvider.count}/6)',
            onPressed: () async {
              if (teamProvider.isFull) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El equipo ya tiene 6 Pokémon (máximo alcanzado)')),
                );
                return;
              }
              final added = await teamProvider.addPokemon(d);
              if (context.mounted && added) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${prettyName(d.name)} agregado al equipo (${teamProvider.count}/6)'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${prettyName(d.name)} ya está en tu equipo'), duration: const Duration(seconds: 2)),
                );
              }
            },
          ),
        );
      },
    );
  }
}

/// Barra de estadística: pista crema, relleno rojo y Pokébola al final.
class _StatBar extends StatelessWidget {
  final String name;
  final int value;
  const _StatBar({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    final frac = (value / 160).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 104, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(name, style: pokeText(16)))),
          SizedBox(width: 40, child: Text('$value', style: pokeText(16))),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                const ball = 24.0;
                final fill = (c.maxWidth - ball) * frac + ball / 2;
                return SizedBox(
                  height: ball,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(color: const Color(0xFFF3E39A), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                      ),
                      Container(
                        width: fill,
                        height: 12,
                        decoration: BoxDecoration(color: PokeColors.red, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black, width: 1.5)),
                      ),
                      Positioned(left: fill - ball / 2, child: const PokeBallIcon(size: ball)),
                    ],
                  ),
                );
              },
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

  const _EvolutionSection({required this.future, required this.currentId, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EvolutionNode>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white)));
        }
        if (snap.hasError || !snap.hasData) {
          return Column(
            children: [
              const Text('No se pudo cargar la evolución', style: TextStyle(color: Colors.white)),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          );
        }
        final root = snap.data!;
        if (root.children.isEmpty) {
          return const Center(child: Text('Este Pokémon no evoluciona', style: TextStyle(color: Colors.white)));
        }
        return Center(child: _EvolutionTree(node: root, currentId: currentId, stage: 0));
      },
    );
  }
}

/// Dibuja el árbol de evolución de forma recursiva: cada nodo muestra su
/// tarjeta y, debajo, sus evoluciones (varias si la cadena se ramifica).
class _EvolutionTree extends StatelessWidget {
  final EvolutionNode node;
  final int currentId;
  final int stage;
  const _EvolutionTree({required this.node, required this.currentId, required this.stage});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EvolutionCard(node: node, isCurrent: node.id == currentId, stage: stage),
        if (node.children.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Icon(Icons.arrow_downward, size: 38, color: PokeColors.goldLight, shadows: [Shadow(color: Colors.black87, offset: Offset(2, 2))]),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in node.children) _EvolutionTree(node: c, currentId: currentId, stage: stage + 1),
            ],
          ),
        ],
      ],
    );
  }
}

/// Arte oficial sobre una Pokébola con halo; microanimación de escala al
/// pasar el cursor (hover) y toque para escuchar el grito del Pokémon.
class _AnimatedPokemonArtwork extends StatefulWidget {
  final int id;
  const _AnimatedPokemonArtwork({required this.id});

  @override
  State<_AnimatedPokemonArtwork> createState() => _AnimatedPokemonArtworkState();
}

class _AnimatedPokemonArtworkState extends State<_AnimatedPokemonArtwork> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Center(
        child: SizedBox(
          height: 270,
          width: 270,
          child: Semantics(
            button: true,
            label: 'Escuchar grito',
            child: GestureDetector(
              onTap: () => CryService.playCry(widget.id, volume: 0.7),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Halo y Pokébola grande, tenue, detrás del Pokémon.
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x88FFFFFF), blurRadius: 40, spreadRadius: 2)],
                    ),
                    child: const Opacity(opacity: 0.8, child: PokeBallIcon(size: 260)),
                  ),
                  AnimatedScale(
                    scale: _isHovered ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: PokeImage(id: widget.id, height: 230, fit: BoxFit.contain),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 18,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PokeColors.goldLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 2))],
                      ),
                      child: const Icon(Icons.volume_up, color: Colors.black, size: 20),
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
}

class _EvolutionCard extends StatefulWidget {
  final EvolutionNode node;
  final bool isCurrent;
  final int stage;
  const _EvolutionCard({required this.node, required this.isCurrent, required this.stage});

  @override
  State<_EvolutionCard> createState() => _EvolutionCardState();
}

class _EvolutionCardState extends State<_EvolutionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isInteractive = !widget.isCurrent;
    final color = _stageColors[widget.stage.clamp(0, _stageColors.length - 1)];

    return MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isInteractive) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isInteractive) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: _isHovered ? Matrix4.translationValues(0.0, -4.0, 0.0) : Matrix4.identity(),
        width: 170,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: widget.isCurrent ? PokeColors.goldLight : Colors.black, width: widget.isCurrent ? 4 : 3),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 4))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          // Tocar la etapa actual no hace nada; las demás abren su propio detalle.
          onTap: widget.isCurrent
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PokemonDetailPage(id: widget.node.id))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(opacity: 0.35, child: PokeBallIcon(size: 96)),
                      AnimatedScale(
                        scale: _isHovered ? 1.12 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: PokeImage(id: widget.node.id, height: 96, fit: BoxFit.contain, cacheWidth: 192),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(fit: BoxFit.scaleDown, child: Text(prettyName(widget.node.name), style: pokeText(22, color: PokeColors.ink))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
