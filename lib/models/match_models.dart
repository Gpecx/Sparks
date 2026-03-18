/// Modelos de dados para o modo Duelo de Faíscas (PvP).

enum MatchStatus { waiting, active, finished, disconnected }

class DuelQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const DuelQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

class RoundScore {
  final String playerId;
  final int questionIndex;
  final bool isCorrect;
  final int timeTakenMs;

  const RoundScore({
    required this.playerId,
    required this.questionIndex,
    required this.isCorrect,
    required this.timeTakenMs,
  });

  /// Pontuação: (Acerto * 100) - (TempoMs / 100)
  double get score => isCorrect ? (100.0 - (timeTakenMs / 100.0)).clamp(0, 100) : 0;
}

class Match {
  final String id;
  final String player1Id;
  final String player2Id;
  final List<DuelQuestion> questions;
  MatchStatus status;
  final List<RoundScore> player1Scores;
  final List<RoundScore> player2Scores;

  Match({
    required this.id,
    required this.player1Id,
    required this.player2Id,
    required this.questions,
    this.status = MatchStatus.waiting,
    List<RoundScore>? player1Scores,
    List<RoundScore>? player2Scores,
  })  : player1Scores = player1Scores ?? [],
        player2Scores = player2Scores ?? [];

  double get player1TotalScore =>
      player1Scores.fold(0.0, (sum, s) => sum + s.score);

  double get player2TotalScore =>
      player2Scores.fold(0.0, (sum, s) => sum + s.score);

  String? get winnerId {
    if (status != MatchStatus.finished) return null;
    if (player1TotalScore > player2TotalScore) return player1Id;
    if (player2TotalScore > player1TotalScore) return player2Id;
    return null; // empate
  }
}
