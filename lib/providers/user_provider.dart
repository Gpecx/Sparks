import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spark_app/models/user_model.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/models/progress_model.dart';
import 'package:spark_app/services/progress_service.dart';
import 'package:spark_app/services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────
//  USER PROVIDER — Riverpod 3.x
//  Usa StreamProvider para reatividade nativa com o Firestore.
// ─────────────────────────────────────────────────────────────────

/// Provider do UserService (singleton).
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

/// Provider do usuário atual (stream do Firebase Auth).
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider reativo do UserModel via stream direto do Firestore.
/// Esta é a abordagem correta no Riverpod 3.x — usa StreamProvider
/// para garantir que a UI seja reconstruída a cada mudança no documento.
final userModelProvider = StreamProvider<UserModel?>((ref) {
  final auth = ref.watch(authStateProvider);
  final uid = auth.value?.uid;

  if (uid == null) return Stream.value(null);

  return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? UserModel.fromFirestore(snap) : null);
});

/// Provider reativo do NotificationService.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  final auth = ref.watch(authStateProvider);
  final uid = auth.value?.uid;
  if (uid != null) {
    service.startListening(uid);
  } else {
    service.stopListening();
  }
  ref.onDispose(() => service.dispose());
  return service;
});
/// Provider para verificar se o usuário está logado.
final isLoggedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

/// Provider para o progresso do último módulo ativo.
/// Busca da subcoleção users/{uid}/progress via ProgressService.
final lastActiveModuleProvider = FutureProvider<ProgressModel?>((ref) async {
  final auth = ref.watch(authStateProvider);
  final uid = auth.value?.uid;
  if (uid == null) return null;

  final allProgress = await ProgressService().getAllProgress(uid);
  if (allProgress.isEmpty) return null;

  final incomplete = allProgress
      .where((p) => !p.isCompleted)
      .toList()
    ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

  return incomplete.isNotEmpty ? incomplete.first : allProgress.last;
});

/// Provider para o ranking global semanal.
final globalRankingProvider = FutureProvider<List<RankingEntry>>((ref) async {
  final userService = ref.read(userServiceProvider);
  return await userService.getGlobalWeeklyRanking();
});

/// Provider para o ranking do clã.
final clanRankingProvider = FutureProvider<List<RankingEntry>>((ref) async {
  final userService = ref.read(userServiceProvider);
  return await userService.getClanWeeklyRanking();
});

/// Provider para o ranking all-time.
final allTimeRankingProvider = FutureProvider<List<RankingEntry>>((ref) async {
  final userService = ref.read(userServiceProvider);
  return await userService.getAllTimeRanking();
});