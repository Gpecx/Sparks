import 'package:cloud_functions/cloud_functions.dart';

/// Tipo de pagamento suportado pelo Asaas.
enum AsaasBillingType {
  pix('PIX'),
  creditCard('CREDIT_CARD'),
  boleto('BOLETO');

  final String value;
  const AsaasBillingType(this.value);
}

/// Resultado retornado pelo backend após criar a cobrança.
class CheckoutResult {
  final String orderId;
  final String chargeId;
  final String billingType;
  final double totalPrice;

  // PIX
  final String? pixPayload;
  final String? pixQrCodeBase64;
  final String? pixExpirationDate;

  // Cartão / Boleto
  final String? invoiceUrl;
  final String? bankSlipUrl;

  const CheckoutResult({
    required this.orderId,
    required this.chargeId,
    required this.billingType,
    required this.totalPrice,
    this.pixPayload,
    this.pixQrCodeBase64,
    this.pixExpirationDate,
    this.invoiceUrl,
    this.bankSlipUrl,
  });

  bool get isPix => billingType == 'PIX';
  bool get isBoleto => billingType == 'BOLETO';
  bool get isCreditCard => billingType == 'CREDIT_CARD';

  factory CheckoutResult.fromMap(Map<String, dynamic> m) {
    return CheckoutResult(
      orderId: m['orderId'] as String,
      chargeId: m['chargeId'] as String,
      billingType: m['billingType'] as String,
      totalPrice: (m['totalPrice'] as num).toDouble(),
      pixPayload: m['pixPayload'] as String?,
      pixQrCodeBase64: m['pixQrCodeBase64'] as String?,
      pixExpirationDate: m['pixExpirationDate'] as String?,
      invoiceUrl: m['invoiceUrl'] as String?,
      bankSlipUrl: m['bankSlipUrl'] as String?,
    );
  }
}

/// Modelo de item passado ao backend.
class CheckoutItemPayload {
  final String name;
  final String description;
  final double price;
  final int sparkPointsGranted;
  final bool isSubscription;
  final String? planId;

  const CheckoutItemPayload({
    required this.name,
    required this.description,
    required this.price,
    required this.sparkPointsGranted,
    this.isSubscription = false,
    this.planId,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'price': price,
        'sparkPointsGranted': sparkPointsGranted,
        'isSubscription': isSubscription,
        if (planId != null) 'planId': planId,
      };
}

/// Serviço que abstrai a chamada à Cloud Function [createAsaasCheckout].
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );

  /// Cria uma cobrança no Asaas e retorna os dados necessários para exibir
  /// o QR Code PIX, link de pagamento ou boleto ao usuário.
  ///
  /// [items] — itens do carrinho a cobrar.
  /// [billingType] — método de pagamento escolhido pelo usuário.
  /// [cpfCnpj] — CPF/CNPJ do cliente (opcional, melhora aprovação de cartão).
  Future<CheckoutResult> createCheckout({
    required List<CheckoutItemPayload> items,
    required AsaasBillingType billingType,
    String? cpfCnpj,
  }) async {
    final callable = _functions.httpsCallable(
      'createAsaasCheckout',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    final response = await callable.call<Map<String, dynamic>>({
      'items': items.map((i) => i.toMap()).toList(),
      'billingType': billingType.value,
      if (cpfCnpj != null) 'customerCpfCnpj': cpfCnpj,
    });

    return CheckoutResult.fromMap(
      Map<String, dynamic>.from(response.data),
    );
  }
}
