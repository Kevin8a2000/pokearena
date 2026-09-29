/// Representa una entrada de puntaje en el historial de minijuegos / quiz (Sprint 2, Requisito F5).
class ScoreEntry {
  final String gameName;
  final int score;
  final DateTime date;

  const ScoreEntry({
    required this.gameName,
    required this.score,
    required this.date,
  });

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      gameName: (json['gameName'] as String?) ?? 'Quiz',
      score: (json['score'] as int?) ?? 0,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'gameName': gameName,
        'score': score,
        'date': date.toIso8601String(),
      };
}
