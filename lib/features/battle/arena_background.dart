import 'package:flutter/material.dart';

import 'battle_terrain.dart';

/// Fondo fotográfico del terreno detrás del pintado procedural
/// (dunas + plataformas). Sin decoración superpuesta: solo la foto.
/// Si el archivo falta, muestra el degradado de siempre.
class ArenaBackground extends StatelessWidget {
  final BattleTerrain terrain;
  final double borderRadius;

  const ArenaBackground({
    super.key,
    required this.terrain,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [terrain.skyTop, terrain.skyBottom],
        ),
      ),
    );
    final asset = terrain.bgAsset;
    if (asset == null) return Positioned.fill(child: fallback);
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => fallback,
        ),
      ),
    );
  }
}
