import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:spark_app/services/analytics_service.dart';
import 'package:spark_app/services/audit_service.dart';
import 'package:spark_app/services/user_service.dart';

// ─────────────────────────────────────────────────────────────────
//  GAMIFICATION SERVICE — Missões diárias e desafios semanais
//
//  Missão diária:
//    - Completar 3 lições num mesmo dia
//    - Recompensa: badge 'daily_warrior' + 50 SP
//    - Salvo em: users/{uid}/missions/daily_{yyyy-MM-dd}
//
//  Desafio semanal (streak):
//    - Manter streak por 7 dias consecutivos
//    - Recompensa: badge 'weekly_warrior' + 100 XP
//    - Salvo em: users/{uid}/missions/weekly_{yyyy-Www}
//
//  Uso:
//    await GamificationService().onLessonCompleted(uid);
//    await GamificationService().checkWeeklyChallenge(uid, currentStreak);
// ─────────────────────────────────────────────────────────────────

class GamificationService {
  // ── Singleton ──────────────────────────────────────────────────
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────────────────────────
  //  MISSÃO DIÁRIA — 3 lições = daily_warrior + 50 SP
  // ─────────────────────────────────────────────────────────────────

  /// Deve ser chamado após cada lição completada.
  /// Incrementa o contador diário e, ao atingir 3, concede a recompensa.
  ///
  /// [uid] — UID do usuário
  /// Retorna [DailyMissionResult] com o estado atual da missão.
  Future<DailyMissionResult> onLessonCompleted(String uid) async {
    if (uid.isEmpty) return DailyMissionResult.empty();

    final docId = _dailyDocId();
    final missionRef = _db
        .collection('users')
        .doc(uid)
        .collection('missions')
        .doc(docId);

    try {
      final snap = await missionRef.get();

      // Se a missão já foi concluída hoje, não faz nada
      if (snap.exists && snap.data()?['completed'] == true) {
        final count = (snap.data()?['lessonsCount'] as num?)?.toInt() ?? 3;
        return DailyMissionResult(
          lessonsCount: count,
          target: 3,
          isCompleted: true,
          isNewlyCompleted: false,
        );
      }

      final currentCount = snap.exists
          ? (snap.data()?['lessonsCount'] as num?)?.toInt() ?? 0
          : 0;
      final newCount = currentCount + 1;
      final isCompleted = newCount >= 3;

      // Atualiza o documento da missão diária
      await missionRef.set({
        'type': 'daily',
        'date': _todayString(),
        'lessonsCount': newCount,
        'target': 3,
        'completed': isCompleted,
        if (isCompleted) 'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
          '[Gamification] Missão diária: $newCount/3 ${isCompleted ? "✓ COMPLETA" : ""}');

      // Concede recompensa ao completar a missão
      if (isCompleted) {
        await _grantDailyReward(uid);
      }

      return DailyMissionResult(
        lessonsCount: newCount,
        target: 3,
        isCompleted: isCompleted,
        isNewlyCompleted: isCompleted,
      );
    } catch (e) {
      debugPrint('[Gamification] Erro na missão diária: $e');
      return DailyMissionResult.empty();
    }
  }

  Future<void> _grantDailyReward(String uid) async {
    try {
      // Badge daily_warrior + 50 SP
      final userService = UserService();

      // Desbloqueia badge
      await userService.unlockBadge('daily_warrior', source: 'daily_mission');

      // Concede Spark Points
      await userService.addSparkPoints(50, source: 'daily_mission');

      // Audit log
      await AuditService().logForUser(
        uid: uid,
        action: AuditAction.dailyMissionCompleted,
        amount: 50,
        source: 'daily_mission',
        meta: {'badge': 'daily_warrior', 'spGranted': 50},
      );

      // Analytics
      await AnalyticsService().logDailyMissionCompleted(spGranted: 50);

      debugPrint('[Gamification] daily_warrior desbloqueado! +50 SP');
    } catch (e) {
      debugPrint('[Gamification] Erro ao conceder recompensa diária: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  DESAFIO SEMANAL — Streak 7 dias = weekly_warrior + 100 XP
  // ─────────────────────────────────────────────────────────────────

  /// Deve ser chamado após registerStudyActivity() quando o streak é atualizado.
  /// Verifica se o streak atingiu 7 dias e concede a recompensa semanal.
  ///
  /// [uid]           — UID do usuário
  /// [currentStreak] — streak atual após a atualização
  /// Retorna [WeeklyMissionResult] com o estado atual.
  Future<WeeklyMissionResult> checkWeeklyChallenge(
    String uid,
    int currentStreak,
  ) async {
    if (uid.isEmpty || currentStreak < 7) {
      return WeeklyMissionResult(
        currentStreak: currentStreak,
        target: 7,
        isCompleted: false,
        isNewlyCompleted: false,
      );
    }

    final docId = _weeklyDocId();
    final missionRef = _db
        .collection('users')
        .doc(uid)
        .collection('missions')
        .doc(docId);

    try {
      final snap = await missionRef.get();

      // Recompensa já concedida nesta semana
      if (snap.exists && snap.data()?['completed'] == true) {
        return WeeklyMissionResult(
          currentStreak: currentStreak,
          target: 7,
          isCompleted: true,
          isNewlyCompleted: false,
        );
      }

      // Marca missão semanal como concluída
      await missionRef.set({
        'type': 'weekly',
        'week': _currentWeekString(),
        'streakAtCompletion': currentStreak,
        'target': 7,
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[Gamification] Desafio semanal COMPLETO! Streak=$currentStreak');

      await _grantWeeklyReward(uid, currentStreak);

      return WeeklyMissionResult(
        currentStreak: currentStreak,
        target: 7,
        isCompleted: true,
        isNewlyCompleted: true,
      );
    } catch (e) {
      debugPrint('[Gamification] Erro no desafio semanal: $e');
      return WeeklyMissionResult(
        currentStreak: currentStreak,
        target: 7,
        isCompleted: false,
        isNewlyCompleted: false,
      );
    }
  }

  Future<void> _grantWeeklyReward(String uid, int streak) async {
    try {
      final userService = UserService();

      // Badge weekly_warrior + 100 XP
      await userService.unlockBadge('weekly_warrior', source: 'weekly_challenge');
      await userService.addXp(100, source: 'weekly_challenge');

      // Audit log
      await AuditService().logForUser(
        uid: uid,
        action: AuditAction.weeklyMissionCompleted,
        amount: 100,
        source: 'weekly_challenge',
        meta: {'badge': 'weekly_warrior', 'streak': streak, 'xpGranted': 100},
      );

      // Analytics
      await AnalyticsService().logWeeklyMissionCompleted(
        streak: streak,
        xpGranted: 100,
      );

      debugPrint('[Gamification] weekly_warrior desbloqueado! +100 XP');
    } catch (e) {
      debugPrint('[Gamification] Erro ao conceder recompensa semanal: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  LEITURA DO ESTADO (para UI)
  // ─────────────────────────────────────────────────────────────────

  /// Retorna o estado atual da missão diária do usuário logado.
  Future<DailyMissionResult> getDailyMissionState() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return DailyMissionResult.empty();

    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('missions')
          .doc(_dailyDocId())
          .get();

      if (!snap.exists) {
        return DailyMissionResult(
          lessonsCount: 0,
          target: 3,
          isCompleted: false,
          isNewlyCompleted: false,
        );
      }

      final data = snap.data()!;
      return DailyMissionResult(
        lessonsCount: (data['lessonsCount'] as num?)?.toInt() ?? 0,
        target: 3,
        isCompleted: data['completed'] as bool? ?? false,
        isNewlyCompleted: false,
      );
    } catch (e) {
      return DailyMissionResult.empty();
    }
  }

  /// Retorna o estado atual do desafio semanal do usuário logado.
  Future<WeeklyMissionResult> getWeeklyMissionState(int currentStreak) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return WeeklyMissionResult(
        currentStreak: currentStreak,
        target: 7,
        isCompleted: false,
        isNewlyCompleted: false,
      );
    }

    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('missions')
          .doc(_weeklyDocId())
          .get();

      return WeeklyMissionResult(
        currentStreak: currentStreak,
        target: 7,
        isCompleted: snap.exists && snap.data()?['completed'] == true,
        isNewlyCompleted: false,
      );
    } catch (e) {
      return WeeklyMissionResult(
        currentStreak: currentStreak,
        target: 7,
        isCompleted: false,
        isNewlyCompleted: false,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _dailyDocId() => 'daily_${_todayString()}';

  String _currentWeekString() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final weekNum = ((dayOfYear - now.weekday + 10) / 7).floor();
    return '${now.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  String _weeklyDocId() => 'weekly_${_currentWeekString()}';
}

// ─────────────────────────────────────────────────────────────────
//  VALUE OBJECTS — resultado das operações
// ─────────────────────────────────────────────────────────────────

class DailyMissionResult {
  final int lessonsCount;
  final int target;
  final bool isCompleted;

  /// true apenas no momento em que a missão foi concluída (primeira vez).
  final bool isNewlyCompleted;

  const DailyMissionResult({
    required this.lessonsCount,
    required this.target,
    required this.isCompleted,
    required this.isNewlyCompleted,
  });

  factory DailyMissionResult.empty() => const DailyMissionResult(
        lessonsCount: 0,
        target: 3,
        isCompleted: false,
        isNewlyCompleted: false,
      );

  double get progress => (lessonsCount / target).clamp(0.0, 1.0);

  @override
  String toString() =>
      'DailyMission($lessonsCount/$target completed=$isCompleted)';
}

class WeeklyMissionResult {
  final int currentStreak;
  final int target;
  final bool isCompleted;

  /// true apenas no momento em que o desafio foi concluído (primeira vez).
  final bool isNewlyCompleted;

  const WeeklyMissionResult({
    required this.currentStreak,
    required this.target,
    required this.isCompleted,
    required this.isNewlyCompleted,
  });

  double get progress => (currentStreak / target).clamp(0.0, 1.0);

  @override
  String toString() =>
      'WeeklyMission($currentStreak/$target completed=$isCompleted)';
}
