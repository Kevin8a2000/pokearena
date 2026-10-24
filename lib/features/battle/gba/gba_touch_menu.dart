import 'package:flutter/material.dart';

import '../../../core/models/pokemon.dart';
import '../../../core/theme/type_colors.dart';
import '../battle_calculator.dart';
import '../battle_hints.dart';
import '../battle_provider.dart';

/// Menú de batalla táctil: una barra translúcida abajo, encima de la escena a
/// pantalla completa. En reposo muestra los 4 botones de acción; al tocar uno
/// se sustituye por los ataques, la mochila o el equipo. Todo se toca directo.

/// Opacidad de los botones y tarjetas: se ve el juego a través de ellos.
const double kOverlayAlpha = 0.62;

/// Ancho del bloque de 4 botones (2x2) en reposo.
const double kActionsWidth = 300;

const _red = Color(0xFFD32F2F);
const _yellow = Color(0xFFF9A825);
const _green = Color(0xFF388E3C);
const _blue = Color(0xFF1976D2);

/// Color de la insignia de efectividad.
Color effectivenessColor(EffectivenessTier t) => switch (t) {
      EffectivenessTier.strong => const Color(0xFF2E7D32),
      EffectivenessTier.normal => const Color(0xFF546E7A),
      EffectivenessTier.weak => const Color(0xFFEF6C00),
      EffectivenessTier.immune => const Color(0xFFC62828),
    };

/// Una acción principal del menú.
class GbaActionSpec {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  const GbaActionSpec(this.title, this.subtitle, this.color, this.icon);
}

const gbaActions = [
  GbaActionSpec('LUCHAR', 'Elige un ataque', _red, Icons.bolt),
  GbaActionSpec('MOCHILA', 'Usa una poción', _yellow, Icons.backpack),
  GbaActionSpec('POKÉMON', 'Cambia de Pokémon', _green, Icons.catching_pokemon),
  GbaActionSpec('HUIR', 'Escapa del combate', _blue, Icons.directions_run),
];

/// Barra inferior del menú táctil. [mode]: 0 acciones, 1 ataques, 2 mochila,
/// 3 equipo.
class GbaTouchBar extends StatelessWidget {
  final BattleProvider b;
  final int mode;
  final bool enabled;
  final ValueChanged<int> onAction;
  final ValueChanged<int> onMove;
  final VoidCallback onUltimate;
  final VoidCallback onPotion;
  final ValueChanged<int> onSwitch;
  final VoidCallback onBack;

  /// Llaves opcionales (una por botón, mismo orden que [gbaActions]) para
  /// que el tutorial de foco de luz encuentre la posición real de cada uno.
  final List<GlobalKey>? actionKeys;

