import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────
//  AUDIT SERVICE
//
//  Registra eventos de mudança em users/{uid}/audit_log.
//  Cada documento segue o schema:
//    {
//      action    : String  — ex: 'xp_gained', 'lesson_completed', 'level_up'
//      amount    : int     — valor numérico da ação (XP, SP, etc.)
//      source    : String  — origem: 'lesson', 'badge', 'daily_mission', etc.
//      meta      : Map?    — dados extras opcionais (moduleId, lessonId...)
//      createdAt : Timestamp (serverTimestamp)
//    }
//
//  Uso:
//    await AuditService().log(action: 'xp_gained', amount: 50, source: 'lesson');
// ─────────────────────────────────────────────────────────────────

/// Constantes de ação para evitar strings avulsas no código.
abstract class AuditAction {
  static const String xpGained = 'xp_gained';
  static const String spGained = 'sp_gained';
  static const String spSpent = 'sp_spent';
  static const String lessonCompleted = 'lesson_completed';
  static const String levelUp = 'level_up';
  static const String badgeUnlocked = 'badge_unlocked';
  static const String streakUpdated = 'streak_updated';
  static const String streakReset = 'streak_reset';
  static const String streakResurrected = 'streak_resurrected';
  static const String dailyMissionCompleted = 'daily_mission_completed';
  static const String weeklyMissionCompleted = 'weekly_mission_completed';
  static const String xpIntegrityFixed = 'xp_integrity_fixed';
}

class AuditService {
  // ── Singleton ──────────────────────────────────────────────────
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // ─────────────────────────────────────────────────────────────────
  //  LOG
  // ─────────────────────────────────────────────────────────────────

  /// Registra um evento no audit log do usuário atual.
  ///
  /// [action]  — tipo da ação (use [AuditAction] constants)
  /// [amount]  — valor numérico (XP, SP, nível, etc.)
  /// [source]  — origem da ação ('lesson', 'badge', 'offline_sync', etc.)
  /// [meta]    — dados extras opcionais
  Future<void> log({
    required String action,
    required int amount,
    required String source,
    Map<String, dynamic>? meta,
  }) async {
    if (_uid.isEmpty) return;

    try {
      final entry = <String, dynamic>{
        'action': action,
        'amount': amount,
        'source': source,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (meta != null && meta.isNotEmpty) {
        entry['meta'] = meta;
      }

      await _db
          .collection('users')
          .doc(_uid)
          .collection('audit_log')
          .add(entry);

      debugPrint('[Audit] $action | amount=$amount | source=$source');
    } catch (e) {
      // Audit log não deve quebrar o fluxo principal
      debugPrint('[Audit] Erro ao gravar log: $e');
    }
  }

  /// Versão para uid externo (ex: chamada do OfflineSyncService).
  Future<void> logForUser({
    required String uid,
    required String action,
    required int amount,
    required String source,
    Map<String, dynamic>? meta,
  }) async {
    if (uid.isEmpty) return;

    try {
      final entry = <String, dynamic>{
        'action': action,
        'amount': amount,
        'source': source,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (meta != null && meta.isNotEmpty) {
        entry['meta'] = meta;
      }

      await _db
          .collection('users')
          .doc(uid)
          .collection('audit_log')
          .add(entry);
    } catch (e) {
      debugPrint('[Audit] Erro ao gravar log para $uid: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  LEITURA (diagnóstico/admin)
  // ─────────────────────────────────────────────────────────────────

  /// Retorna os últimos [limit] registros do audit log do usuário.
  Future<List<Map<String, dynamic>>> getRecentLogs({int limit = 20}) async {
    if (_uid.isEmpty) return [];

    try {
      final snap = await _db
          .collection('users')
          .doc(_uid)
          .collection('audit_log')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('[Audit] Erro ao ler logs: $e');
      return [];
    }
  }
}
