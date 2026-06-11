import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/progress_model.dart';
import '../core/constants/fs.dart';


/// Representa uma atualização de progresso otimista em memória.
class OptimisticProgress {
  final String categoryId;
  final String moduleId;
  final String lessonId;
  final String moduleName;

  const OptimisticProgress({
    required this.categoryId,
    required this.moduleId,
    required this.lessonId,
    this.moduleName = '',
  });
}

/// Notifier que gerencia os progressos otimistas locais e temporários.
class OptimisticProgressNotifier extends Notifier<List<OptimisticProgress>> {
  @override
  List<OptimisticProgress> build() => [];

  void addOptimisticProgress(OptimisticProgress progress) {
    // Evita duplicatas locais idênticas
    final exists = state.any((p) => p.moduleId == progress.moduleId && p.lessonId == progress.lessonId);
    if (!exists) {
      state = [...state, progress];
    }
  }

  void removeOptimisticProgress(String moduleId, String lessonId) {
    state = state.where((p) => !(p.moduleId == moduleId && p.lessonId == lessonId)).toList();
  }
}

/// Provedor do estado otimista temporário.
final optimisticProgressProvider =
    NotifierProvider<OptimisticProgressNotifier, List<OptimisticProgress>>(() {
  return OptimisticProgressNotifier();
});

/// Stream puro vindo direto do Firestore (sem atualizações otimistas da UI).
final rawProgressProvider = StreamProvider<List<ProgressModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
      .collection(FS.users)
      .doc(uid)
      .collection(FS.progress)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ProgressModel.fromFirestore(doc))
          .toList());
});

/// Provedor principal exposto para a UI que combina progresso real (Firestore) + otimista.
final userProgressProvider = Provider<AsyncValue<List<ProgressModel>>>((ref) {
  final rawAsync = ref.watch(rawProgressProvider);
  final optimisticList = ref.watch(optimisticProgressProvider);

  return rawAsync.when(
    data: (rawList) {
      if (optimisticList.isEmpty) return AsyncValue.data(rawList);

      // Cria um mapa mutável baseado no progresso bruto
      final Map<String, ProgressModel> mergedMap = {
        for (var p in rawList) p.moduleId: p
      };

      for (final opt in optimisticList) {
        final existing = mergedMap[opt.moduleId];
        if (existing != null) {
          if (!existing.completedLessons.contains(opt.lessonId)) {
            final updatedLessons = <String>[...existing.completedLessons, opt.lessonId];
            final progressPercent = existing.progressPercent;
            final isCompleted = progressPercent >= 1.0;

            mergedMap[opt.moduleId] = ProgressModel(
              id: existing.id,
              moduleId: existing.moduleId,
              categoryId: existing.categoryId,
              moduleName: existing.moduleName,
              completedLessons: updatedLessons,
              progressPercent: progressPercent,
              isCompleted: isCompleted,
              startedAt: existing.startedAt,
              completedAt: isCompleted ? DateTime.now() : existing.completedAt,
              lastAccessed: DateTime.now(),
              bestScore: existing.bestScore,
              attempts: existing.attempts,
            );
          }
        } else {
          // Novo progresso iniciado localmente
          final updatedLessons = <String>[opt.lessonId];
          const progressPercent = 0.0;
          final isCompleted = progressPercent >= 1.0;

          mergedMap[opt.moduleId] = ProgressModel(
            id: opt.moduleId,
            moduleId: opt.moduleId,
            categoryId: opt.categoryId,
            moduleName: opt.moduleName,
            completedLessons: updatedLessons,
            progressPercent: progressPercent,
            isCompleted: isCompleted,
            startedAt: DateTime.now(),
            completedAt: isCompleted ? DateTime.now() : null,
            lastAccessed: DateTime.now(),
            bestScore: 0,
            attempts: 0,
          );
        }
      }

      return AsyncValue.data(mergedMap.values.toList());
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});
