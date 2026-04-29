import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/models/user_model.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/models/progress_model.dart';
import 'package:spark_app/services/progress_service.dart';

// ─────────────────────────────────────────────────────────────────
//  USER PROVIDER — Riverpod
//  Expõe o UserService para toda a árvore de widgets.
// ─────────────────────────────────────────────────────────────────

/// Provider do UserService (singleton).
/// Emulando a reatividade antiga do ChangeNotifierProvider no Riverpod 3.0.
final userServiceProvider = Provider<UserService>((ref) {
  final service = UserService();
  
  // Força o provider a notificar seus ouvintes quando o Singleton emitir evento
  void listener() => ref.invalidateSelf();
  service.addListener(listener);
  
  ref.onDispose(() => service.removeListener(listener));
  
  return service;
});

/// Provider do usuário atual (stream do Firebase Auth).
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider do UserModel (reativo ao stream do Firestore).
final userModelProvider = Provider<UserModel?>((ref) {
  final userService = ref.watch(userServiceProvider);
  return userService.user;
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

  // Retorna o módulo mais recentemente acessado que não esteja 100% completo
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