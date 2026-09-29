import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/models/pokemon.dart';
import 'package:pokearena/core/services/pokeapi_service.dart';
import 'package:pokearena/features/quiz/quiz_provider.dart';

class _FakeApi extends PokeApiService {
  _FakeApi() : super();
  @override
  Future<List<PokemonSummary>> fetchAllPokemon() async {
    return List.generate(
      20,
      (i) => PokemonSummary(id: i + 1, name: 'poke${i + 1}'),
    );
  }
}

void main() {
  test('startGame genera 4 opciones con la respuesta incluida', () async {
    final q = QuizProvider(_FakeApi(), Random(1));
    await q.load();
    q.startGame();
    expect(q.options.length, 4);
    expect(q.options.map((e) => e.id).toSet().length, 4);
    expect(q.options.any((e) => e.id == q.current!.id), isTrue);
    q.dispose();
  });

  test('acierto suma puntaje y cuenta correctos', () async {
    final q = QuizProvider(_FakeApi(), Random(2));
    await q.load();
    q.startGame();
    final before = q.score;
    q.reveal(q.current);
    expect(q.correctCount, 1);
    expect(q.score, greaterThan(before));
    q.dispose();
  });

  test('fallo no suma puntaje', () async {
    final q = QuizProvider(_FakeApi(), Random(3));
    await q.load();
    q.startGame();
    final wrong = q.options.firstWhere((e) => e.id != q.current!.id);
    q.reveal(wrong);
    expect(q.correctCount, 0);
    expect(q.score, 0);
    q.dispose();
  });
}
