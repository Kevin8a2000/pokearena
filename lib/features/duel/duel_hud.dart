import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/pokemon.dart';
import '../../core/widgets/poke_image.dart';
import '../battle/gba/gba_touch_menu.dart' show kOverlayAlpha;
import 'duel_engine.dart';

/// Piezas de la interfaz del Duelo: placas con barras, reloj, D-pad virtual,
/// botones de acción translúcidos y efectos de texto.

const kDuelRed = Color(0xFFE53935);
const kDuelGreen = Color(0xFF43A047);
const kDuelBlue = Color(0xFF1E88E5);
const kDuelPurple = Color(0xFF8E24AA);
const kDuelOrange = Color(0xFFFB8C00);
const kDuelCyan = Color(0xFF29B6F6);

/// Retrato + nombre + barras de vida, stamina y ULTRA/FRENESÍ + coronas.
class DuelPlate extends StatelessWidget {
  final PokemonDetail pokemon;
  final DuelFighter fighter;

  /// true = placa de la derecha (retrato a la derecha, barras alineadas a la derecha).
  final bool right;

  /// Etiqueta de la tercera barra: ULTRA (jugador) o FRENESÍ (rival).
  final String ultraLabel;
  final Color ultraColor;

  /// Rondas ganadas y totales para dibujar las coronas.
  final int crowns;
  final int crownSlots;
  const DuelPlate({
    super.key,
    required this.pokemon,
    required this.fighter,
    required this.right,
    this.ultraLabel = 'ULTRA',
    this.ultraColor = kDuelOrange,
    this.crowns = 0,
    this.crownSlots = DuelTuning.roundsToWin,
  });

  @override
  Widget build(BuildContext context) {
    final hp = fighter.hpFraction;
    final hpColor = hp > 0.5 ? const Color(0xFF66BB6A) : hp > 0.2 ? Colors.amber : Colors.redAccent;
    final portrait = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white70, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: PokeImage(id: pokemon.id, kind: PokeSpriteKind.artwork, width: 42, height: 42, cacheWidth: 160, filterQuality: FilterQuality.high),
      ),
    );
    final crownRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < crownSlots; i++)
          Icon(Icons.workspace_premium, size: 14, color: i < crowns ? Colors.amber : Colors.white30),
      ],
    );
    final bars = Expanded(
      child: Column(
        crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            textDirection: right ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Flexible(
                child: Text(
                  prettyName(pokemon.name).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 3)]),
                ),
              ),
              const SizedBox(width: 6),
              crownRow,
            ],
          ),
          const SizedBox(height: 2),
          _Bar(fraction: hp, color: hpColor, height: 10, reverse: right),
          const SizedBox(height: 2),
          _LabeledBar(label: 'STAMINA', fraction: fighter.staminaFraction, color: kDuelCyan, reverse: right),
          const SizedBox(height: 2),
          _LabeledBar(label: ultraLabel, fraction: fighter.ultraFraction, color: fighter.ultraReady ? Colors.yellowAccent : ultraColor, reverse: right),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: right ? [bars, const SizedBox(width: 6), portrait] : [portrait, const SizedBox(width: 6), bars],
    );
  }
}

class _LabeledBar extends StatelessWidget {
  final String label;
  final double fraction;
  final Color color;
  final bool reverse;
  const _LabeledBar({required this.label, required this.fraction, required this.color, required this.reverse});

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 2)]));
    return Row(
      textDirection: reverse ? TextDirection.rtl : TextDirection.ltr,
      children: [
        SizedBox(width: 34, child: Align(alignment: reverse ? Alignment.centerRight : Alignment.centerLeft, child: text)),
        Expanded(child: _Bar(fraction: fraction, color: color, height: 6, reverse: reverse)),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;
  final bool reverse;
  const _Bar({required this.fraction, required this.color, required this.height, required this.reverse});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.white54, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Align(
          alignment: reverse ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
            child: Container(color: color),
          ),
        ),
      ),
    );
  }
}

/// Reloj redondo del centro con los segundos que quedan y el terreno debajo.
class DuelTimer extends StatelessWidget {
  final double seconds;
  final String terrain;
  const DuelTimer({super.key, required this.seconds, this.terrain = ''});

  @override
  Widget build(BuildContext context) {
    final s = seconds.ceil().clamp(0, 999);
    final low = s <= 10;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.55),
            border: Border.all(color: low ? Colors.redAccent : Colors.amber, width: 2.5),
          ),
          child: Text(
            '$s',
            style: TextStyle(color: low ? Colors.redAccent : Colors.amber, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        if (terrain.isNotEmpty)
          Text(
            terrain.toUpperCase(),
            maxLines: 1,
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.6, shadows: [Shadow(color: Colors.black, blurRadius: 3)]),
          ),
      ],
    );
  }
}

/// Analógico virtual translúcido para moverse: arrastrar a izquierda/derecha
/// mueve con velocidad proporcional al desplazamiento. Usa punteros propios,
/// así funciona a la vez que los botones (multitáctil).
class DuelJoystick extends StatefulWidget {
  final ValueChanged<double> onMove;
  final double size;
  const DuelJoystick({super.key, required this.onMove, this.size = 124});

  @override
  State<DuelJoystick> createState() => _DuelJoystickState();
}

class _DuelJoystickState extends State<DuelJoystick> {
  int? _pointer;
  Offset _knob = Offset.zero; // en [-1, 1]

  double get _radius => widget.size / 2 - 22;

  void _update(Offset local) {
    final c = Offset(widget.size / 2, widget.size / 2);
    var d = (local - c) / _radius;
    if (d.distance > 1) d = d / d.distance;
    setState(() => _knob = d);
    // Zona muerta pequeña y respuesta proporcional.
    final dx = d.dx.abs() < 0.15 ? 0.0 : d.dx;
    widget.onMove(dx);
  }

