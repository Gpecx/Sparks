import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/services/analytics_service.dart';
import 'package:spark_app/services/firebase_service.dart';

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

      // FIX: Caso o cadastro tenha sido interrompido (app fechado no meio), 
      // garante que o documento seja criado para não mostrar 'Usuário'.
      final user = credential.user;
      if (user != null) {
        final docRef = _firestore.collection('users').doc(user.uid);
        
        try {
          // Timeout de 3s para não travar o login se o firestore estiver lento
          final docSnap = await docRef.get().timeout(const Duration(seconds: 3));
          
          if (!docSnap.exists) {
            await docRef.set({
              'uid': user.uid,
              'displayName': user.displayName ?? 'Usuário',
              'email': user.email ?? email,
              'photoUrl': user.photoURL,
              'role': 'Técnico',
              'sparkPoints': 100,
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
            }).timeout(const Duration(seconds: 3));
          }
        } catch (e) {
          // Ignora o erro se der timeout ou falhar a rede, para permitir o login continuar
          print('Aviso: Falha ao verificar/criar doc do usuário no login: \$e');
        }
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
        'role': 'Técnico',
        'sparkPoints': 100, // Bônus de boas-vindas
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


  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
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
