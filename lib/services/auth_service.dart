import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:spark_app/services/analytics_service.dart';
import 'package:spark_app/services/firebase_service.dart';

/// Lançada quando o usuário fecha/cancela o popup de login do Google.
/// Não é um erro — a UI deve apenas ignorar silenciosamente.
class GoogleSignInCancelled implements Exception {}

class AuthService {
  final _auth = FirebaseService.instance.auth;
  final _firestore = FirebaseService.instance.firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Verifica/cria doc do usuário em background — não bloqueia o login
      final user = credential.user;
      if (user != null) {
        Future.microtask(() async {
          try {
            final docRef = _firestore.collection('users').doc(user.uid);
            final docSnap = await docRef.get().timeout(const Duration(seconds: 5));
            if (!docSnap.exists) {
              await docRef.set({
                'uid': user.uid,
                'displayName': user.displayName ?? 'Usuário',
                'email': user.email ?? email,
                'photoUrl': user.photoURL,
                'role': 'técnico',
                'xp': 0,
                'level': 1,
                'tensionLevel': 'BT',
                'currentStreak': 0,
                'longestStreak': 0,
                'activeDays': 0,
                'studiedToday': false,
                'lastStudyDate': null,
                'weeklyXp': 0,
                'monthlyXp': 0,
                'unlockedBadgeIds': [],
                'clanId': null,
                'clanName': null,
                'totalLessonsCompleted': 0,
                'totalCorrectAnswers': 0,
                'totalAnswers': 0,
                'eloRating': 1200,
                'wins': 0,
                'losses': 0,
                'totalDuels': 0,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }).timeout(const Duration(seconds: 5));
            }
          } catch (e) {
            debugPrint('Aviso: Falha ao verificar/criar doc do usuário no login: $e');
          }
        });
      }

      // Analytics
      await AnalyticsService().logLogin();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String name,
    String profession,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      await credential.user!.updateDisplayName(name.trim());

      // Esquema exato do UserModel — única fonte de verdade
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'displayName': name.trim(),
        'email': email.trim(),
        'photoUrl': null,
        'role': 'técnico',
        'xp': 0,
        'level': 1,
        'tensionLevel': 'BT',
        'currentStreak': 0,
        'longestStreak': 0,
        'activeDays': 0,
        'studiedToday': false,
        'lastStudyDate': null,
        'weeklyXp': 0,
        'monthlyXp': 0,
        'unlockedBadgeIds': [],
        'clanId': null,
        'clanName': null,
        'totalLessonsCompleted': 0,
        'totalCorrectAnswers': 0,
        'totalAnswers': 0,
        'eloRating': 1200,
        'wins': 0,
        'losses': 0,
        'totalDuels': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Analytics
      await AnalyticsService().logSignUp();

      return credential;

    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Login/cadastro com a conta Google.
  ///
  /// Funciona tanto na web (popup) quanto em mobile/desktop (fluxo nativo do
  /// provedor OAuth via `signInWithProvider`) usando apenas o `firebase_auth`.
  /// Se for a primeira vez do usuário, cria o documento dele no Firestore.
  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});

      final UserCredential credential = kIsWeb
          ? await _auth.signInWithPopup(googleProvider)
          : await _auth.signInWithProvider(googleProvider);

      final user = credential.user;
      if (user != null) {
        await _ensureUserDoc(user);
      }

      // Analytics — distingue primeiro cadastro de login recorrente
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
      if (isNewUser) {
        await AnalyticsService().logSignUp();
      } else {
        await AnalyticsService().logLogin();
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      // Cancelamento pelo usuário não é um erro — propaga como sinal silencioso.
      const cancelCodes = {
        'popup-closed-by-user',
        'cancelled-popup-request',
        'user-cancelled',
        'web-context-canceled',
      };
      if (cancelCodes.contains(e.code)) {
        throw GoogleSignInCancelled();
      }
      throw _mapAuthException(e);
    }
  }

  /// Garante que exista um documento em `users/{uid}` para o usuário.
  /// Usado pelo login com Google, onde não há um cadastro prévio explícito.
  Future<void> _ensureUserDoc(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final docSnap = await docRef.get().timeout(const Duration(seconds: 5));
      if (!docSnap.exists) {
        await docRef
            .set(_defaultUserData(
              uid: user.uid,
              displayName: user.displayName ?? 'Usuário',
              email: user.email ?? '',
              photoUrl: user.photoURL,
            ))
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('Aviso: falha ao verificar/criar doc do usuário (Google): $e');
    }
  }

  /// Esquema padrão do UserModel para um novo usuário — única fonte de verdade.
  Map<String, dynamic> _defaultUserData({
    required String uid,
    required String displayName,
    required String email,
    String? photoUrl,
  }) =>
      {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'role': 'técnico',
        'xp': 0,
        'level': 1,
        'tensionLevel': 'BT',
        'currentStreak': 0,
        'longestStreak': 0,
        'activeDays': 0,
        'studiedToday': false,
        'lastStudyDate': null,
        'weeklyXp': 0,
        'monthlyXp': 0,
        'unlockedBadgeIds': [],
        'clanId': null,
        'clanName': null,
        'totalLessonsCompleted': 0,
        'totalCorrectAnswers': 0,
        'totalAnswers': 0,
        'eloRating': 1200,
        'wins': 0,
        'losses': 0,
        'totalDuels': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };


  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Exclui PERMANENTEMENTE a conta do usuário e todos os dados associados.
  ///
  /// Chama a Cloud Function `deleteAccount`, que (via Admin SDK) apaga:
  /// ranking de todas as semanas, vínculo/clã, public_profiles, o documento
  /// users/{uid} com subcoleções e o próprio usuário do Firebase Auth.
  /// Como o usuário do Auth é removido no servidor, não é necessário
  /// reautenticar no cliente. Ao final, encerra a sessão local.
  Future<void> deleteAccount() async {
    final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
    await fn.httpsCallable('deleteAccount').call();
    // O usuário do Auth já não existe no servidor; limpa a sessão local.
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// Verifica via Cloud Function se [deviceId] é confiável e ainda não expirou.
  /// Usa Admin SDK no backend, evitando bloqueio por Security Rules client-side.
  Future<bool> checkDeviceVerification(String uid, String deviceId) async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('checkDeviceTrust').call({'deviceId': deviceId});
      final data = result.data as Map<dynamic, dynamic>;
      return data['trusted'] == true;
    } catch (e) {
      debugPrint('Aviso: falha ao checar dispositivo confiável: $e');
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  Exception _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return Exception('E-mail inválido.');
      case 'user-disabled':
        return Exception('Conta desativada. Contate o suporte.');
      case 'user-not-found':
        return Exception('Nenhuma conta encontrada com esse e-mail.');
      case 'wrong-password':
        return Exception('Senha incorreta.');
      case 'email-already-in-use':
        return Exception('E-mail já cadastrado.');
      case 'account-exists-with-different-credential':
        return Exception('Já existe uma conta com este e-mail usando outro método de login. Entre com e-mail e senha.');
      case 'operation-not-allowed':
        return Exception('Operação não permitida.');
      case 'weak-password':
        return Exception('Senha fraca. Use ao menos 6 caracteres.');
      case 'too-many-requests':
        return Exception('Muitas tentativas. Tente novamente mais tarde.');
      case 'network-request-failed':
        return Exception('Sem conexão. Verifique sua internet.');
      default:
        return Exception(e.message ?? 'Erro de autenticação desconhecido.');
    }
  }
}
