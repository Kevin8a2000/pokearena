import 'package:flutter/material.dart';

import '../../core/theme/poke_design.dart';
import '../../core/widgets/poke_widgets.dart';
import '../../core/widgets/pokeball_background.dart';

/// Tarjeta de un modo de batalla en la portada: color propio, ilustración a la
/// izquierda, título y subtítulo, y botón rojo "Entrar →". Toda la tarjeta se
/// puede tocar.
class BattleModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final Widget illustration;
  final VoidCallback onTap;

  /// Textura de fondo: Pokébolas tenues (Normal) o ninguna.
  final bool pokeballTexture;
  const BattleModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.illustration,
    required this.onTap,
    this.pokeballTexture = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 124),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black, width: 3),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              children: [
                if (pokeballTexture)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.55,
                      child: Wrap(
                        children: [
                          for (var i = 0; i < 24; i++)
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: PokeballMark(size: 38, color: Colors.white, opacity: 0.14),
                            ),
                        ],
                      ),
                    ),
                  ),
                // Brillo interior fino.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                  child: Row(
                    children: [
                      SizedBox(width: 108, child: Center(child: illustration)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(title, maxLines: 1, style: pokeText(30, shadows: pokeTextShadow))),
                            const SizedBox(height: 2),
                            Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.2, fontWeight: FontWeight.w600, shadows: pokeTextShadow)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PokeButton(label: 'Entrar', onPressed: onTap, arrow: true, height: 42, fontSize: 17),
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
