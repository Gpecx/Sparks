import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/services/payment_service.dart';
import 'package:spark_app/screens/payment_pending_screen.dart';
import 'package:spark_app/screens/main_shell_screen.dart';
// CartItem é definido aqui para ser importado pela StoreScreen
class CartItem {
  final String name;
  final String description;
  final double price;
  final IconData icon;
  final bool isSubscription;
  final String? planId;

  const CartItem({
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
    this.isSubscription = false,
    this.planId,
  });
}

// ── Seletor de método de pagamento ───────────────────────────────

class _BillingTypeOption {
  final AsaasBillingType type;
  final String label;
  final String subtitle;
  final IconData icon;

  const _BillingTypeOption({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

const _billingOptions = [
  _BillingTypeOption(
    type: AsaasBillingType.pix,
    label: AppLocalizations.of(context)!.checkoutPix,
    subtitle: AppLocalizations.of(context)!.checkoutCreditCardDesc,
    icon: Icons.qr_code_2_rounded,
  ),
  _BillingTypeOption(
    type: AsaasBillingType.creditCard,
    label: AppLocalizations.of(context)!.checkoutCreditCard,
    subtitle: AppLocalizations.of(context)!.checkoutProcessedSecurely,
    icon: Icons.credit_card_rounded,
  ),
  _BillingTypeOption(
    type: AsaasBillingType.boleto,
    label: AppLocalizations.of(context)!.checkoutBoleto,
    subtitle: AppLocalizations.of(context)!.checkoutPixDesc,
    icon: Icons.receipt_long_rounded,
  ),
];

// ── CheckoutScreen ───────────────────────────────────────────────

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  const CheckoutScreen({super.key, required this.items});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  AsaasBillingType _selectedBilling = AsaasBillingType.pix;
  bool _isProcessing = false;
  final _cpfController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // CPF/CNPJ necessário para PIX e Boleto
  bool get _needsCpf =>
      _selectedBilling == AsaasBillingType.pix ||
      _selectedBilling == AsaasBillingType.boleto;

  @override
  void dispose() {
    _cpfController.dispose();
    super.dispose();
  }

  double get _total =>
      widget.items.fold<double>(0, (s, i) => s + i.price);

  // Converte os CartItems da loja em payloads para o backend
  List<CheckoutItemPayload> get _payloads => widget.items
      .map((i) => CheckoutItemPayload(
            name: i.name,
            description: i.description,
            price: i.price,
            isSubscription: i.isSubscription,
            planId: i.planId,
          ))
      .toList();

  Future<void> _finalizeCheckout() async {
    if (_needsCpf && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isProcessing = true);
    final cpf = _cpfController.text.trim().isEmpty ? null : _cpfController.text.trim();
    try {
      final result = await PaymentService.instance.createCheckout(
        items: _payloads,
        billingType: _selectedBilling,
        cpfCnpj: cpf,
      );

      if (!mounted) return;

      // Navega para a tela de aguardo/QR Code
      final shouldGoToProfile = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPendingScreen(
            result: result,
          ),
        ),
      );

      // Volta para a loja ou vai pro perfil ao retornar da tela de pagamento
      if (mounted) {
        final shell = context.findAncestorStateOfType<MainShellScreenState>();
        if (shouldGoToProfile == true) {
          shell?.switchTab(3);
        }
        Navigator.pop(context); // Fecha CheckoutScreen
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      // Mensagem amigável por código de erro
      final String msg;
      final bool isUnavailable;
      switch (e.code) {
        case 'unavailable':
          msg = e.message ?? 'O sistema de pagamentos está em manutenção. Tente novamente em breve.';
          isUnavailable = true;
        case 'unauthenticated':
          msg = 'Você precisa estar logado para fazer uma compra.';
          isUnavailable = false;
        case 'invalid-argument':
          msg = e.message ?? 'Dados inválidos. Tente novamente.';
          isUnavailable = false;
        default:
          // 'internal' ou qualquer outro código desconhecido
          msg = 'O sistema de pagamentos está temporariamente indisponível. Tente novamente em breve.';
          isUnavailable = true;
      }
      _showErrorDialog(msg, isUnavailable: isUnavailable);

    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      _showErrorDialog(msg);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showErrorDialog(String message, {bool isUnavailable = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUnavailable ? Icons.construction_rounded : Icons.error_outline_rounded,
              color: isUnavailable ? AppColors.gold : AppColors.error,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              isUnavailable ? 'Pagamentos em breve!' : 'Ops, algo deu errado',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ENTENDI',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              onPressed:
                  _isProcessing ? null : () => Navigator.pop(context),
            ),
            title: const Text(
              'CHECKOUT',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.5),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: widget.items.isEmpty
                    ? _buildEmptyCart()
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Lista de itens
                          ..._buildItemList(),
                          const SizedBox(height: 24),

                          // Seleção de método de pagamento
                          const Text(
                            'MÉTODO DE PAGAMENTO',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ..._billingOptions.map(
                            (opt) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildBillingOption(opt),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // CPF/CNPJ — obrigatório para PIX e Boleto
                          if (_needsCpf) ...[
                            const Text(
                              'IDENTIFICAÇÃO',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Form(
                              key: _formKey,
                              child: TextFormField(
                                controller: _cpfController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.of(context)!.checkoutCpfCnpj,
                                  hintStyle: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 13),
                                  filled: true,
                                  fillColor: AppColors.card,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: AppColors.cardBorder
                                            .withValues(alpha: 0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: AppColors.cardBorder
                                            .withValues(alpha: 0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: AppColors.primary),
                                  ),
                                  prefixIcon: const Icon(
                                      Icons.badge_outlined,
                                      color: AppColors.textMuted,
                                      size: 20),
                                ),
                                validator: (v) {
                                  final text = v?.trim() ?? '';
                                  if (text.isEmpty) return 'Informe o CPF ou CNPJ';
                                  if (text.length < 11) {
                                    return 'CPF/CNPJ inválido (muito curto)';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: AppColors.textMuted, size: 13),
                                const SizedBox(width: 6),
                                Text(
                                  AppLocalizations.of(context)!.checkoutCpfCnpjRequired,
                                  style: TextStyle(
                                      color:
                                          AppColors.textMuted,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
              ),

              // Rodapé com total e botão
              if (widget.items.isNotEmpty) _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets auxiliares ──────────────────────────────────────────

  Widget _buildEmptyCart() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shopping_cart_outlined,
            color: AppColors.primary.withValues(alpha: 0.2), size: 100),
        const SizedBox(height: 16),
        const Text(
          'Seu carrinho está vazio',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Explore a loja e equipe-se\npara os próximos desafios!',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.storefront, size: 18, color: AppColors.primary),
          label: const Text('VOLTAR À LOJA',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              elevation: 0),
        ),
      ]),
    );
  }

  List<Widget> _buildItemList() {
    return widget.items.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.cardBorder.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(item.icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(item.description,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Text(
                'R\$ ${item.price.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBillingOption(_BillingTypeOption opt) {
    final isSelected = _selectedBilling == opt.type;
    return GestureDetector(
      onTap: () => setState(() => _selectedBilling = opt.type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.cardBorder.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                      alpha: isSelected ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(opt.icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opt.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(opt.subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textMuted.withValues(alpha: 0.5),
                  width: isSelected ? 0 : 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
            top:
                BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${widget.items.length} ${widget.items.length == 1 ? 'item' : 'itens'}',
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('TOTAL ',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Flexible(
                      child: Text(
                        'R\$ ${_total.toStringAsFixed(2)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
              height: 1,
              color: AppColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _finalizeCheckout,
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Text(
                      'CONFIRMAR PEDIDO',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline,
                  color: AppColors.textMuted, size: 12),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.checkoutSecurePayment,
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}