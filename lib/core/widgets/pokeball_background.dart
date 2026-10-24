import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'poke_image.dart' show spriteCandidates;

/// Pokébola dibujada por código: aro grueso, banda central y botón interno.
/// Se usa como marca de agua en tarjetas y como motivo del fondo.
class PokeballMark extends StatelessWidget {
  final double size;
  final Color color;

  /// Opacidad con la que se pinta [color].
  final double opacity;
  const PokeballMark({super.key, required this.size, this.color = Colors.white, this.opacity = 0.35});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: PokeballPainter(color.withValues(alpha: opacity))),
    );
  }
}

/// Pintor de la Pokébola (contorno y bandas en un solo color).
class PokeballPainter extends CustomPainter {
  final Color color;
  const PokeballPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Aro exterior grueso.
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.24,
    );
    // Banda horizontal central.
    canvas.drawRect(Rect.fromCenter(center: c, width: r * 1.56, height: r * 0.20), Paint()..color = color);
    // Botón interno: aro + punto.
    canvas.drawCircle(
      c,
      r * 0.24,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );
    canvas.drawCircle(c, r * 0.12, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant PokeballPainter old) => old.color != color;
}

/// Pokémon que decoran los fondos (siluetas de los más conocidos).
const _patternIds = [25, 1, 4, 7, 133, 39, 143, 94, 129, 52, 54, 131, 12, 16, 63, 92, 104, 113, 150, 151];

/// Motivo de siluetas de Pokémon repartidas (sin tapar el contenido): cada
/// silueta es el arte oficial teñido de un solo color. Las posiciones, tamaños
/// y giros son deterministas ([seed]), así que no parpadea entre repintados.
/// Si no hay red simplemente no se ve ninguna silueta.
class PokemonPattern extends StatelessWidget {
  /// Distancia entre siluetas (más pequeño = más densas).
  final double cell;
  final Color color;
  final int seed;
  const PokemonPattern({super.key, this.cell = 130, this.color = const Color(0x12FFFFFF), this.seed = 7});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, c) {
          if (!c.hasBoundedWidth || !c.hasBoundedHeight) return const SizedBox.shrink();
          final rnd = math.Random(seed);
          final rows = (c.maxHeight / cell).ceil() + 1;
          final cols = (c.maxWidth / cell).ceil() + 1;
          final items = <Widget>[];
          for (var row = 0; row < rows; row++) {
            for (var col = 0; col < cols; col++) {
              final dx = (row.isOdd ? cell / 2 : 0) + (rnd.nextDouble() - 0.5) * cell * 0.2;
              final dy = (rnd.nextDouble() - 0.5) * cell * 0.2;
              final s = cell * (0.62 + rnd.nextDouble() * 0.2);
              final id = _patternIds[rnd.nextInt(_patternIds.length)];
              final angle = (rnd.nextDouble() - 0.5) * 0.6;
              items.add(
                Positioned(
                  left: col * cell + dx - s / 2,
                  top: row * cell + dy - s / 2,
                  width: s,
                  height: s,
                  child: Transform.rotate(
                    angle: angle,
                    child: Image.network(
                      spriteCandidates(id)[0],
                      fit: BoxFit.contain,
                      cacheWidth: 160,
                      color: color,
                      colorBlendMode: BlendMode.srcIn,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              );
            }
          }
          return ClipRect(child: Stack(children: items));
        },
      ),
    );
  }
}

/// Fondo azul marino con siluetas de Pokémon tenues repartidas.
class PokeballBackground extends StatelessWidget {
  /// Distancia entre siluetas (más pequeño = más densas).
  final double cell;
  const PokeballBackground({super.key, this.cell = 130});

  static const top = Color(0xFF14224C);
  static const bottom = Color(0xFF0A1330);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
      ),
      child: PokemonPattern(cell: cell),
    );
  }
}
