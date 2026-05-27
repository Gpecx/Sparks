import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/services/payment_service.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tela exibida após o usuário escolher o método de pagamento.
///
/// Para PIX: mostra o QR Code e o "Copia e Cola" e ouve o Firestore
///           para detectar automaticamente quando o pagamento for confirmado.
///
/// Para Cartão / Boleto: abre o link de pagamento do Asaas no navegador.
class PaymentPendingScreen extends StatefulWidget {
  final CheckoutResult result;
  final int totalPoints;

  const PaymentPendingScreen({
    super.key,
    required this.result,
    required this.totalPoints,
  });

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot>? _orderSub;
  bool _paid = false;
  bool _copied = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

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

    // Ouve o pedido no Firestore para detectar confirmação
    _listenOrder();
  }

  void _listenOrder() {
    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    );

    _orderSub = db
        .collection('orders')
        .doc(widget.result.orderId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final status = snap.data()?['status'] as String?;
      if (status == 'PAID' && !_paid) {
        setState(() => _paid = true);
        _pulseController.stop();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.totalPoints > 0
                          ? 'Pagamento Confirmado! +${widget.totalPoints} Pontos adicionados.'
                          : 'Pagamento Confirmado!',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          
          context.go('/home');
        }
      }
    });
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

  @override
  void dispose() {
    _orderSub?.cancel();
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
                  const Text(
                    'Aguardando pagamento...',
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
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          const SizedBox(height: 8),
          if (widget.result.pixExpirationDate != null)
            Text(
              'Expira em: ${widget.result.pixExpirationDate}',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11),
            ),
          const SizedBox(height: 28),

          // Total
          Text(
            'R\$ ${widget.result.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          if (widget.totalPoints > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, color: AppColors.gold, size: 16),
                Text(
                  ' +${widget.totalPoints} Pontos Spark ao confirmar',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          const SizedBox(height: 28),

          // Copia e Cola
          if (payload != null) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('CÓDIGO PIX — COPIA E COLA',
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
            'O pagamento é confirmado automaticamente.\nVocê não precisa fazer nada após pagar.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
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
          const Text(
            'Você será redirecionado\npara a página de pagamento',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Após finalizar o pagamento, seus Pontos Spark\nserão adicionados automaticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: url != null ? _openExternalLink : null,
              icon:
                  const Icon(Icons.open_in_new, size: 18, color: Colors.black),
              label: const Text('ABRIR PÁGINA DE PAGAMENTO',
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
                const Text('Aguardando confirmação...',
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
