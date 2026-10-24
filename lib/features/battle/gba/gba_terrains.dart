import 'package:flutter/material.dart';

import '../battle_terrain.dart';

/// Terrenos exclusivos del modo Normal (vista GBA), pintados por código
/// con paisaje y animación propios. No tocan los 18 del modo 2.5D.
const gbaTerrains = [
  BattleTerrain(
    id: 'gba-playa',
    name: 'Playa',
    skyTop: Color(0xFF6EC6F5),
    skyBottom: Color(0xFFD8F4FF),
    stands: Color(0xFF5C8AA8),
    crowdA: Color(0xFF2E9BD6),
    crowdB: Color(0xFFFF6F61),
    floor: Color(0xFFF2DC9B),
    floorLine: Color(0xFF2E9BD6),
  ),
  BattleTerrain(
    id: 'gba-bosque',
    name: 'Bosque',
    skyTop: Color(0xFF8FD0F5),
    skyBottom: Color(0xFFE0F4DC),
    stands: Color(0xFF4E7A4E),
    crowdA: Color(0xFFE4572E),
    crowdB: Color(0xFFF6E7C1),
    floor: Color(0xFF62A84E),
    floorLine: Color(0xFFFFFFFF),
  ),
  BattleTerrain(
    id: 'gba-noche',
    name: 'Noche',
    skyTop: Color(0xFF0A1030),
    skyBottom: Color(0xFF2A3A6E),
    stands: Color(0xFF1A2340),
    crowdA: Color(0xFFD8F36B),
    crowdB: Color(0xFF8A9BD6),
    floor: Color(0xFF2E3A55),
    floorLine: Color(0xFFD8F36B),
    night: true,
  ),
  BattleTerrain(
    id: 'gba-volcan',
    name: 'Volcán',
    skyTop: Color(0xFF2B1420),
    skyBottom: Color(0xFF7A2E22),
    stands: Color(0xFF4A2620),
    crowdA: Color(0xFFFFB03A),
    crowdB: Color(0xFF5B1F1F),
    floor: Color(0xFF3E2A26),
    floorLine: Color(0xFFFF7A3C),
    night: true,
  ),
  BattleTerrain(
    id: 'gba-nieve',
    name: 'Nieve',
    skyTop: Color(0xFFAED4F5),
    skyBottom: Color(0xFFFFFFFF),
    stands: Color(0xFF8FA8BF),
    crowdA: Color(0xFF2E6BD6),
    crowdB: Color(0xFFFFFFFF),
    floor: Color(0xFFE8F2FA),
    floorLine: Color(0xFF2E9BD6),
  ),
  BattleTerrain(
    id: 'gba-desierto',
    name: 'Desierto',
    skyTop: Color(0xFFF5C97A),
    skyBottom: Color(0xFFFFE8C1),
    stands: Color(0xFFB08A5C),
    crowdA: Color(0xFFB03A2E),
    crowdB: Color(0xFFFFD27A),
    floor: Color(0xFFE0B36A),
    floorLine: Color(0xFFFFFFFF),
  ),
  BattleTerrain(
    id: 'gba-jungla',
    name: 'Jungla',
    skyTop: Color(0xFF4E9E6B),
    skyBottom: Color(0xFFC8E8B0),
    stands: Color(0xFF2E6B4E),
    crowdA: Color(0xFFFFE14D),
    crowdB: Color(0xFF2E8B57),
    floor: Color(0xFF3E7A3E),
    floorLine: Color(0xFFD8F36B),
  ),
  BattleTerrain(
    id: 'gba-montana',
    name: 'Montaña',
    skyTop: Color(0xFF7AA8D0),
    skyBottom: Color(0xFFE0EAF5),
    stands: Color(0xFF5C6E85),
    crowdA: Color(0xFF2E6BD6),
    crowdB: Color(0xFFFFFFFF),
    floor: Color(0xFFD8E2EC),
    floorLine: Color(0xFF5C6E85),
  ),
  BattleTerrain(
    id: 'gba-atardecer',
    name: 'Atardecer',
    skyTop: Color(0xFFE88A5C),
    skyBottom: Color(0xFFF5D9A8),
    stands: Color(0xFF8A5C4E),
    crowdA: Color(0xFFB03A2E),
    crowdB: Color(0xFFFFD27A),
    floor: Color(0xFFC47B5C),
    floorLine: Color(0xFFFFFFFF),
  ),
  BattleTerrain(
    id: 'gba-tormenta',
    name: 'Tormenta',
    skyTop: Color(0xFF1A2233),
    skyBottom: Color(0xFF3E4E6B),
    stands: Color(0xFF232B3E),
    crowdA: Color(0xFF7AD9F5),
    crowdB: Color(0xFF5C6E8A),
    floor: Color(0xFF2E3A4E),
    floorLine: Color(0xFF7AD9F5),
    night: true,
  ),
];

/// Terreno GBA por id; si no existe, Playa.
BattleTerrain gbaTerrainById(String id) {
  for (final t in gbaTerrains) {
    if (t.id == id) return t;
  }
  return gbaTerrains.first;
}
