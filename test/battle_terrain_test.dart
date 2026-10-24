import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/features/battle/battle_terrain.dart';

void main() {
  test('hay 18 terrenos con ids únicos y nombres', () {
    expect(battleTerrains, hasLength(18));
    final ids = battleTerrains.map((t) => t.id).toSet();
    expect(ids, hasLength(18));
    expect(
      ids,
      containsAll([
        'grass',
        'volcano',
        'electric',
        'beach',
        'cave',
        'snow',
        'ruins',
        'ruins_day',
        'castle',
        'castle_day',
        'jungle',
        'jungle_day',
        'graveyard',
        'panteon',
        'town',
        'autumn',
        'torneo',
        'meadow2',
      ]),
    );
    for (final t in battleTerrains) {
      expect(t.name.isNotEmpty, isTrue);
    }
  });

  test('noche solo en interiores y cuevas', () {
    final night =
        battleTerrains.where((t) => t.night).map((t) => t.id).toSet();
    expect(
      night,
      containsAll(
          ['electric', 'cave', 'ruins', 'castle', 'jungle', 'graveyard']),
    );
    expect(night.contains('grass'), isFalse);
    expect(night.contains('beach'), isFalse);
  });

  test('cada terreno tiene foto de fondo', () {
    for (final t in battleTerrains) {
      expect(t.bgAsset, endsWith('.png'));
    }
  });

  test('cada modo tiene terrenos y ninguno queda huérfano', () {
    final normal = battleTerrains.where((t) => t.forNormal);
    final horde = battleTerrains.where((t) => t.forHorde);
    expect(normal, isNotEmpty);
    expect(horde, isNotEmpty);
    for (final t in battleTerrains) {
      expect(t.forNormal || t.forHorde, isTrue);
    }
  });

  test('terrainById resuelve y cae a Hierba si no existe', () {
    expect(terrainById('volcano').name, 'Bosque Rojo');
    expect(terrainById('playa').id, 'grass');
  });

  test('mazmorra y eléctrico nocturnos; bosque rojo de día', () {
    expect(terrainById('electric').night, isTrue);
    expect(terrainById('volcano').night, isFalse);
    expect(terrainById('grass').night, isFalse);
    expect(terrainById('beach').night, isFalse);
  });
}
