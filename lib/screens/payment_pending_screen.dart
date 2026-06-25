import 'package:spark_app/core/utils/currency_utils.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:spark_app/services/firebase_service.dart';
import 'package:spark_app/services/payment_service.dart';
import 'package:spark_app/services/analytics_service.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:url_launcher/url_launcher.dart';

// Intervalo e tempo máximo de polling (fallback caso o webhook falhe)
const Duration _kPollInterval = Duration(seconds: 10);
const Duration _kPollTimeout = Duration(minutes: 15);

/// Tela exibida após o usuário escolher o método de pagamento.
///
/// Para PIX: mostra o QR Code e o "Copia e Cola" e ouve o Firestore
///           para detectar automaticamente quando o pagamento for confirmado.
///
/// Para Cartão / Boleto: abre o link de pagamento do Asaas no navegador.
class PaymentPendingScreen extends StatefulWidget {
  final CheckoutResult result;

  const PaymentPendingScreen({
    super.key,
    required this.result,
  });

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot>? _orderSub;
  Timer? _pollTimer;
  bool _paid = false;
  bool _copied = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Para pagamentos não-PIX abre o link automaticamente
    if (!widget.result.isPix) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openExternalLink());
    }

    // Ouve o pedido no Firestore para detectar confirmação (real-time)
    _listenOrder();

    // Polling como fallback caso o webhook do Asaas não chegue
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _pollOrderStatus());
  }

  void _listenOrder() {
    final db = FirebaseService.instance.firestore;

    _orderSub = db
        .collection('orders')
        .doc(widget.result.orderId)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) {
        debugPrint('[PaymentPendingScreen] Pedido ainda não existe ou não foi propagado.');
        return;
      }
      final status = snap.data()?['status'] as String?;
      debugPrint('[PaymentPendingScreen] Status atual do pedido ${widget.result.orderId}: $status');
      if (status == 'PAID' && !_paid) {
        setState(() => _paid = true);
        _pulseController.stop();

        // Marketing: compra confirmada (client-side; o servidor envia Purchase via CAPI).
        AnalyticsService().logPurchase(value: widget.result.totalPrice);

        if (mounted) {
          await _showSuccessDialog();
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      }
    }, onError: (e) {
      debugPrint('[PaymentPendingScreen] Erro no listener do pedido: $e');
    });
  }

  /// Polling ativo — fallback para quando o webhook Asaas não dispara.
  /// Chama a Cloud Function [checkPaymentStatus] que consulta o Asaas
  /// diretamente e processa os pontos caso o pagamento esteja confirmado.
  Future<void> _pollOrderStatus() async {
    if (_paid) {
      _pollTimer?.cancel();
      return;
    }

    // Para de fazer polling após o timeout
    if (DateTime.now().difference(_startedAt) > _kPollTimeout) {
      debugPrint('[PaymentPendingScreen] Timeout de polling atingido.');
      _pollTimer?.cancel();
      return;
    }

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final callable = functions.httpsCallable('checkPaymentStatus');
      final response = await callable.call<Map<String, dynamic>>({
        'orderId': widget.result.orderId,
      });

      final data = Map<String, dynamic>.from(response.data);
      final status = data['status'] as String? ?? 'PENDING';
      final processed = data['processed'] as bool? ?? false;
      debugPrint('[PaymentPendingScreen][POLL] status=$status processed=$processed');

      if (status == 'PAID' && !_paid && mounted) {
        setState(() => _paid = true);
        _pulseController.stop();
        _pollTimer?.cancel();
        await _showSuccessDialog();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      // Erros de polling são não-críticos — o listener real-time continua ativo
      debugPrint('[PaymentPendingScreen][POLL] Erro ao consultar status: $e');
    }
  }

  Future<void> _openExternalLink() async {
    final url = widget.result.invoiceUrl ?? widget.result.bankSlipUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyPixCode() async {
    final payload = widget.result.pixPayload;
    if (payload == null) return;
    await Clipboard.setData(ClipboardData(text: payload));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone de sucesso com glow
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                AppLocalizations.of(context)!.paymentCompleted,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              Text(
                AppLocalizations.of(context)!.paymentApproved,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.person_rounded,
                      size: 18, color: Colors.black),
                  label: const Text(
                    'CONCLUÍDO',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.result.isPix
                  ? 'PAGAR VIA PIX'
                  : widget.result.isBoleto
                      ? 'BOLETO BANCÁRIO'
                      : 'CARTÃO DE CRÉDITO',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.5),
            ),
          ),
          body: widget.result.isPix ? _buildPixBody() : _buildLinkBody(),
        ),
      ),
    );
  }

  // ── PIX ─────────────────────────────────────────────────────────

  Widget _buildPixBody() {
    final qrBase64 = widget.result.pixQrCodeBase64;
    final payload = widget.result.pixPayload;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Status pill
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.paymentPendingWaiting,
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // QR Code
          if (qrBase64 != null && qrBase64.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 2)
                ],
              ),
              child: Image.memory(
                base64Decode(qrBase64),
                width: 220,
                height: 220,
                fit: BoxFit.contain,
              ),
            )
          else
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          const SizedBox(height: 8),
          if (widget.result.pixExpirationDate != null)
            Text(
              AppLocalizations.of(context)!.paymentExpiresIn(widget.result.pixExpirationDate ?? ''),
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11),
            ),
          const SizedBox(height: 28),

          // Total
          Text(
            CurrencyUtils.format(context, widget.result.totalPrice),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const SizedBox(height: 28),

          // Copia e Cola
          if (payload != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(AppLocalizations.of(context)!.paymentPixCode,
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      payload,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _copyPixCode,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _copied
                          ? const Icon(Icons.check_circle,
                              color: AppColors.primary,
                              size: 22,
                              key: ValueKey('check'))
                          : const Icon(Icons.copy_outlined,
                              color: AppColors.textMuted,
                              size: 22,
                              key: ValueKey('copy')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _copyPixCode,
                icon: Icon(
                    _copied ? Icons.check_circle : Icons.copy_outlined,
                    size: 18,
                    color: Colors.black),
                label: Text(
                    _copied ? 'CÓDIGO COPIADO!' : 'COPIAR CÓDIGO PIX',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.paymentAutoConfirm,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Link externo (Cartão / Boleto) ───────────────────────────────

  Widget _buildLinkBody() {
    final url = widget.result.invoiceUrl ?? widget.result.bankSlipUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.open_in_browser,
              color: AppColors.primary, size: 72),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.paymentRedirecting,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.paymentAfterComplete,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: url != null ? _openExternalLink : null,
              icon:
                  const Icon(Icons.open_in_new, size: 18, color: Colors.black),
              label: Text(AppLocalizations.of(context)!.paymentOpenPage,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) =>
                Opacity(opacity: _pulseAnim.value, child: child),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.paymentWaitingConfirm,
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
