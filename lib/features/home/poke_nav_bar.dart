import 'package:flutter/material.dart';

import '../../core/theme/poke_design.dart';
import '../../core/widgets/poke_widgets.dart';

/// Un destino de la barra: etiqueta y su icono ilustrado.
class PokeNavDestination {
  final String label;
  final Widget Function(double size) icon;
  const PokeNavDestination(this.label, this.icon);
}

/// Los 6 destinos de la app, en el orden de las pestañas de `HomeShell`.
final List<PokeNavDestination> pokeNavDestinations = [
  PokeNavDestination('Pokédex', (s) => PokeBallIcon(size: s)),
  PokeNavDestination('Equipo', (s) => _TeamIcon(size: s)),
  PokeNavDestination('Batalla', (s) => _GloveIcon(size: s)),
  PokeNavDestination('Quiz', (s) => _QuizIcon(size: s)),
  PokeNavDestination('Perfil', (s) => _TrainerIcon(size: s)),
  PokeNavDestination('Ajustes', (s) => _GearIcon(size: s)),
];

/// Barra de navegación inferior grande: fondo azul marino con filo dorado,
/// iconos ilustrados (dibujados por código) y etiqueta blanca en negrita. El
/// destino activo va en una cápsula oscura con borde dorado.
class PokeNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const PokeNavBar({super.key, required this.index, required this.onTap});

  static const navy = Color(0xFF0B1330);
  static const gold = Color(0xFFE8B923);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14204A), navy]),
        border: Border(top: BorderSide(color: gold, width: 2.5)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (var i = 0; i < pokeNavDestinations.length; i++)
                Expanded(
                  child: _NavTile(
                    destination: pokeNavDestinations[i],
                    selected: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final PokeNavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.destination, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            // Activo: cuadrado rojo con borde dorado y brillo (como el diseño).
            decoration: BoxDecoration(
              gradient: selected ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [PokeColors.redLight, PokeColors.redDark]) : null,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? PokeNavBar.gold : Colors.transparent, width: 2.5),
              boxShadow: selected ? [BoxShadow(color: PokeNavBar.gold.withValues(alpha: 0.45), blurRadius: 10), const BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: selected ? 1.08 : 1.0,
                  child: destination.icon(36),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                      ),
                    ),
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

// ----------------------------------------------------------------- iconos

/// Grupo de entrenadores: icono de personas con degradado azul → naranja.
class _TeamIcon extends StatelessWidget {
  final double size;
  const _TeamIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.groups, size: size * 1.08, color: Colors.white),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF42A5F5), Color(0xFFFFA726)]).createShader(r),
            blendMode: BlendMode.srcIn,
            child: Icon(Icons.groups, size: size, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Guante de boxeo rojo con contorno claro.
class _GloveIcon extends StatelessWidget {
  final double size;
  const _GloveIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.sports_mma, size: size * 1.1, color: Colors.white),
          Icon(Icons.sports_mma, size: size * 0.96, color: const Color(0xFFD32F2F)),
        ],
      ),
    );
  }
}

/// Carta amarilla con un "?" (Quiz).
class _QuizIcon extends StatelessWidget {
  final double size;
  const _QuizIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.rotate(
          angle: -0.14,
          child: Container(
            width: size * 0.72,
            height: size * 0.92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE066), Color(0xFFF2A900)]),
              borderRadius: BorderRadius.circular(size * 0.14),
              border: Border.all(color: const Color(0xFF5D3A00), width: 2),
            ),
            child: FittedBox(
              child: Text('?', style: const TextStyle(color: Color(0xFF3A2A00), fontWeight: FontWeight.w900, fontSize: 30)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrenador con gorra roja.
class _TrainerIcon extends StatelessWidget {
  final double size;
  const _TrainerIcon({required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const _TrainerPainter());
}

class _TrainerPainter extends CustomPainter {
  const _TrainerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Hombros (camiseta azul).
    canvas.drawRRect(
      RRect.fromRectAndCorners(Rect.fromLTWH(w * 0.12, h * 0.66, w * 0.76, h * 0.34), topLeft: Radius.circular(w * 0.3), topRight: Radius.circular(w * 0.3)),
      Paint()..color = const Color(0xFF1E88E5),
    );
    // Cara.
    canvas.drawCircle(Offset(w / 2, h * 0.44), w * 0.27, Paint()..color = const Color(0xFFFFCCA0));
    // Gorra roja con visera y Pokébola.
    final cap = Paint()..color = const Color(0xFFE53935);
    canvas.drawArc(Rect.fromCircle(center: Offset(w / 2, h * 0.40), radius: w * 0.29), 3.14159, 3.14159, true, cap);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, h * 0.38, w * 0.62, h * 0.07), Radius.circular(h * 0.03)), Paint()..color = const Color(0xFFB71C1C));
    canvas.drawCircle(Offset(w / 2, h * 0.26), w * 0.07, Paint()..color = Colors.white);
    // Ojos.
    final eye = Paint()..color = const Color(0xFF212121);
    canvas.drawCircle(Offset(w * 0.42, h * 0.5), w * 0.025, eye);
    canvas.drawCircle(Offset(w * 0.58, h * 0.5), w * 0.025, eye);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Engranaje con una Pokébola en el centro (Ajustes).
class _GearIcon extends StatelessWidget {
  final double size;
  const _GearIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.settings, size: size * 1.1, color: Colors.white),
          Icon(Icons.settings, size: size * 0.98, color: const Color(0xFF90A4AE)),
          PokeBallIcon(size: size * 0.42),
        ],
      ),
    );
  }
}
