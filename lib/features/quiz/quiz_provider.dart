import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/models/pokemon.dart';
import '../../core/services/pokeapi_service.dart';

enum QuizPhase { idle, playing, revealing, finished }

/// Lógica del Quiz ¿Quién es ese Pokémon? (Sprint 3).
/// - 10 rondas, 4 opciones, 15s por ronda.
/// - Silueta con [current], se revela en [revealing].
/// - Puntaje: 10 base + segundos restantes como bonus.
class QuizProvider extends ChangeNotifier {
  static const int totalRounds = 10;
  static const int secondsPerRound = 15;

  final PokeApiService _api;
  final Random _random;

  QuizProvider(this._api, [Random? random]) : _random = random ?? Random();

  List<PokemonSummary> _all = [];
  bool loading = false;
  String? error;

  QuizPhase phase = QuizPhase.idle;
  PokemonSummary? current;
  List<PokemonSummary> options = [];
  PokemonSummary? picked;

  int round = 0;
  int score = 0;
  int correctCount = 0;
  int secondsLeft = secondsPerRound;
  Timer? _timer;

  List<PokemonSummary> get all => _all;
  bool get hasData => _all.isNotEmpty;

  Future<void> load() async {
    if (hasData || loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final list = await _api.fetchAllPokemon();
      _all = list.where((p) => p.id >= 1 && p.id <= 1025).toList();
    } catch (_) {
      error = 'No se pudo cargar el Quiz. Revisa tu conexión.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void startGame() {
    if (!hasData) return;
    round = 0;
    score = 0;
    correctCount = 0;
    picked = null;
    _nextRound();
  }

  void _nextRound() {
    if (round >= totalRounds) {
      phase = QuizPhase.finished;
      _timer?.cancel();
      notifyListeners();
      return;
    }
    round++;
    // Elige respuesta correcta al azar y 3 distractores distintos.
    final correct = _all[_random.nextInt(_all.length)];
    final set = <int>{correct.id};
    final opts = <PokemonSummary>[correct];
    while (opts.length < 4) {
      final c = _all[_random.nextInt(_all.length)];
      if (set.add(c.id)) opts.add(c);
    }
    opts.shuffle(_random);
    current = correct;
    options = opts;
    picked = null;
    phase = QuizPhase.playing;
    secondsLeft = secondsPerRound;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  /// Llamado cada segundo; al llegar a 0 se revela como fallo por tiempo.
  void tick() {
    if (phase != QuizPhase.playing) return;
    if (secondsLeft > 0) {
      secondsLeft--;
      notifyListeners();
    }
    if (secondsLeft <= 0) {
      reveal(null); // tiempo agotado
    }
  }

  /// El usuario elige una opción (o null si se acabó el tiempo).
  void reveal(PokemonSummary? choice) {
    if (phase != QuizPhase.playing) return;
    _timer?.cancel();
    picked = choice;
    if (choice != null && choice.id == current!.id) {
      correctCount++;
      score += 10 + secondsLeft;
    }
    phase = QuizPhase.revealing;
    notifyListeners();
  }

  void next() => _nextRound();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
