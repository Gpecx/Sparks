import 'package:cloud_functions/cloud_functions.dart';

/// Serviço que abstrai as Cloud Functions de códigos de acesso (cortesia):
/// resgate (professor) e gestão (admin).
class AccessCodeService {
  AccessCodeService._();
  static final AccessCodeService instance = AccessCodeService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  /// Resgata um [code] e libera acesso total por N dias.
  /// Retorna a data até a qual o acesso fica válido.
  ///
  /// Lança [AccessCodeException] com mensagem amigável em caso de falha.
  Future<DateTime> redeem(String code) async {
    try {
      final callable = _functions.httpsCallable(
        'redeemAccessCode',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final res = await callable.call<Map<String, dynamic>>({'code': code});
      return DateTime.parse(res.data['expiresAt'] as String);
    } on FirebaseFunctionsException catch (e) {
      throw AccessCodeException(_messageFor(e));
    }
  }

  /// [admin] Gera um lote de [count] códigos de [durationDays] dias.
  Future<List<String>> createCodes({
    required int count,
    int durationDays = 30,
    String? label,
  }) async {
    try {
      final callable = _functions.httpsCallable('createAccessCodes');
      final res = await callable.call<Map<String, dynamic>>({
        'count': count,
        'durationDays': durationDays,
        if (label != null && label.isNotEmpty) 'label': label,
      });
      return (res.data['codes'] as List).map((e) => e.toString()).toList();
    } on FirebaseFunctionsException catch (e) {
      throw AccessCodeException(_messageFor(e));
    }
  }

  /// [admin] Lista os códigos existentes e seus status.
  Future<List<Map<String, dynamic>>> listCodes() async {
    try {
      final callable = _functions.httpsCallable('listAccessCodes');
      final res = await callable.call<Map<String, dynamic>>({});
      return (res.data['codes'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw AccessCodeException(_messageFor(e));
    }
  }

  /// [admin] Desativa um código (não afeta acessos já concedidos).
  Future<void> revoke(String code) async {
    try {
      final callable = _functions.httpsCallable('revokeAccessCode');
      await callable.call<Map<String, dynamic>>({'code': code});
    } on FirebaseFunctionsException catch (e) {
      throw AccessCodeException(_messageFor(e));
    }
  }

  /// Mapeia os códigos de erro do backend para mensagens PT-BR.
  String _messageFor(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'not-found':
        return 'Código inválido.';
      case 'already-exists':
        return 'Você já resgatou este código.';
      case 'resource-exhausted':
        return e.message ?? 'Código esgotado ou muitas tentativas. Tente mais tarde.';
      case 'failed-precondition':
        return e.message ?? 'Não foi possível resgatar este código.';
      case 'permission-denied':
        return 'Você não tem permissão para esta ação.';
      case 'unauthenticated':
        return 'Faça login para continuar.';
      case 'invalid-argument':
        return 'Código é obrigatório.';
      default:
        return e.message ?? 'Erro ao processar o código.';
    }
  }
}

/// Exceção com mensagem pronta para exibir ao usuário.
class AccessCodeException implements Exception {
  final String message;
  AccessCodeException(this.message);
  @override
  String toString() => message;
}
