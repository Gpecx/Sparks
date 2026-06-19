import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/fs.dart';

// ─────────────────────────────────────────────────────────────────
//  DAILY CHALLENGE SERVICE — Desafio Diário
//
//  Regras de negócio:
//   • Cooldown de 24h: após concluir, o próximo só libera 24h depois
//     (mesma hora do dia seguinte ou após). Persistido em
//     users/{uid}.lastDailyChallengeCompletedAt (ver UserService).
//   • Questões: sorteadas aleatoriamente de TODO o banco existente via
//     collectionGroup('questions') — reaproveita questões já cadastradas
//     nas trilhas, sem gerar conteúdo novo.
// ─────────────────────────────────────────────────────────────────

class DailyChallengeService {
  static final DailyChallengeService _instance = DailyChallengeService._internal();
  factory DailyChallengeService() => _instance;
  DailyChallengeService._internal()
      : _fs = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  @visibleForTesting
  DailyChallengeService.forTesting(FirebaseFirestore firestore) : _fs = firestore;

  final FirebaseFirestore _fs;
  final Random _rng = Random();

  /// Intervalo entre desafios. Concluiu hoje às 15h → libera amanhã às 15h.
  static const Duration cooldown = Duration(hours: 24);

  /// Nº de questões por desafio.
  static const int questionsPerChallenge = 5;

  /// Quantas questões puxar do banco para depois embaralhar e sortear.
  /// Pool generoso para dar variedade; só é lido quando o usuário inicia o
  /// desafio (1x por dia), então o custo de leitura é aceitável.
  static const int _pool = 250;

  /// `true` se o usuário pode jogar o Desafio Diário agora.
  /// [lastCompletedAt] vem de UserModel.lastDailyChallengeCompletedAt.
  static bool isAvailable(DateTime? lastCompletedAt) {
    if (lastCompletedAt == null) return true;
    return DateTime.now().isAfter(lastCompletedAt.add(cooldown));
  }

  /// Momento em que o próximo desafio fica disponível (null se já liberado).
  static DateTime? nextAvailableAt(DateTime? lastCompletedAt) {
    if (lastCompletedAt == null) return null;
    final next = lastCompletedAt.add(cooldown);
    return DateTime.now().isAfter(next) ? null : next;
  }

  /// Tempo restante até liberar (Duration.zero se já liberado).
  static Duration remaining(DateTime? lastCompletedAt) {
    final next = nextAvailableAt(lastCompletedAt);
    if (next == null) return Duration.zero;
    return next.difference(DateTime.now());
  }

  /// Sorteia [count] questões aleatórias de todo o banco.
  /// Retorna lista vazia se o banco não tiver questões / em caso de erro.
  Future<List<QuestionModel>> fetchRandomQuestions({
    int count = questionsPerChallenge,
    String? lang,
  }) async {
    try {
      final snap = await _fs.collectionGroup(FS.questions).limit(_pool).get();
      final models = snap.docs
          .map((d) => QuestionModel.fromFirestore(d, lang: lang))
          .where((q) => q.isActive && q.statement.trim().isNotEmpty)
          .toList();
      if (models.isEmpty) return const [];
      models.shuffle(_rng);
      return models.take(count).toList();
    } catch (e) {
      debugPrint('[DailyChallengeService.fetchRandomQuestions] erro: $e');
      return const [];
    }
  }
}
