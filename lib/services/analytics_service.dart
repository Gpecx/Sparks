import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────
//  ANALYTICS SERVICE — Firebase Analytics
//
//  Centraliza todos os logEvent do app SPARK.
//  Convenção de nomes: snake_case, compatível com GA4.
//
//  Eventos implementados:
//    lesson_completed   — ao concluir uma lição
//    level_up           — ao subir de nível
//    badge_unlocked     — ao desbloquear uma conquista
//    daily_mission_done — ao completar missão diária
//    weekly_mission_done— ao completar desafio semanal
//    streak_updated     — ao registrar atividade de estudo
//    login              — ao fazer login (reutiliza evento padrão GA4)
//    sign_up            — ao registrar novo usuário (padrão GA4)
//
//  Uso:
//    await AnalyticsService().logLessonCompleted(
//      moduleId: 'nr10_basico',
//      lessonId: 'lesson_01',
//      timeSpentSeconds: 120,
//      score: 90,
//      xpEarned: 50,
//    );
// ─────────────────────────────────────────────────────────────────

class AnalyticsService {
  // ── Singleton ──────────────────────────────────────────────────
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final _analytics = FirebaseAnalytics.instance;

  // ─────────────────────────────────────────────────────────────────
  //  LIÇÃO COMPLETADA — evento principal de aprendizagem
  // ─────────────────────────────────────────────────────────────────

  /// Dispara `lesson_completed` com contexto completo.
  ///
  /// Parâmetros GA4:
  ///   [moduleId]          — ID do módulo (ex: 'nr10_basico')
  ///   [lessonId]          — ID da lição
  ///   [categoryId]        — ID da categoria/trilha (opcional)
  ///   [timeSpentSeconds]  — tempo gasto na lição em segundos
  ///   [score]             — pontuação de 0 a 100 (opcional)
  ///   [xpEarned]          — XP ganho nessa lição
  ///   [spEarned]          — Spark Points ganhos
  Future<void> logLessonCompleted({
    required String moduleId,
    required String lessonId,
    String? categoryId,
    int timeSpentSeconds = 0,
    int? score,
    int xpEarned = 0,
    int spEarned = 0,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'lesson_completed',
        parameters: <String, Object>{
          'module_id': moduleId,
          'lesson_id': lessonId,
          if (categoryId != null) 'category_id': categoryId,
          'time_spent_seconds': timeSpentSeconds,
          if (score != null) 'score': score,
          'xp_earned': xpEarned,
          'sp_earned': spEarned,
        },
      );
      debugPrint('[Analytics] lesson_completed: $moduleId/$lessonId | xp=$xpEarned');
    } catch (e) {
      debugPrint('[Analytics] Erro em lesson_completed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  SUBIDA DE NÍVEL
  // ─────────────────────────────────────────────────────────────────

  Future<void> logLevelUp({
    required int oldLevel,
    required int newLevel,
    required int totalXp,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'level_up',
        parameters: <String, Object>{
          'old_level': oldLevel,
          'new_level': newLevel,
          'total_xp': totalXp,
        },
      );
      debugPrint('[Analytics] level_up: $oldLevel → $newLevel');
    } catch (e) {
      debugPrint('[Analytics] Erro em level_up: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  BADGE DESBLOQUEADO
  // ─────────────────────────────────────────────────────────────────

  Future<void> logBadgeUnlocked({
    required String badgeId,
    required String source,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'badge_unlocked',
        parameters: <String, Object>{
          'badge_id': badgeId,
          'source': source,
        },
      );
      debugPrint('[Analytics] badge_unlocked: $badgeId via $source');
    } catch (e) {
      debugPrint('[Analytics] Erro em badge_unlocked: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  MISSÃO DIÁRIA CONCLUÍDA
  // ─────────────────────────────────────────────────────────────────

  Future<void> logDailyMissionCompleted({int spGranted = 50}) async {
    try {
      await _analytics.logEvent(
        name: 'daily_mission_done',
        parameters: <String, Object>{'sp_granted': spGranted},
      );
      debugPrint('[Analytics] daily_mission_done | sp=$spGranted');
    } catch (e) {
      debugPrint('[Analytics] Erro em daily_mission_done: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  DESAFIO SEMANAL CONCLUÍDO
  // ─────────────────────────────────────────────────────────────────

  Future<void> logWeeklyMissionCompleted({
    required int streak,
    int xpGranted = 100,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'weekly_mission_done',
        parameters: <String, Object>{
          'streak': streak,
          'xp_granted': xpGranted,
        },
      );
      debugPrint('[Analytics] weekly_mission_done | streak=$streak');
    } catch (e) {
      debugPrint('[Analytics] Erro em weekly_mission_done: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  STREAK ATUALIZADO
  // ─────────────────────────────────────────────────────────────────

  Future<void> logStreakUpdated({required int newStreak}) async {
    try {
      await _analytics.logEvent(
        name: 'streak_updated',
        parameters: <String, Object>{'streak': newStreak},
      );
    } catch (e) {
      debugPrint('[Analytics] Erro em streak_updated: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  EVENTOS PADRÃO GA4 (login / sign_up)
  // ─────────────────────────────────────────────────────────────────

  Future<void> logLogin({String method = 'email'}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('[Analytics] Erro em login: $e');
    }
  }

  Future<void> logSignUp({String method = 'email'}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('[Analytics] Erro em sign_up: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  USER PROPERTY — define propriedades persistentes
  // ─────────────────────────────────────────────────────────────────

  /// Define o nível do usuário como user property para segmentação no GA4.
  Future<void> setUserLevel(int level) async {
    try {
      await _analytics.setUserProperty(name: 'user_level', value: '$level');
    } catch (e) {
      debugPrint('[Analytics] Erro em setUserLevel: $e');
    }
  }

  /// Define a role do usuário (Técnico, Engenheiro, etc.).
  Future<void> setUserRole(String role) async {
    try {
      await _analytics.setUserProperty(name: 'user_role', value: role);
    } catch (e) {
      debugPrint('[Analytics] Erro em setUserRole: $e');
    }
  }

  /// Habilita / desabilita coleta (LGPD/opt-out).
  Future<void> setCollectionEnabled({bool enabled = true}) async {
    await _analytics.setAnalyticsCollectionEnabled(enabled);
  }
}
