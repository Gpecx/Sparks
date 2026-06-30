import 'package:cloud_functions/cloud_functions.dart';

/// Serviço das Cloud Functions de verificação de estudante:
/// fluxo OTP por e-mail institucional (usuário) e gestão (admin).
class StudentVerificationService {
  StudentVerificationService._();
  static final StudentVerificationService instance =
      StudentVerificationService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  /// [usuário] Envia um código OTP ao e-mail institucional informado.
  /// Lança [StudentVerificationException] se o domínio não for elegível
  /// (failed-precondition) ou em outras falhas.
  Future<void> sendOtp({
    required String institutionalEmail,
    String? institution,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'sendStudentVerificationCode',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      await callable.call<Map<String, dynamic>>({
        'institutionalEmail': institutionalEmail,
        if (institution != null && institution.isNotEmpty) 'institution': institution,
      });
    } on FirebaseFunctionsException catch (e) {
      throw StudentVerificationException(_messageFor(e));
    }
  }

  /// [usuário] Confirma o código OTP. Em caso de código errado/expirado,
  /// lança [StudentVerificationException] com a mensagem do servidor.
  Future<void> verifyOtp(String code) async {
    try {
      final callable = _functions.httpsCallable('verifyStudentVerificationCode');
      final res = await callable.call<Map<String, dynamic>>({'code': code});
      final ok = res.data['verified'] == true;
      if (!ok) {
        throw StudentVerificationException(
          (res.data['error'] as String?) ?? 'Não foi possível verificar o código.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      throw StudentVerificationException(_messageFor(e));
    }
  }

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
      case 'failed-precondition':
        return e.message ?? 'Não foi possível concluir a verificação.';
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
