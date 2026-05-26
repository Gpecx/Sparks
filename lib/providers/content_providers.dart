import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/core/constants/fs.dart';
import 'package:spark_app/models/spark_admin_models.dart';

final _firestoreProvider = Provider((ref) => FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default'));

// ── 1. Categorias ───────────────────────────────────────────────────────────
final categoriesStreamProvider = StreamProvider<List<SPARKCategory>>((ref) {
  final firestore = ref.watch(_firestoreProvider);
  return firestore
      .collection(FS.categories)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => SPARKCategory.fromFirestore(d)).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });
});

// ── 2. Módulos ──────────────────────────────────────────────────────────────
final modulesStreamProvider =
    StreamProvider.family<List<SPARKModule>, String>((ref, categoryId) {
  final firestore = ref.watch(_firestoreProvider);
  return firestore
      .collection(FS.categories)
      .doc(categoryId)
      .collection(FS.modules)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => SPARKModule.fromFirestore(d)).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });
});

// ── 3. Trilhas ──────────────────────────────────────────────────────────────
typedef TrailArgs = ({String categoryId, String moduleId});

final trailsStreamProvider =
    StreamProvider.family<List<SPARKTrail>, TrailArgs>((ref, args) {
  final firestore = ref.watch(_firestoreProvider);
  return firestore
      .collection(FS.categories)
      .doc(args.categoryId)
      .collection(FS.modules)
      .doc(args.moduleId)
      .collection(FS.trails)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => SPARKTrail.fromFirestore(d)).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });
});

// ── 4. Lições ───────────────────────────────────────────────────────────────
typedef LessonArgs = ({String categoryId, String moduleId, String trailId});

final lessonsStreamProvider =
    StreamProvider.family<List<SPARKLesson>, LessonArgs>((ref, args) {
  final firestore = ref.watch(_firestoreProvider);
  return firestore
      .collection(FS.categories)
      .doc(args.categoryId)
      .collection(FS.modules)
      .doc(args.moduleId)
      .collection(FS.trails)
      .doc(args.trailId)
      .collection(FS.lessons)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => SPARKLesson.fromFirestore(d)).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });
});

// ── 5. Todas as Lições de um Módulo (Achatadas) ─────────────────────────────
final moduleLessonsProvider = Provider.family<AsyncValue<List<SPARKLesson>>, TrailArgs>((ref, args) {
  final trailsAsync = ref.watch(trailsStreamProvider(args));
  
  return trailsAsync.when(
    data: (trails) {
      List<SPARKLesson> allLessons = [];
      bool isLoading = false;
      bool hasError = false;
      Object? error;
      StackTrace? stack;

      for (final trail in trails) {
        final lessonsAsync = ref.watch(lessonsStreamProvider((
          categoryId: args.categoryId,
          moduleId: args.moduleId,
          trailId: trail.id,
        )));

        lessonsAsync.when(
          data: (lessons) => allLessons.addAll(lessons),
          loading: () => isLoading = true,
          error: (e, s) {
            hasError = true;
            error = e;
            stack = s;
          },
        );
      }

      if (hasError) return AsyncError(error!, stack!);
      if (isLoading) return const AsyncLoading();
      
      return AsyncData(allLessons);
    },
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
  );
});

// ── 6. Módulos em Destaque ──────────────────────────────────────────────────
final topModulesStreamProvider = Provider<AsyncValue<List<SPARKModule>>>((ref) {
  final categoriesAsync = ref.watch(categoriesStreamProvider);

  return categoriesAsync.when(
    data: (categories) {
      final List<SPARKModule> allModules = [];
      bool isLoading = false;
      bool hasError = false;
      Object? error;
      StackTrace? stack;

      for (final cat in categories) {
        final modulesAsync = ref.watch(modulesStreamProvider(cat.id));
        modulesAsync.when(
          data: (modules) => allModules.addAll(modules),
          loading: () => isLoading = true,
          error: (e, s) {
            hasError = true;
            error = e;
            stack = s;
          },
        );
      }

      if (hasError) return AsyncError(error!, stack!);
      if (isLoading) return const AsyncLoading();

      // Ordenar por accessCount decrescente em memória e extrair os 5 principais
      allModules.sort((a, b) => b.accessCount.compareTo(a.accessCount));
      return AsyncData(allModules.take(5).toList());
    },
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
  );
});
