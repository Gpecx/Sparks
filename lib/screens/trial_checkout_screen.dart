import 'package:spark_app/core/utils/currency_utils.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/controllers/energy_controller.dart';
import 'package:spark_app/services/analytics_service.dart';

// ─── Modelo do plano recebido pela tela ──────────────────────────────────────
class TrialPlanInfo {
  final String planId;
  final String planName;
  final double monthlyPrice;
  final Color accentColor;
  final IconData icon;

  const TrialPlanInfo({
    required this.planId,
    required this.planName,
    required this.monthlyPrice,
    required this.accentColor,
    required this.icon,
  });
}

// ─── Formatadores de input ───────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ─── Tela principal ──────────────────────────────────────────────────────────

class TrialCheckoutScreen extends StatefulWidget {
  final TrialPlanInfo plan;

  const TrialCheckoutScreen({super.key, required this.plan});

  @override
  State<TrialCheckoutScreen> createState() => _TrialCheckoutScreenState();
}

class _TrialCheckoutScreenState extends State<TrialCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();

  bool _isProcessing = false;
  bool _obscureCvv = true;

  @override
  void dispose() {
    _holderCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _cpfCtrl.dispose();
    super.dispose();
  }

  Future<void> _startTrial() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isProcessing = true);

    try {
      final expParts = _expiryCtrl.text.split('/');
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final callable = functions.httpsCallable('startTrial');

      await callable.call<Map<String, dynamic>>({
        'planId': widget.plan.planId,
        'cpfCnpj': _cpfCtrl.text.trim(),
        'cardHolderName': _holderCtrl.text.trim(),
        'cardNumber': _cardCtrl.text.replaceAll(' ', ''),
        'cardExpiryMonth': expParts.isNotEmpty ? expParts[0] : '',
        'cardExpiryYear': expParts.length > 1 ? '20${expParts[1]}' : '',
        'cardCvv': _cvvCtrl.text.trim(),
      });

      // Marketing: trial iniciado (client-side; o servidor também envia StartTrial via CAPI).
      AnalyticsService().logTrialStart(plan: widget.plan.planId);

      // Ativa premium localmente imediatamente
      EnergyController().setPremium(true);

      if (!mounted) return;
      await _showSuccessDialog();
      if (mounted) {
        context.go('/');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? AppLocalizations.of(context)!.trialErrorStart);
    } catch (e) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context)!.trialErrorUnexpected);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.credit_card_off_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.trialCheckoutOops,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.trialTryAgain,
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
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
                color: widget.plan.accentColor.withValues(alpha: 0.5),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: widget.plan.accentColor.withValues(alpha: 0.3),
                  blurRadius: 32,
                  spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.plan.accentColor.withValues(alpha: 0.15),
                  border: Border.all(
                      color: widget.plan.accentColor.withValues(alpha: 0.5),
                      width: 2),
                ),
                child: Icon(Icons.all_inclusive,
                    color: widget.plan.accentColor, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.trialCheckoutSuccess,
                style: TextStyle(
                    color: widget.plan.accentColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                  children: [
                    TextSpan(
                        text: '7 dias grátis do ${widget.plan.planName} '),
                    const TextSpan(
                        text: 'com bateria ∞',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                    const TextSpan(
                        text:
                            '.\n\nApós o período, você será cobrado '),
                    TextSpan(
                      text:
                          '${CurrencyUtils.format(context, widget.plan.monthlyPrice)}${AppLocalizations.of(context)!.storePerMonth}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(
                        text: '. Cancele quando quiser nas configurações.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.plan.accentColor,
                  ),
                  child: Text(AppLocalizations.of(context)!.trialStartStudying,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
            ],
          ),
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
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
            ),
            title: const Text(
              'TRIAL GRATUITO',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.5),
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                // ── Banner do plano ─────────────────────────────────
                _buildPlanBanner(),
                const SizedBox(height: 24),

                // ── Dados do cartão ─────────────────────────────────
                _sectionLabel('DADOS DO CARTÃO'),
                const SizedBox(height: 12),
                _buildField(
                  controller: _holderCtrl,
                  hint: AppLocalizations.of(context)!.trialCardName,
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.trialEnterName : null,
                ),
                const SizedBox(height: 10),
                _buildField(
                  controller: _cardCtrl,
                  hint: '0000 0000 0000 0000',
                  icon: Icons.credit_card_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CardNumberFormatter()],
                  validator: (v) {
                    final d = v?.replaceAll(' ', '') ?? '';
                    if (d.length != 16) return AppLocalizations.of(context)!.trialInvalidCardNumber;
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        controller: _expiryCtrl,
                        hint: 'MM/AA',
                        icon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_ExpiryFormatter()],
                        validator: (v) {
                          if (v == null || v.length < 5) return AppLocalizations.of(context)!.trialInvalid;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(
                        controller: _cvvCtrl,
                        hint: 'CVV',
                        icon: Icons.lock_outline,
                        keyboardType: TextInputType.number,
                        obscureText: _obscureCvv,
                        maxLength: 4,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCvv
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscureCvv = !_obscureCvv),
                        ),
                        validator: (v) {
                          final d = v?.trim() ?? '';
                          if (d.length < 3) return 'CVV inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── CPF ─────────────────────────────────────────────
                _sectionLabel('IDENTIFICAÇÃO'),
                const SizedBox(height: 12),
                _buildField(
                  controller: _cpfCtrl,
                  hint: 'CPF/CNPJ',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.text,
                  maxLength: 14,
                  validator: (v) {
                    final d = v?.trim() ?? '';
                    if (d.length < 11) return 'CPF/CNPJ inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // ── Resumo do trial ─────────────────────────────────
                _buildTrialSummary(),
                const SizedBox(height: 24),

                // ── Botão ───────────────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _startTrial,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.plan.accentColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.all_inclusive,
                            color: Colors.white, size: 20),
                    label: Text(
                      _isProcessing
                          ? 'ATIVANDO...'
                          : 'INICIAR 7 DIAS GRÁTIS',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Segurança ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline,
                        color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context)!.trialCheckoutSecure,
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────────

  Widget _buildPlanBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.plan.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: widget.plan.accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.plan.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.plan.icon,
                color: widget.plan.accentColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.planName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '7 dias grátis • Depois R\$ ${widget.plan.monthlyPrice.toStringAsFixed(2)}/mês',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: widget.plan.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: widget.plan.accentColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              'GRÁTIS',
              style: TextStyle(
                  color: widget.plan.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    int? maxLength,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        counterText: '',
        filled: true,
        fillColor: AppColors.card,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: widget.plan.accentColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildTrialSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESUMO',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _summaryRow(AppLocalizations.of(context)!.trialToday, 'R\$ 0,00 (trial)', AppColors.primary),
          const SizedBox(height: 8),
          _summaryRow(
            AppLocalizations.of(context)!.trialAfter7Days,
            '${CurrencyUtils.format(context, widget.plan.monthlyPrice)}${AppLocalizations.of(context)!.storePerMonth}',
            Colors.white,
          ),
          const SizedBox(height: 8),
          _summaryRow(AppLocalizations.of(context)!.trialCancellation, AppLocalizations.of(context)!.trialAnytime, AppColors.textMuted),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFF2A2A3E)),
          ),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.textMuted, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.trialChargeNote,
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