  void _release() {
    _pointer = null;
    setState(() => _knob = Offset.zero);
    widget.onMove(0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        _update(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) _update(e.localPosition);
      },
      onPointerUp: (e) {
        if (e.pointer == _pointer) _release();
      },
      onPointerCancel: (e) {
        if (e.pointer == _pointer) _release();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _StickPainter(_knob, _radius)),
      ),
    );
  }
}

class _StickPainter extends CustomPainter {
  final Offset knob;
  final double radius;
  const _StickPainter(this.knob, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ring = Paint()
      ..color = const Color(0xFF81D4FA).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(c, size.width / 2 - 3, Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: 0.22));
    canvas.drawCircle(c, size.width / 2 - 3, ring);
    final arrow = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (final a in [0.0, math.pi]) {
      final p = c + Offset(math.cos(a), math.sin(a)) * (size.width / 2 - 14);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.drawPath(
        Path()
          ..moveTo(0, -5)
          ..lineTo(5, 4)
          ..lineTo(-5, 4)
          ..close(),
        arrow,
      );
      canvas.restore();
    }
    final k = c + knob * radius;
    canvas.drawCircle(k, 21, Paint()..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawCircle(k, 21, ring);
  }

  @override
  bool shouldRepaint(_StickPainter old) => old.knob != knob;
}

/// Botón de acción redondo translúcido con icono, etiqueta y anillo de
/// enfriamiento. Responde al instante al tocar (puntero abajo) y admite varios
/// dedos a la vez; con [onRelease] sirve para botones que se mantienen.
class DuelActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double size;

  /// 0 = listo, 1 = recién usado (enfriamiento completo).
  final double cooldown;
  final bool enabled;

  /// Brillo de "lista" (p. ej. ¡ULTRA! cargada).
  final bool glow;
  final Widget? child;
  final VoidCallback onPress;
  final VoidCallback? onRelease;
  const DuelActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPress,
    this.onRelease,
    this.size = 54,
    this.cooldown = 0,
    this.enabled = true,
    this.glow = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dim = !enabled || cooldown > 0;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPress(),
      onPointerUp: (_) => onRelease?.call(),
      onPointerCancel: (_) => onRelease?.call(),
      child: SizedBox(
        width: size + 22,
        height: size + 22,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: dim ? 0.55 : 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: kOverlayAlpha),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
                      boxShadow: glow ? [BoxShadow(color: Colors.orangeAccent.withValues(alpha: 0.9), blurRadius: 14, spreadRadius: 3)] : null,
                    ),
                    child: child ?? Icon(icon, color: Colors.white, size: size * 0.5),
                  ),
                  if (cooldown > 0)
                    SizedBox(
                      width: size,
                      height: size,
                      child: CircularProgressIndicator(
                        value: cooldown.clamp(0.0, 1.0).toDouble(),
                        strokeWidth: 4,
                        color: Colors.white,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
              style: const TextStyle(color: Colors.white, fontSize: 8.5, height: 1.0, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 3)]),
            ),
          ],
        ),
      ),
    );
  }
}

/// "¡COMBO xN!" grande tipo cómic (amarillo y rojo) con destellos.
class ComboBubble extends StatelessWidget {
  final int combo;
  const ComboBubble({super.key, required this.combo});

  @override
  Widget build(BuildContext context) {
    final big = math.min(34.0, 20.0 + combo * 3);
    Widget text(Color c, {Paint? stroke}) => Text(
          '¡COMBO X$combo!',
          style: TextStyle(
            fontSize: big,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
            color: stroke == null ? c : null,
            foreground: stroke,
          ),
        );
    return Transform.rotate(
      angle: -0.07,
      child: Stack(
        alignment: Alignment.center,
        children: [
          text(Colors.black, stroke: Paint()..style = PaintingStyle.stroke..strokeWidth = 7..color = const Color(0xFF3E0000)),
          text(Colors.black, stroke: Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..color = Colors.deepOrange),
          text(Colors.yellowAccent),
          Positioned(right: -10, top: -8, child: Icon(Icons.auto_awesome, size: big * 0.6, color: Colors.white)),
          Positioned(left: -8, bottom: -6, child: Icon(Icons.auto_awesome, size: big * 0.45, color: Colors.amberAccent)),
        ],
      ),
    );
  }
}

/// Brasas flotantes de fondo (partículas baratas) para dar vida a la arena.
class DuelEmbers extends StatelessWidget {
  final double clock;
  final Color color;
  const DuelEmbers({super.key, required this.clock, this.color = const Color(0xFFFFB74D)});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _EmberPainter(clock, color), size: Size.infinite));
  }
}

class _EmberPainter extends CustomPainter {
  final double clock;
  final Color color;
  const _EmberPainter(this.clock, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 38; i++) {
      final seed = i * 12.9898;
      final fx = (math.sin(seed) * 43758.5453).abs() % 1;
      final fy = (math.sin(seed * 1.7) * 24634.6345).abs() % 1;
      final speed = 0.05 + (fx * 0.12);
      final y = (1 - ((fy + clock * speed) % 1)) * size.height;
      final x = (fx * size.width + math.sin(clock * 1.3 + i) * 14) % size.width;
      final r = 0.8 + (fy * 1.8);
      final a = (0.25 + 0.5 * ((math.sin(clock * 3 + i) + 1) / 2)) * (1 - y / size.height * 0.4);
      paint.color = color.withValues(alpha: a.clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => old.clock != clock;
}
