import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/services/firebase_service.dart';

class AuthService {
  final _auth = FirebaseService.instance.auth;
  final _firestore = FirebaseService.instance.firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
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

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'uid': credential.user!.uid,
        'name': name.trim(),
        'email': email.trim(),
        'profession': profession.trim(),
        'photoUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'sparkPoints': 0,
        'xp': 0,
        'energy': 25,
        'energyLastRegen': FieldValue.serverTimestamp(),
        'streak': 0,
        'longestStreak': 0,
        'lastLoginDate': FieldValue.serverTimestamp(),
        'isPremium': false,
        'tensionLevel': 'BT',
        'role': 'member',
        'clanId': null,
        'totalLessonsCompleted': 0,
        'totalCorrectAnswers': 0,
        'totalAnswers': 0,
        'badges': [],
        'weeklyXp': 0,
        'monthlyXp': 0,
      });

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