  /// Llave opcional del panel de submenú (ataques/mochila/equipo): como solo
  /// hay uno montado a la vez, una sola llave sirve para los tres.
  final GlobalKey? panelKey;
  const GbaTouchBar({
    super.key,
    required this.b,
    required this.mode,
    required this.enabled,
    required this.onAction,
    required this.onMove,
    required this.onUltimate,
    required this.onPotion,
    required this.onSwitch,
    required this.onBack,
    this.actionKeys,
    this.panelKey,
  });

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      1 => _panel(_moves()),
      2 => _panel(_bag()),
      3 => _panel(_team()),
      _ => _actions(),
    };
  }

  /// Fondo de la barra cuando muestra tarjetas (translúcido, esquinas arriba).
  Widget _panel(Widget child) {
    return Container(
      key: panelKey,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border.all(color: Colors.white24),
      ),
      child: child,
    );
  }

  /// Reposo: los 4 botones en cuadrícula 2x2 a la derecha; a la izquierda
  /// queda libre el cuadro de diálogo del juego.
  Widget _actions() {
    Widget btn(int i) => Expanded(
          child: _ActionButton(key: actionKeys?[i], spec: gbaActions[i], selected: i == mode - 1, enabled: enabled, onTap: () => onAction(i)),
        );
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 6, 6),
        child: SizedBox(
          width: kActionsWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [btn(0), const SizedBox(width: 6), btn(1)]),
              const SizedBox(height: 6),
              Row(children: [btn(2), const SizedBox(width: 6), btn(3)]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onBack,
          child: const SizedBox(
            width: 54,
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back, size: 20, color: Colors.white),
                SizedBox(height: 2),
                Text('Volver', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moves() {
    final moves = b.playerMoves;
    final star = b.recommendedPlayerMove;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backButton(),
        for (var i = 0; i < moves.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: GbaMoveCard(
              move: moves[i],
              ppLeft: b.playerPpLeft(i),
              effectiveness: b.moveEffectiveness(moves[i]),
              recommended: star == i,
              enabled: enabled && b.playerPpLeft(i) > 0,
              onTap: () => onMove(i),
              translucent: true,
            ),
          ),
        ],
        if (b.playerCharge >= 100) ...[
          const SizedBox(width: 5),
          Expanded(child: _ZCard(enabled: enabled, onTap: onUltimate)),
        ],
      ],
    );
  }

  Widget _bag() {
    final left = b.playerPotions;
    final usable = enabled && left > 0;
    return Row(
      children: [
        _backButton(),
        Opacity(
          opacity: usable ? 1 : 0.45,
          child: Material(
            color: const Color(0xFF2A3140).withValues(alpha: kOverlayAlpha),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: usable ? onPotion : null,
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white38)),
                child: Row(
                  children: [
                    const Icon(Icons.medication, color: Colors.greenAccent, size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('POCIÓN x$left', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                          const Text('Cura 40 % de tus PS y cede el turno', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _team() {
    return Row(
      children: [
        _backButton(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < b.playerTeam.length; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  SizedBox(
                    width: 138,
                    child: _TeamCard(
                      name: prettyName(b.playerTeam[i].name),
                      hp: i < b.playerTeamHp.length ? b.playerTeamHp[i] : 0,
                      maxHp: i < b.playerTeamMaxHp.length ? b.playerTeamMaxHp[i] : 1,
                      active: i == b.playerActive,
                      enabled: enabled,
                      onTap: () => onSwitch(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final GbaActionSpec spec;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _ActionButton({super.key, required this.spec, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: spec.color.withValues(alpha: kOverlayAlpha),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Colors.white : Colors.white54, width: selected ? 3 : 1),
            ),
            child: Row(
              children: [
                Icon(spec.icon, color: Colors.white, size: 20),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                        ),
                      ),
                      Text(
                        spec.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 9, shadows: [Shadow(color: Colors.black54, blurRadius: 2)]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de un ataque: nombre, tipo, potencia, precisión, PP y efectividad.
class GbaMoveCard extends StatelessWidget {
  final BattleMove move;
  final int ppLeft;
  final double effectiveness;
  final bool recommended;
  final bool enabled;
  final VoidCallback onTap;

  /// Fondo semitransparente para dejar ver el juego detrás.
  final bool translucent;
  const GbaMoveCard({
    super.key,
    required this.move,
    required this.ppLeft,
    required this.effectiveness,
    required this.recommended,
    required this.enabled,
    required this.onTap,
    this.translucent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorForType(move.type);
    final tier = effectivenessTier(effectiveness);
    final noPp = ppLeft <= 0;
    final low = ppLow(ppLeft, move.maxPp);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: translucent ? const Color(0xFF2A3140).withValues(alpha: kOverlayAlpha) : const Color(0xFF2A3140),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: recommended ? Colors.amber : color.withValues(alpha: 0.7), width: recommended ? 2.5 : 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Text(move.type.isEmpty ? '?' : move.type.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        move.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (recommended) const Icon(Icons.star, size: 15, color: Colors.amber),
                  ],
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Poder ${move.power} · Prec. ${move.accuracy}%', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ppFraction(ppLeft, move.maxPp),
                          minHeight: 6,
                          backgroundColor: Colors.white12,
                          color: low ? Colors.redAccent : Colors.lightGreenAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(noPp ? 'Sin PP' : '$ppLeft/${move.maxPp}', style: TextStyle(color: low ? Colors.redAccent : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(color: effectivenessColor(tier), borderRadius: BorderRadius.circular(5)),
                  child: Text(
                    recommended ? '★ ${effectivenessLabel(effectiveness)}' : effectivenessLabel(effectiveness),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _ZCard({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: const Color(0xFF3A2F0B).withValues(alpha: kOverlayAlpha),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber, width: 2)),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                SizedBox(width: 6),
                Expanded(
                  child: Text('¡MOV. Z!\nCarga al 100 %', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final String name;
  final int hp;
  final int maxHp;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  const _TeamCard({required this.name, required this.hp, required this.maxHp, required this.active, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fainted = hp <= 0;
    final usable = enabled && !fainted && !active;
    final frac = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0).toDouble();
    final color = frac > 0.5 ? Colors.lightGreenAccent : frac > 0.2 ? Colors.amber : Colors.redAccent;
    return Opacity(
      opacity: usable ? 1 : 0.5,
      child: Material(
        color: const Color(0xFF2A3140).withValues(alpha: kOverlayAlpha),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: usable ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? Colors.amber : Colors.white24, width: active ? 2 : 1)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: Colors.white12, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  fainted ? 'Debilitado' : active ? 'En combate · $hp/$maxHp' : 'PS $hp/$maxHp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fainted ? Colors.redAccent : Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
