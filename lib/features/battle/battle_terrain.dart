import 'package:flutter/material.dart';

/// Terreno de batalla (solo cosmetico: no toca el balance).
/// Cada uno define cielo, gradas, publico, piso y si es de noche.
/// [bgAsset] es la foto del terreno (detras del pintado, sin decoracion).
/// [forNormal]/[forHorde]: en qué modos aparece (por defecto en ambos;
/// así se pueden separar los terrenos de cada modo sin romper nada).
class BattleTerrain {
  final String id;
  final String name;
  final Color skyTop;
  final Color skyBottom;
  final Color stands;
  final Color crowdA;
  final Color crowdB;
  final Color floor;
  final Color floorLine;
  final bool night;
  final String? bgAsset;
  final bool forNormal;
  final bool forHorde;

  const BattleTerrain({
    required this.id,
    required this.name,
    required this.skyTop,
    required this.skyBottom,
    required this.stands,
    required this.crowdA,
    required this.crowdB,
    required this.floor,
    required this.floorLine,
    this.night = false,
    this.bgAsset,
    this.forNormal = true,
    this.forHorde = true,
  });
}

const battleTerrains = [
  BattleTerrain(
    id: 'grass',
    name: 'Estadio Hierba',
    skyTop: Color(0xFF9ED7F5),
    skyBottom: Color(0xFFE8F6FF),
    stands: Color(0xFF8FA8BF),
    crowdA: Color(0xFFE4572E),
    crowdB: Color(0xFFF6E7C1),
    floor: Color(0xFF7CC47F),
    floorLine: Color(0xFFFFFFFF),
    bgAsset: 'assets/images/arenas/grass.png',
  ),
  BattleTerrain(
    id: 'volcano',
    name: 'Bosque Rojo',
    skyTop: Color(0xFFE8A08A),
    skyBottom: Color(0xFFF5D9C1),
    stands: Color(0xFF8A5C4E),
    crowdA: Color(0xFFB03A2E),
    crowdB: Color(0xFFFFD27A),
    floor: Color(0xFFA05C3E),
    floorLine: Color(0xFFFFFFFF),
    bgAsset: 'assets/images/arenas/volcano.png',
  ),
  BattleTerrain(
    id: 'electric',
    name: 'Mazmorra',
    skyTop: Color(0xFF101A3A),
    skyBottom: Color(0xFF2A3A7A),
    stands: Color(0xFF232B55),
    crowdA: Color(0xFFFFE14D),
    crowdB: Color(0xFF3ED6FF),
    floor: Color(0xFF3A4A8C),
    floorLine: Color(0xFFFFE14D),
    bgAsset: 'assets/images/arenas/electric.png',
    night: true,
  ),
  BattleTerrain(
    id: 'beach',
    name: 'Desierto',
    skyTop: Color(0xFF7AD9F5),
    skyBottom: Color(0xFFFFF3D6),
    stands: Color(0xFFE0B36A),
    crowdA: Color(0xFF2E9BD6),
    crowdB: Color(0xFFFF6F61),
    floor: Color(0xFFF2DC9B),
    floorLine: Color(0xFF2E9BD6),
    bgAsset: 'assets/images/arenas/beach.png',
  ),
  BattleTerrain(
    id: 'cave',
    name: 'Cueva Roca',
    skyTop: Color(0xFF2B2118),
    skyBottom: Color(0xFF6B543A),
    stands: Color(0xFF4A3A28),
    crowdA: Color(0xFFFFD27A),
    crowdB: Color(0xFF8A6F4D),
    floor: Color(0xFF9A7B4F),
    floorLine: Color(0xFFFFFFFF),
    bgAsset: 'assets/images/arenas/cave.png',
    night: true,
  ),
  BattleTerrain(
    id: 'snow',
    name: 'Pico Nieve',
    skyTop: Color(0xFFBFE3F5),
    skyBottom: Color(0xFFFFFFFF),
    stands: Color(0xFF9FB8CC),
    crowdA: Color(0xFF2E6BD6),
    crowdB: Color(0xFFFFFFFF),
    floor: Color(0xFFE8F2FA),
    floorLine: Color(0xFF2E9BD6),
    bgAsset: 'assets/images/arenas/snow.png',
  ),
  // --- Nuevos desde cero (paleta procedural + foto realista) ---
  BattleTerrain(
    id: 'ruins',
    name: 'Ruinas Nocturnas',
    skyTop: Color(0xFF16263F),
    skyBottom: Color(0xFF3E5C7E),
    stands: Color(0xFF2C3E55),
    crowdA: Color(0xFFFFD27A),
    crowdB: Color(0xFF9FB8CC),
    floor: Color(0xFF4E6B3C),
    floorLine: Color(0xFFD8E6C1),
    bgAsset: 'assets/images/arenas/ruins.png',
    night: true,
  ),
  BattleTerrain(
    id: 'ruins_day',
    name: 'Pradera Antigua',
    skyTop: Color(0xFF8FC7E8),
    skyBottom: Color(0xFFE4F4E0),
    stands: Color(0xFF7A8B6F),
    crowdA: Color(0xFFE4572E),
    crowdB: Color(0xFFF6E7C1),
    floor: Color(0xFF6FA050),
    floorLine: Color(0xFFFFFFFF),
    bgAsset: 'assets/images/arenas/ruins_day.png',
  ),
  BattleTerrain(
    id: 'castle',
    name: 'Salón Dragón',
    skyTop: Color(0xFF2A1A2E),
    skyBottom: Color(0xFF5C2E3E),
    stands: Color(0xFF4A3040),
    crowdA: Color(0xFFFFD27A),
    crowdB: Color(0xFFB03A4A),
    floor: Color(0xFF6B6560),
    floorLine: Color(0xFFFFD27A),
    bgAsset: 'assets/images/arenas/castle.png',
    night: true,
  ),
  BattleTerrain(
    id: 'castle_day',
    name: 'Gran Salón',
    skyTop: Color(0xFFF2E3C1),
    skyBottom: Color(0xFFD9B98A),
    stands: Color(0xFF8A6F4D),
    crowdA: Color(0xFFB03A4A),
    crowdB: Color(0xFFFFD27A),
    floor: Color(0xFF9A938A),
    floorLine: Color(0xFF5C2E3E),
    bgAsset: 'assets/images/arenas/castle_day.png',
  ),
  BattleTerrain(
    id: 'jungle',
    name: 'Jungla',
    skyTop: Color(0xFF0E2A24),
    skyBottom: Color(0xFF2E5C4C),
    stands: Color(0xFF1E3E34),
    crowdA: Color(0xFFD8F36B),
    crowdB: Color(0xFF2E8B57),
    floor: Color(0xFF3E6B34),
    floorLine: Color(0xFFD8F36B),
    bgAsset: 'assets/images/arenas/jungle.png',
    night: true,
  ),
  BattleTerrain(
    id: 'jungle_day',
    name: 'Jungla Viva',
    skyTop: Color(0xFF9ED7B5),
    skyBottom: Color(0xFFE8F6DC),
    stands: Color(0xFF5C8A5C),
    crowdA: Color(0xFFFFE14D),
    crowdB: Color(0xFF2E8B57),
    floor: Color(0xFF62A84E),
    floorLine: Color(0xFFFFFFFF),
    bgAsset: 'assets/images/arenas/jungle_day.png',
  ),
  BattleTerrain(
    id: 'graveyard',
    name: 'Cementerio',
    skyTop: Color(0xFF241F33),
    skyBottom: Color(0xFF5C5470),
    stands: Color(0xFF39324A),
    crowdA: Color(0xFF9DFF6B),
    crowdB: Color(0xFF5C5470),
    floor: Color(0xFF4E4A55),
    floorLine: Color(0xFF9DFF6B),
    bgAsset: 'assets/images/arenas/graveyard.png',
    night: true,
  ),
  BattleTerrain(
    id: 'panteon',
    name: 'Panteón Antiguo',
    skyTop: Color(0xFFE8D98A),
    skyBottom: Color(0xFFF5ECC1),
    stands: Color(0xFF8A7B4D),
    crowdA: Color(0xFF2E6B4E),
    crowdB: Color(0xFFF5ECC1),
    floor: Color(0xFF9A917A),
    floorLine: Color(0xFF2E6B4E),
    bgAsset: 'assets/images/arenas/panteon.png',
  ),
  BattleTerrain(
    id: 'town',
    name: 'Pueblo',
    skyTop: Color(0xFFF5C97A),
    skyBottom: Color(0xFFFFE8C1),
    stands: Color(0xFFB08A5C),
    crowdA: Color(0xFF2E9BD6),
    crowdB: Color(0xFFFF6F61),
    floor: Color(0xFFE0B36A),
    floorLine: Color(0xFFFFFFFF),
    bgAsset: 'assets/images/arenas/town.png',
  ),
  BattleTerrain(
    id: 'autumn',
    name: 'Bosque Otoñal',
    skyTop: Color(0xFFE8A05C),
    skyBottom: Color(0xFFF5D9A8),
    stands: Color(0xFF8A5C3E),
    crowdA: Color(0xFFB03A2E),
    crowdB: Color(0xFFFFD27A),
    floor: Color(0xFFC47B3E),
    floorLine: Color(0xFFFFFFFF),
    bgAsset: 'assets/images/arenas/autumn.png',
  ),
  BattleTerrain(
    id: 'torneo',
    name: 'Arena Torneo',
    skyTop: Color(0xFF5C4A6B),
    skyBottom: Color(0xFF9A8AB0),
    stands: Color(0xFF4A3E55),
    crowdA: Color(0xFFFF4A5C),
    crowdB: Color(0xFFF2F0DC),
    floor: Color(0xFFB0A090),
    floorLine: Color(0xFFFF4A5C),
    bgAsset: 'assets/images/arenas/torneo.png',
  ),
  BattleTerrain(
    id: 'meadow2',
    name: 'Pradera Alta',
    skyTop: Color(0xFF7AC7F5),
    skyBottom: Color(0xFFE0F4DC),
    stands: Color(0xFF6F8F6F),
    crowdA: Color(0xFFE4572E),
    crowdB: Color(0xFFF6E7C1),
    floor: Color(0xFF5FB85F),
    floorLine: Color(0xFFFFFFFF),
    bgAsset: 'assets/images/arenas/meadow2.png',
  ),
];

/// Terreno por id; si no existe, Hierba.
BattleTerrain terrainById(String id) {
  for (final t in battleTerrains) {
    if (t.id == id) return t;
  }
  return battleTerrains.first;
}
