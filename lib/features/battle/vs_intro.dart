import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Franjas de color para el destello "VS" justo al empezar el combate:
/// un rip de los fondos de pantalla VS de Pokémon Platinum (créditos en la
/// propia imagen: "VS. GYM/E4 BGS ripped by Dragon"), 256x2121px. Solo se
/// usan las 8 franjas de líder de gimnasio (Roark→Volkner), que son limpias
/// y uniformes (240x60 recortadas en y=41,128,212,289,365,439,518,601; el
/// resto de la hoja son los paneles de Alto Mando/Frontera, con forma de
/// paralelogramo y el nombre del entrenador incrustado, que no aplican
/// aquí). Medidas tomadas a mano con un muestreo de píxeles sobre el PNG.
class VsFlashAssets {
  VsFlashAssets._();

  static const String asset = 'assets/images/arenas/vs_flash_backgrounds.png';

  static ui.Image? _sheet;
  static ui.Image? get sheet => _sheet;

  static const List<Rect> bands = [
    Rect.fromLTWH(0, 41, 256, 60),
    Rect.fromLTWH(0, 128, 256, 60),
    Rect.fromLTWH(0, 212, 256, 60),
    Rect.fromLTWH(0, 289, 256, 60),
    Rect.fromLTWH(0, 365, 256, 60),
    Rect.fromLTWH(0, 439, 256, 60),
    Rect.fromLTWH(0, 518, 256, 60),
    Rect.fromLTWH(0, 601, 256, 60),
  ];

  /// Carga la hoja una sola vez; si falla, el destello simplemente no se
  /// dibuja (igual que el resto de hojas opcionales del modo GBA).
  static Future<void> load() async {
    if (_sheet != null) return;
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sheet = frame.image;
    } catch (_) {}
  }
}

/// Destello de color a pantalla completa justo al empezar un combate (como
/// la pantalla "VS [Entrenador]" de los juegos, sin el nombre porque esta
/// app no tiene entrenadores con nombre propio). Se desvanece solo y avisa
/// con [onDone] para que quien lo use pueda apagar el estado que lo mostró.
class VsFlashOverlay extends StatefulWidget {
  final int index;
  final VoidCallback? onDone;
  const VsFlashOverlay({required this.index, this.onDone, super.key});

  @override
  State<VsFlashOverlay> createState() => _VsFlashOverlayState();
}

class _VsFlashOverlayState extends State<VsFlashOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 18),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 54),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 28),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = VsFlashAssets.sheet;
    if (sheet == null) return const SizedBox.shrink();
    final rect = VsFlashAssets.bands[widget.index % VsFlashAssets.bands.length];
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => Opacity(
        opacity: _opacity.value,
        child: CustomPaint(painter: _VsFlashPainter(sheet, rect)),
      ),
    );
  }
}

class _VsFlashPainter extends CustomPainter {
  final ui.Image sheet;
  final Rect src;
  _VsFlashPainter(this.sheet, this.src);

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    canvas.drawImageRect(sheet, src, dst, Paint()..filterQuality = FilterQuality.low);
  }

  @override
  bool shouldRepaint(covariant _VsFlashPainter old) => old.sheet != sheet || old.src != src;
}
