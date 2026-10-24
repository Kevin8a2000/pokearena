import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/core/widgets/poke_image.dart';
import 'package:pokearena/features/battle/battle_provider.dart';
import 'package:pokearena/features/battle/horde_fight_view.dart'
    show hordeSlots, shade;

void main() {
  test('front usa pixel con respaldo en arte oficial', () {
    final urls = spriteCandidates(129,
        PokeSpriteKind.front);
    expect(urls.first,
        contains('sprites/pokemon/129.png'));
    expect(urls.any((u) => u.contains('official-artwork')), isTrue);
  });

  test('back usa espalda con caídas a frente y arte', () {
    final urls =
        spriteCandidates(25, PokeSpriteKind.back);
    expect(
        urls.first, contains('sprites/pokemon/back/25.png'));
    expect(urls.any((u) => u.contains('sprites/pokemon/25.png')),
        isTrue);
    expect(urls.any((u) => u.contains('official-artwork')), isTrue);
  });

  test('hordeMode inicia apagado y se puede activar', () {
    final b = BattleProvider(PokeApiService());
    expect(b.hordeMode, isFalse);
    b.setHordeMode(true);
    expect(b.hordeMode, isTrue);
  });

  test('conteos 1-3 con clamp y 3v3 por defecto', () {
    final b = BattleProvider(PokeApiService());
    expect(b.playerCount, 3);
    expect(b.enemyCount, 3);
    b.setPlayerCount(9);
    b.setEnemyCount(0);
    expect(b.playerCount, 3);
    expect(b.enemyCount, 1);
  });

  test('hordeSlots centra con 1 y simétrico con 3', () {
    final one = hordeSlots(1);
    expect(one, hasLength(1));
    expect(one.first.x, 0.0);
    final three = hordeSlots(3);
    expect(three, hasLength(3));
    expect(three[0].x, closeTo(-three[2].x, 1e-9));
    expect(three[0].y, closeTo(three[2].y, 1e-9));
    expect(three[1].scale, greaterThan(three[0].scale));
    expect(hordeSlots(0), isEmpty);
  });

  test('shade aclara y oscurece', () {
    const base = Color(0xFF808080);
    expect(shade(base, 1.0), Colors.white);
    expect(shade(base, -1.0), Colors.black);
    expect(shade(base, 0.0), base);
  });
}
