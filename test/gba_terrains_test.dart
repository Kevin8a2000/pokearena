import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/gba/gba_terrains.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('10 terrenos GBA con ids únicos y nombres', () {
    expect(gbaTerrains, hasLength(10));
    final ids = gbaTerrains.map((t) => t.id).toSet();
    expect(ids, hasLength(10));
    expect(
      ids,
      containsAll([
        'gba-playa',
        'gba-bosque',
        'gba-noche',
        'gba-volcan',
        'gba-nieve',
        'gba-desierto',
        'gba-jungla',
        'gba-montana',
        'gba-atardecer',
        'gba-tormenta',
      ]),
    );
    for (final t in gbaTerrains) {
      expect(t.name.isNotEmpty, isTrue);
      expect(t.bgAsset, isNull);
    }
  });

  test('gbaTerrainById resuelve y cae a Playa', () {
    expect(gbaTerrainById('gba-nieve').name, 'Nieve');
    expect(gbaTerrainById('hierba').id, 'gba-playa');
  });

  test('terreno GBA persiste por separado del 2.5D', () async {
    SharedPreferences.setMockInitialValues({});
    final b = BattleProvider(PokeApiService());
    expect(b.gbaTerrainId, 'gba-playa');
    await b.setGbaTerrain('gba-tormenta');
    expect(b.gbaTerrainId, 'gba-tormenta');
    // El clásico no se contamina.
    expect(b.terrainId, 'grass');
    await b.setGbaTerrain('no-existe');
    expect(b.gbaTerrainId, 'gba-tormenta');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pokearena_gba_terrain'), 'gba-tormenta');
  });
}
