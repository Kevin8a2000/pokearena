import 'package:flutter/material.dart';

/// Un paso del recorrido: qué botón o panel real debe estar visible
/// ([requiredMode]: 0=reposo/4 botones, 1=ataques, 2=mochila, 3=equipo),
/// dónde enfocar ([target]) y qué explicar. La pantalla pide el modo que
/// toque antes de medir [target], así el foco siempre cae sobre el
/// elemento real (con sus datos reales), nunca sobre un ejemplo de mentira.
class GbaSpotlightStep {
  final int requiredMode;
  final GlobalKey target;
  final IconData icon;
  final String title;
  final String text;
  const GbaSpotlightStep({
    required this.requiredMode,
    required this.target,
    required this.icon,
    required this.title,
    required this.text,
  });
}

/// Motor de tutorial por pasos: ilumina al 100% el elemento real que le
/// toca a cada paso (con borde activo), oscurece el resto al 70% y lo
/// bloquea, y explica qué es y cómo se usa. Un toque en cualquier parte
/// apaga el foco actual y enciende el siguiente; cuando un paso necesita
/// un botón/panel que no es el que está abierto ahora, pide ese modo con
/// [onNeedMode] antes de avanzar. Al terminar el último paso llama a
/// [onDone].
class GbaActionSpotlight extends StatefulWidget {
  final List<GbaSpotlightStep> steps;
  final int currentMode;
  final ValueChanged<int> onNeedMode;
  final VoidCallback onDone;
  const GbaActionSpotlight({
    super.key,
    required this.steps,
    required this.currentMode,
    required this.onNeedMode,
    required this.onDone,
  });

  @override
  State<GbaActionSpotlight> createState() => _GbaActionSpotlightState();
}

/// Dim al 70% de opacidad (negro) sobre todo lo que no es el foco.
const double _kDimAlpha = 0.7;

class _GbaActionSpotlightState extends State<GbaActionSpotlight> {
  int _step = 0;

  void _advance() {
    if (_step >= widget.steps.length - 1) {
      widget.onDone();
      return;
    }
    final next = _step + 1;
    setState(() => _step = next);
    final mode = widget.steps[next].requiredMode;
    if (mode != widget.currentMode) widget.onNeedMode(mode);
  }

  /// [box] y [overlayBox] no son ancestro/descendiente entre sí (son ramas
  /// distintas del mismo Stack), así que convertimos por coordenadas
  /// globales de pantalla en vez de pedirle a `localToGlobal` un ancestro
  /// que no lo es (eso revienta el árbol de render).
  Rect? _targetRect(RenderBox overlayBox) {
    final step = widget.steps[_step];
    if (step.requiredMode != widget.currentMode) return null;
    final box = step.target.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final globalTopLeft = box.localToGlobal(Offset.zero);
    final localTopLeft = overlayBox.globalToLocal(globalTopLeft);
    return localTopLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final overlayBox = context.findRenderObject();
        final rect = overlayBox is RenderBox ? _targetRect(overlayBox) : null;
        // El objetivo real aún no está medido (cambio de modo en curso):
        // no bloquear nada hasta el siguiente frame.
        if (rect == null) return const SizedBox.shrink();
        final spot = rect.inflate(6);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _advance,
                child: CustomPaint(painter: _SpotlightPainter(spot)),
              ),
            ),
            _caption(cons, spot),
            Positioned(
              top: 6,
              right: 6,
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text('Saltar', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _caption(BoxConstraints cons, Rect spot) {
    final step = widget.steps[_step];
    final below = spot.top < cons.maxHeight * 0.45;
    return Positioned(
      left: 12,
      right: 12,
      top: below ? spot.bottom + 14 : null,
      bottom: below ? null : cons.maxHeight - spot.top + 14,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(step.icon, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(step.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  Text('${_step + 1}/${widget.steps.length}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              Text(step.text, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3)),
              const SizedBox(height: 6),
              const Text('Toca en cualquier lugar para continuar', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recorta un "agujero" redondeado en un velo negro al 70%: lo de dentro
/// queda al 100% (el foco), lo de fuera queda oscurecido y, al ir sobre un
/// `GestureDetector` opaco, también bloqueado.
class _SpotlightPainter extends CustomPainter {
  final Rect spot;
  const _SpotlightPainter(this.spot);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(RRect.fromRectAndRadius(spot, const Radius.circular(14)));
    final scrim = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(scrim, Paint()..color = Colors.black.withValues(alpha: _kDimAlpha));
    canvas.drawRRect(
      RRect.fromRectAndRadius(spot, const Radius.circular(14)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.spot != spot;
}
