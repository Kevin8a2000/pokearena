import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/score_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScoreHistoryService - Pruebas Unitarias (Sprint 2 / Requisito F5)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('retorna lista vacía si no hay registros guardados', () async {
      final service = ScoreHistoryService();
      final history = await service.getHistory();
      expect(history, isEmpty);
    });

    test('guarda una partida y la recupera con los campos correctos', () async {
      final service = ScoreHistoryService();
      final date = DateTime(2026, 9, 28, 14, 30);

      await service.saveScore(gameName: 'Quiz de Tipos', score: 85, date: date);

      final history = await service.getHistory();
      expect(history.length, 1);
      expect(history.first.gameName, 'Quiz de Tipos');
      expect(history.first.score, 85);
      expect(history.first.date, date);
    });

    test('ordena los registros con el más reciente primero', () async {
      final service = ScoreHistoryService();
      final date1 = DateTime(2026, 9, 26);
      final date2 = DateTime(2026, 9, 27);
      final date3 = DateTime(2026, 9, 28);

      await service.saveScore(gameName: 'Quiz 1', score: 50, date: date1);
      await service.saveScore(gameName: 'Quiz 2', score: 70, date: date2);
      await service.saveScore(gameName: 'Quiz 3', score: 90, date: date3);

      final history = await service.getHistory();
      expect(history.length, 3);
      expect(history[0].gameName, 'Quiz 3');
      expect(history[1].gameName, 'Quiz 2');
      expect(history[2].gameName, 'Quiz 1');
    });

    test('filtra por nombre de juego', () async {
      final service = ScoreHistoryService();

      await service.saveScore(gameName: 'Quiz Siluetas', score: 100);
      await service.saveScore(gameName: 'Quiz Tipos', score: 80);
      await service.saveScore(gameName: 'Quiz Siluetas', score: 60);

      final filtered = await service.getHistory(gameName: 'Quiz Siluetas');
      expect(filtered.length, 2);
      expect(filtered.every((e) => e.gameName == 'Quiz Siluetas'), isTrue);
    });

    test('clearHistory vacía todos los registros', () async {
      final service = ScoreHistoryService();

      await service.saveScore(gameName: 'Quiz 1', score: 100);
      expect((await service.getHistory()).length, 1);

      await service.clearHistory();
      expect(await service.getHistory(), isEmpty);
    });
  });
}
