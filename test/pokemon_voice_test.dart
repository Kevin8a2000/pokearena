import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokemon_voice_service.dart';

PokemonDetail _mon() => const PokemonDetail(
      id: 25,
      name: 'pikachu',
      height: 4,
      weight: 60,
      types: ['electric'],
      stats: {'hp': 35},
      abilities: [PokemonAbility(name: 'static', isHidden: false)],
    );

void main() {
  test('narrationFor menciona nombre, tipo y medidas', () {
    final text = PokemonVoiceService.narrationFor(_mon());
    expect(text, contains('Pikachu'));
    expect(text, contains('Eléctrico'));
    expect(text, contains('0.4'));
    expect(text, contains('6.0'));
  });

  test('speak sin API key no hace nada y devuelve false', () async {
    expect(await PokemonVoiceService.speak('Hola'), isFalse);
  });
}
