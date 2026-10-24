import 'package:flutter/material.dart';

/// Controles físicos virtuales estilo GBA: cruceta, A/B, L/R y Select/Start.
/// Todo por código, sin assets.
class GbaDPad extends StatelessWidget {
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  const GbaDPad({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        children: [
          // Cruz.
          const Center(
            child: SizedBox(
              width: 126,
              height: 42,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF1A1A1A)),
              ),
            ),
          ),
          const Center(
            child: SizedBox(
              width: 42,
              height: 126,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF1A1A1A)),
              ),
            ),
          ),
          // Pivote central.
          const Center(
            child: SizedBox(
              width: 34,
              height: 34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // LED verde.
          Positioned(
            right: 6,
            top: 34,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF39FF6A),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xFF39FF6A), blurRadius: 6),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: IconButton(
              icon: const Icon(Icons.arrow_drop_up,
                  color: Colors.grey, size: 30),
              onPressed: onUp,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: IconButton(
              icon: const Icon(Icons.arrow_drop_down,
                  color: Colors.grey, size: 30),
              onPressed: onDown,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_left,
                  color: Colors.grey, size: 30),
              onPressed: onLeft,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.arrow_right,
                  color: Colors.grey, size: 30),
              onPressed: onRight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botones A/B rojos inclinados con brillo verde.
class GbaABButtons extends StatelessWidget {
  final VoidCallback onA;
  final VoidCallback onB;
  const GbaABButtons({super.key, required this.onA, required this.onB});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.35,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _circle('B', onB),
          const SizedBox(width: 14),
          _circle('A', onA),
        ],
      ),
    );
  }

  Widget _circle(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: const BoxDecoration(
          color: Color(0xFFCC2B2B),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black45, offset: Offset(2, 3), blurRadius: 4),
            BoxShadow(color: Color(0xFF39FF6A), blurRadius: 10),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gatillos L/R bajo la pantalla.
class GbaTriggers extends StatelessWidget {
  final VoidCallback onL;
  final VoidCallback onR;
  const GbaTriggers({super.key, required this.onL, required this.onR});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GbaTriggerButton(label: 'L', onTap: onL),
          GbaTriggerButton(label: 'R', onTap: onR),
        ],
      ),
    );
  }
}

/// Un gatillo L o R suelto (se usa en los laterales del diseño apaisado).
class GbaTriggerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const GbaTriggerButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF444444),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black26),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

/// Botón pequeño SELECT/START con etiqueta debajo.
class GbaOptionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const GbaOptionButton(
      {super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF555555),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.black38),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
