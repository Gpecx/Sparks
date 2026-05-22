import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/fs.dart';
import '../models/progress_model.dart';
import '../services/achievement_service.dart';
import '../services/analytics_service.dart';
import '../services/audit_service.dart';
import '../services/gamification_service.dart';
import '../services/offline_sync_service.dart';
import '../data/lessons_registry.dart';

class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  Future<ProgressModel?> getProgress(String uid, String moduleId) async {
    final snap = await _fs.collection(FS.users).doc(uid)
        .collection(FS.progress).where(FS.moduleId, isEqualTo: moduleId).limit(1).get();
        
    if (snap.docs.isEmpty) return null;
    return ProgressModel.fromFirestore(snap.docs.first);
  }

  Future<List<ProgressModel>> getAllProgress(String uid) async {
    final snap = await _fs.collection(FS.users).doc(uid).collection(FS.progress).get();
    return snap.docs.map((d) => ProgressModel.fromFirestore(d)).toList();
  }

  /// Marca uma lição como completa e sincroniza com o Firestore.
  /// 
  /// IMPORTANTE: Esta função agora:
  /// 1. Sincroniza o progresso da lição (completedLessons, progressPercent)
  /// 2. NÃO tenta atualizar XP/SP diretamente (campos sensíveis protegidos)
  /// 3. Delega XP/SP para Cloud Functions via UserService
  /// 4. Funciona offline enfileirando operações
  Future<void> markLessonComplete(
    String uid,
    String catId,
    String modId,
    String lessonId,
    int xpEarned,
    int spEarned, {
    String moduleName = '',
    String? trailId,
  }) async {
    try {
      debugPrint('[ProgressService] Marcando lição como completa: $lessonId');

      // Se offline, delega ao OfflineSyncService e retorna
      if (!OfflineSyncService().isOnline) {
        debugPrint('[ProgressService] Offline detectado - enfileirando operação');
        await OfflineSyncService().enqueueMarkLesson(
          uid: uid,
          catId: catId,
          modId: modId,
          lessonId: lessonId,
          xpEarned: xpEarned,
          spEarned: spEarned,
          moduleName: moduleName,
        );
        return;
      }

      final userRef = _fs.collection(FS.users).doc(uid);
      
      // Tenta buscar do cache primeiro para não depender da rede.
      QuerySnapshot<Map<String, dynamic>>? progSnap;
      try {
        progSnap = await userRef.collection(FS.progress)
            .where(FS.moduleId, isEqualTo: modId).limit(1)
            .get(const GetOptions(source: Source.cache));
      } catch (_) {
        debugPrint('[ProgressService] Cache vazio, tentando rede');
      }
      
      // Se ainda vazio, tenta da rede com timeout
      if (progSnap == null || progSnap.docs.isEmpty) {
        try {
          progSnap = await userRef.collection(FS.progress)
              .where(FS.moduleId, isEqualTo: modId).limit(1)
              .get().timeout(const Duration(milliseconds: 1500));
        } catch (e) {
          debugPrint('[ProgressService] Timeout ao buscar progresso: $e');
        }
      }

      final batch = _fs.batch();
      
      DocumentReference pRef;
      if (progSnap != null && progSnap.docs.isNotEmpty) {
        pRef = progSnap.docs.first.reference;
        debugPrint('[ProgressService] Progresso encontrado: ${pRef.id}');
      } else {
        // Se não conseguimos ler o progresso, usamos modId como ID
        pRef = userRef.collection(FS.progress).doc(modId);
        debugPrint('[ProgressService] Criando novo documento de progresso: ${pRef.id}');
        batch.set(pRef, {
          FS.moduleId: modId,
          FS.categoryId: catId,
          'moduleName': moduleName,
          FS.completedLessons: [],
          FS.progressPercent: 0.0,
          FS.isCompleted: false,
          FS.startedAt: FieldValue.serverTimestamp(),
          FS.lastAccessed: FieldValue.serverTimestamp(),
          FS.bestScore: 0,
          FS.attempts: 0,
        }, SetOptions(merge: true));
      }

      // Calcula localmente o progresso baseado no que sabemos
      List<String> alreadyCompleted = [];
      int knownTotal = 0;
      if (progSnap != null && progSnap.docs.isNotEmpty) {
        final existingData = progSnap.docs.first.data();
        alreadyCompleted = List<String>.from(existingData[FS.completedLessons] ?? []);
        knownTotal = (existingData['totalLessons'] as int?) ?? 0;
      }
      
      final completedSet = {...alreadyCompleted, lessonId};
      int totalLessons = getLessonsForModule(modId).length;
      if (totalLessons == 0) totalLessons = knownTotal;
      if (totalLessons == 0) totalLessons = completedSet.length;

      final double updatedProgress = (completedSet.length / totalLessons).clamp(0.0, 1.0);
      final bool moduleCompleted = updatedProgress >= 1.0;

      debugPrint('[ProgressService] Progresso: ${(updatedProgress * 100).toStringAsFixed(1)}% ($completedSet.length/$totalLessons)');

      // ✅ CORREÇÃO: Apenas atualiza progresso, não XP/SP
      batch.set(pRef, {
        FS.completedLessons: FieldValue.arrayUnion([lessonId]),
        FS.lastAccessed: FieldValue.serverTimestamp(),
        FS.progressPercent: double.parse(updatedProgress.toStringAsFixed(2)),
        FS.isCompleted: moduleCompleted,
        if (moduleName.isNotEmpty) 'moduleName': moduleName,
        if (moduleCompleted) FS.completedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ CORREÇÃO: Apenas incrementa totalLessonsCompleted (campo não-sensível)
      batch.set(userRef, {
        FS.totalLessonsCompleted: FieldValue.increment(1),
        FS.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ IMPORTANTE: Aguarda o batch.commit() explicitamente
      try {
        await batch.commit();
        debugPrint('[ProgressService] ✓ Batch sincronizado com sucesso');
      } catch (e) {
        debugPrint('[ProgressService] ✗ Erro ao sincronizar batch: $e');
        // Se falhar, enfileira para tentar depois
        await OfflineSyncService().enqueueMarkLesson(
          uid: uid,
          catId: catId,
          modId: modId,
          lessonId: lessonId,
          xpEarned: xpEarned,
          spEarned: spEarned,
          moduleName: moduleName,
        );
        rethrow;
      }

      // ⚠️ IMPORTANTE: XP e Spark Points devem ser sincronizados separadamente
      // via UserService.addXp() e UserService.addSparkPoints()
      debugPrint('[ProgressService] ⚠️ XP ($xpEarned) e SP ($spEarned) devem ser sincronizados via Cloud Functions');

      // Audit log (sem await para não bloquear UI)
      Future.microtask(() async {
        try {
          await AuditService().logForUser(
            uid: uid,
            action: AuditAction.lessonCompleted,
            amount: xpEarned,
            source: 'lesson',
            meta: {
              'moduleId': modId,
              'categoryId': catId,
              'lessonId': lessonId,
              'spEarned': spEarned,
              'moduleCompleted': moduleCompleted,
            },
          );
        } catch (e) {
          debugPrint('[ProgressService] Erro ao registrar audit log: $e');
        }
      });

      // Analytics — lesson_completed (sem await)
      Future.microtask(() async {
        try {
          await AnalyticsService().logLessonCompleted(
            moduleId: modId,
            lessonId: lessonId,
            categoryId: catId,
            xpEarned: xpEarned,
            spEarned: spEarned,
          );
        } catch (e) {
          debugPrint('[ProgressService] Erro ao registrar analytics: $e');
        }
      });

      // Achievements baseados em quantidade de lições (sem await)
      Future.microtask(() async {
        try {
          final totalLessonsCompletedSoFar = completedSet.length;
          await AchievementService().checkLessonAchievements(uid, totalLessonsCompletedSoFar);
        } catch (e) {
          debugPrint('[ProgressService] Erro ao verificar achievements: $e');
        }
      });

      // Missão diária — 3 lições = daily_warrior + 50 SP (sem await)
      Future.microtask(() async {
        try {
          await GamificationService().onLessonCompleted(uid);
        } catch (e) {
          debugPrint('[ProgressService] Erro ao processar gamificação: $e');
        }
      });

    } catch (e) {
      debugPrint('[ProgressService] ✗ Erro ao marcar lição como completa: $e');
      rethrow;
    }
  }

  Future<bool> isModuleUnlocked(String uid, String requiredModuleId) async {
    final progress = await getProgress(uid, requiredModuleId);
    return progress?.isCompleted ?? false;
  }

  Future<void> saveBestScore(String uid, String modId, int score) async {
    try {
      final p = await getProgress(uid, modId);
      if (p != null && score > p.bestScore) {
        await _fs.collection(FS.users).doc(uid).collection(FS.progress).doc(p.id).update({
          FS.bestScore: score,
          FS.lastAccessed: FieldValue.serverTimestamp(),
        });
        debugPrint('[ProgressService] ✓ Melhor score salvo: $score');
      }
    } catch (e) {
      debugPrint('[ProgressService] ✗ Erro ao salvar melhor score: $e');
    }
  }
}
