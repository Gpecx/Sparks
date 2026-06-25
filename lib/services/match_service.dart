import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:spark_app/models/match_models.dart';

/// Serviço do Duelo de Faíscas (PvP) — matchmaking e partida apurados no
/// servidor (Cloud Functions), com sincronização em tempo real via Firestore.
///
/// - Matchmaking: [joinQueue] / [leaveQueue] (CFs joinDuelQueue/leaveDuelQueue),
///   com [myQueueMatchStream] para detectar quando um oponente nos pareia.
/// - Partida: [matchStream] (tempo real), [submitAnswer] (validação no servidor)
///   e [finalize] (apuração + ELO dos dois jogadores).
/// - Treino: [getBotQuestions] traz perguntas reais (com gabarito) para jogar
///   contra um bot localmente — não afeta o ranking.
class MatchService {
  static final MatchService _instance = MatchService._internal();
  factory MatchService() => _instance;
  MatchService._internal();

  final _db =
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
  final _functions =
      FirebaseFunctions.instanceFor(region: 'southamerica-east1');
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser?.uid ?? '';

  // ── Matchmaking ─────────────────────────────────────────────────────

  /// Entra na fila ou é pareado imediatamente. Reentrante: serve também como
  /// heartbeat enquanto o jogador aguarda.
  Future<JoinQueueResult> joinQueue() async {
    final res = await _functions.httpsCallable('joinDuelQueue').call();
    final d = Map<String, dynamic>.from(res.data as Map);
    return JoinQueueResult(
      status: d['status'] as String? ?? 'waiting',
      matchId: d['matchId'] as String?,
    );
  }

  /// Sai da fila (cancelar busca). Best-effort.
  Future<void> leaveQueue() async {
    try {
      await _functions.httpsCallable('leaveDuelQueue').call();
    } catch (e) {
      debugPrint('[MatchService.leaveQueue] $e');
    }
  }

  /// Abandona um duelo EM ANDAMENTO (saiu no meio): o servidor encerra a
  /// partida dando a vitória (e o ELO) ao oponente que continuou. Best-effort.
  Future<void> leaveDuel(String matchId) async {
    try {
      await _functions.httpsCallable('leaveDuel').call({'matchId': matchId});
    } catch (e) {
      debugPrint('[MatchService.leaveDuel] $e');
    }
  }

  /// Emite o `matchId` assim que outro jogador nos parear (listener do nosso
  /// próprio doc de fila).
  Stream<String?> myQueueMatchStream() {
    if (uid.isEmpty) return const Stream<String?>.empty();
    return _db
        .collection('matchmaking_queue')
        .doc(uid)
        .snapshots()
        .map((s) => s.data()?['matchId'] as String?);
  }

  // ── Partida (PvP) ───────────────────────────────────────────────────

  /// Estado do duelo em tempo real.
  Stream<DuelMatch> matchStream(String matchId) {
    return _db
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .where((s) => s.exists)
        .map((s) => DuelMatch.fromFirestore(s));
  }

  /// Envia uma resposta para validação no servidor. Retorna acerto + índice
  /// correto (revelado só agora) + pontuação da rodada.
  Future<SubmitAnswerResult> submitAnswer({
    required String matchId,
    required int questionIndex,
    required int selectedOption,
    required int elapsedMs,
  }) async {
    final res = await _functions.httpsCallable('submitDuelAnswer').call({
      'matchId': matchId,
      'questionIndex': questionIndex,
      'selectedOption': selectedOption,
      'elapsedMs': elapsedMs,
    });
    final d = Map<String, dynamic>.from(res.data as Map);
    return SubmitAnswerResult(
      isCorrect: d['isCorrect'] as bool? ?? false,
      correctIndex: (d['correctIndex'] as num?)?.toInt() ?? -1,
      score: (d['score'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Pede a apuração do duelo. Se o oponente ainda não terminou, retorna
  /// `status: waiting` (use [force] após o timeout de abandono).
  Future<FinalizeResult> finalize({
    required String matchId,
    bool force = false,
  }) async {
    final res = await _functions.httpsCallable('finalizeDuel').call({
      'matchId': matchId,
      'force': force,
    });
    final d = Map<String, dynamic>.from(res.data as Map);
    return FinalizeResult(
      status: d['status'] as String? ?? 'waiting',
      winnerId: d['winnerId'] as String?,
      player1Total: (d['player1Total'] as num?)?.toDouble(),
      player2Total: (d['player2Total'] as num?)?.toDouble(),
      eloChange: (d['eloChange'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Histórico de duelos ─────────────────────────────────────────────

  /// Últimos duelos PvP encerrados do jogador (mais recentes primeiro).
  ///
  /// O Firestore não faz OR entre campos diferentes com `orderBy`, então
  /// rodamos duas queries (como player1 e como player2), mesclamos e
  /// ordenamos por `finishedAt`. Exige índices compostos
  /// (player1Uid+finishedAt e player2Uid+finishedAt) — ver firestore.indexes.json.
  Future<List<DuelMatch>> fetchDuelHistory({int limit = 20}) async {
    if (uid.isEmpty) return const [];
    final col = _db.collection('matches');

    Future<List<DuelMatch>> queryBy(String field) async {
      final snap = await col
          .where(field, isEqualTo: uid)
          .where('status', isEqualTo: 'finished')
          .orderBy('finishedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(DuelMatch.fromFirestore).toList();
    }

    final results = await Future.wait([
      queryBy('player1Uid'),
      queryBy('player2Uid'),
    ]);

    // Mescla, remove treinos/bots e duplicatas, ordena por data e corta no limite.
    final byId = <String, DuelMatch>{};
    for (final m in [...results[0], ...results[1]]) {
      if (m.isBot) continue;
      byId[m.id] = m;
    }
    final all = byId.values.toList()
      ..sort((a, b) => (b.finishedAt ?? DateTime(0))
          .compareTo(a.finishedAt ?? DateTime(0)));
    return all.take(limit).toList();
  }

  // ── Treino (vs bot) ─────────────────────────────────────────────────

  /// Perguntas reais (com gabarito) para uma partida de treino local.
  Future<List<DuelQuestion>> getBotQuestions({int count = 8}) async {
    final res = await _functions
        .httpsCallable('getBotDuelQuestions')
        .call({'count': count});
    final d = Map<String, dynamic>.from(res.data as Map);
    return ((d['questions'] as List?) ?? const [])
        .map((e) => DuelQuestion.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
