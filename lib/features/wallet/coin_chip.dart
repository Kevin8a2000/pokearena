import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'wallet_provider.dart';

/// Chip del monedero para los AppBar (Equipo, Batalla…). Con [golden] se
/// muestra como la píldora dorada de la Pokédex (borde y moneda dorados).
class CoinChip extends StatelessWidget {
  final bool golden;
  const CoinChip({super.key, this.golden = false});

  @override
  Widget build(BuildContext context) {
    final coins = context.select<WalletProvider, int>((w) => w.coins);
    if (!golden) {
      return Chip(
        avatar: const Icon(Icons.monetization_on, size: 18),
        label: Text('$coins'),
        visualDensity: VisualDensity.compact,
      );
    }
    return Semantics(
      label: '$coins monedas',
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF2B705), width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE066), Color(0xFFF2A900)]),
                boxShadow: [BoxShadow(color: Color(0x66B26A00), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: const Text('P', style: TextStyle(color: Color(0xFF8A5A00), fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            const SizedBox(width: 8),
            Text(
              '$coins',
              style: const TextStyle(color: Color(0xFF14224C), fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
