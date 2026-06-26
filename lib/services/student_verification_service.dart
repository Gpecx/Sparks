import 'package:cloud_functions/cloud_functions.dart';

/// Serviço admin das Cloud Functions de verificação de estudante:
/// listar solicitações e aprovar/rejeitar a matrícula.
class StudentVerificationService {
  StudentVerificationService._();
  static final StudentVerificationService instance =
      StudentVerificationService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  /// [admin] Lista as solicitações de verificação (mais recentes primeiro).
  Future<List<Map<String, dynamic>>> list() async {
    try {
      final callable = _functions.httpsCallable('listStudentVerifications');
      final res = await callable.call<Map<String, dynamic>>({});
      return (res.data['verifications'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw StudentVerificationException(_messageFor(e));
    }
  }

  /// [admin] Aprova a verificação do [uid] — concede o acesso ao plano Student.
  Future<void> approve(String uid) => _review(uid, 'approve');

  /// [admin] Rejeita a verificação do [uid].
  Future<void> reject(String uid) => _review(uid, 'reject');

  Future<void> _review(String uid, String decision) async {
    try {
      final callable = _functions.httpsCallable('reviewStudentVerification');
      await callable.call<Map<String, dynamic>>({
        'uid': uid,
        'decision': decision,
      });
    } on FirebaseFunctionsException catch (e) {
      throw StudentVerificationException(_messageFor(e));
    }
  }

  String _messageFor(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Você não tem permissão para esta ação.';
      case 'unauthenticated':
        return 'Faça login para continuar.';
      case 'not-found':
        return 'Solicitação não encontrada.';
      case 'invalid-argument':
        return e.message ?? 'Dados inválidos.';
      case 'resource-exhausted':
        return 'Muitas tentativas. Tente novamente em instantes.';
      default:
        return e.message ?? 'Erro ao processar a verificação.';
    }
  }
}

/// Exceção com mensagem pronta para exibir ao usuário.
class StudentVerificationException implements Exception {
  final String message;
  StudentVerificationException(this.message);
  @override
  String toString() => message;
}
