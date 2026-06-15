/// Modelos de dados para o modo Duelo de Faíscas (PvP).
///
/// As perguntas vêm das trilhas reais (Firestore, via Cloud Functions) e o
/// resultado do duelo é apurado no servidor (server-authoritative). No modo
/// PvP o `correctIndex` da questão só é revelado pelo servidor APÓS o jogador
/// responder; no modo treino (vs bot) ele vem preenchido desde o início.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus { waiting, active, finished, disconnected }

class DuelQuestion {
  final String id;
  final String statement;
  final List<String> options;

  /// `null` em PvP até o servidor revelar; preenchido no modo treino (bot).
  final int? correctIndex;

  const DuelQuestion({
    required this.id,
    required this.statement,
    required this.options,
    this.correctIndex,
  });

  factory DuelQuestion.fromMap(Map<String, dynamic> m) => DuelQuestion(
        id: m['id'] as String? ?? '',
        statement: m['statement'] as String? ?? '',
        options: List<String>.from((m['options'] as List?) ?? const []),
        correctIndex: (m['correctIndex'] as num?)?.toInt(),
      );
}

/// Resultado de uma rodada (uma questão respondida por um jogador).
class RoundScore {
  final int questionIndex;
  final bool isCorrect;
  final int timeTakenMs;
  final double score;

  const RoundScore({
    required this.questionIndex,
    required this.isCorrect,
    required this.timeTakenMs,
    required this.score,
  });

  /// Cálculo local (modo treino): (Acerto * 100) - (TempoMs / 100), 0..100.
  factory RoundScore.local({
    required int questionIndex,
    required bool isCorrect,
    required int timeTakenMs,
  }) {
    final s = isCorrect ? (100.0 - (timeTakenMs / 100.0)).clamp(0, 100).toDouble() : 0.0;
    return RoundScore(
      questionIndex: questionIndex,
      isCorrect: isCorrect,
      timeTakenMs: timeTakenMs,
      score: s,
    );
  }

  /// Vindo do documento do match no Firestore (campos gravados pela CF).
  factory RoundScore.fromMap(Map<String, dynamic> m) => RoundScore(
        questionIndex: (m['q'] as num?)?.toInt() ?? 0,
        isCorrect: m['isCorrect'] as bool? ?? false,
        timeTakenMs: (m['timeMs'] as num?)?.toInt() ?? 0,
        score: (m['score'] as num?)?.toDouble() ?? 0,
      );
}

/// Representa um duelo PvP carregado em tempo real do Firestore.
class DuelMatch {
  final String id;
  final String player1Uid;
  final String player2Uid;
  final String player1Name;
  final String player2Name;
  final String? player1Photo;
  final String? player2Photo;
  final int player1Elo;
  final int player2Elo;
  final String status; // 'active' | 'finished'
  final bool isBot;
  final List<DuelQuestion> questions;
  final List<RoundScore> player1Scores;
  final List<RoundScore> player2Scores;
  final bool player1Done;
  final bool player2Done;
  final String? winnerId;

  const DuelMatch({
    required this.id,
    required this.player1Uid,
    required this.player2Uid,
    required this.player1Name,
    required this.player2Name,
    this.player1Photo,
    this.player2Photo,
    required this.player1Elo,
    required this.player2Elo,
    required this.status,
    required this.isBot,
    required this.questions,
    required this.player1Scores,
    required this.player2Scores,
    required this.player1Done,
    required this.player2Done,
    this.winnerId,
  });

  factory DuelMatch.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    List<RoundScore> parseScores(dynamic v) =>
        ((v as List?) ?? const [])
            .map((e) => RoundScore.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();

    return DuelMatch(
      id: doc.id,
      player1Uid: d['player1Uid'] as String? ?? '',
      player2Uid: d['player2Uid'] as String? ?? '',
      player1Name: d['player1Name'] as String? ?? 'Jogador 1',
      player2Name: d['player2Name'] as String? ?? 'Jogador 2',
      player1Photo: d['player1Photo'] as String?,
      player2Photo: d['player2Photo'] as String?,
      player1Elo: (d['player1Elo'] as num?)?.toInt() ?? 1200,
      player2Elo: (d['player2Elo'] as num?)?.toInt() ?? 1200,
      status: d['status'] as String? ?? 'active',
      isBot: d['isBot'] as bool? ?? false,
      questions: ((d['questions'] as List?) ?? const [])
          .map((e) => DuelQuestion.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      player1Scores: parseScores(d['player1Scores']),
      player2Scores: parseScores(d['player2Scores']),
      player1Done: d['player1Done'] as bool? ?? false,
      player2Done: d['player2Done'] as bool? ?? false,
      winnerId: d['winnerId'] as String?,
    );
  }

  bool get isFinished => status == 'finished';

  // ── Perspectiva relativa ao jogador local ──────────────────────────
  bool amPlayer1(String uid) => player1Uid == uid;

  List<RoundScore> myScores(String uid) => amPlayer1(uid) ? player1Scores : player2Scores;
  List<RoundScore> oppScores(String uid) => amPlayer1(uid) ? player2Scores : player1Scores;

  String oppName(String uid) => amPlayer1(uid) ? player2Name : player1Name;
  String? oppPhoto(String uid) => amPlayer1(uid) ? player2Photo : player1Photo;
  int oppElo(String uid) => amPlayer1(uid) ? player2Elo : player1Elo;

  double myTotal(String uid) => myScores(uid).fold(0.0, (s, r) => s + r.score);
  double oppTotal(String uid) => oppScores(uid).fold(0.0, (s, r) => s + r.score);
}

// ── Resultados das chamadas às Cloud Functions ───────────────────────

class JoinQueueResult {
  final String status; // 'matched' | 'waiting'
  final String? matchId;
  const JoinQueueResult({required this.status, this.matchId});

  bool get matched => status == 'matched' && matchId != null;
}

class SubmitAnswerResult {
  final bool isCorrect;
  final int correctIndex;
  final double score;
  const SubmitAnswerResult({
    required this.isCorrect,
    required this.correctIndex,
    required this.score,
  });
}

class FinalizeResult {
  final String status; // 'finished' | 'waiting'
  final String? winnerId;
  final double? player1Total;
  final double? player2Total;
  final int eloChange;
  const FinalizeResult({
    required this.status,
    this.winnerId,
    this.player1Total,
    this.player2Total,
    this.eloChange = 0,
  });

  bool get finished => status == 'finished';
}
