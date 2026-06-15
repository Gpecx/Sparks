import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

// ─────────────────────────────────────────────────────────────────
//  SPARK BUSINESS — Formulário B2B (PDF §5.5 / §9)
//
//  Gera uma "lead" comercial em business_leads/{autoId}. O fluxo de
//  pagamento/NF-e e a criação da organização ficam fora desta tela
//  (serão tratados no backend de pagamento).
// ─────────────────────────────────────────────────────────────────

const int kBusinessPricePerUser = 29; // R$/usuário/mês (catálogo)
const int kBusinessMinSeats = 5;

final _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _company = TextEditingController();
  final _cnpj = TextEditingController();
  final _contactName = TextEditingController();
  final _contactEmail = TextEditingController();
  int _seats = kBusinessMinSeats;
  String _period = 'yearly';
  bool _submitting = false;

  @override
  void dispose() {
    _company.dispose();
    _cnpj.dispose();
    _contactName.dispose();
    _contactEmail.dispose();
    super.dispose();
  }

  int get _monthlyTotal => _seats * kBusinessPricePerUser;

  Future<void> _submit() async {
    if (_company.text.trim().isEmpty ||
        _cnpj.text.trim().isEmpty ||
        _contactEmail.text.trim().isEmpty) {
      _snack('Preencha empresa, CNPJ e e-mail de contato.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _db.collection('business_leads').add({
        'company': _company.text.trim(),
        'cnpj': _cnpj.text.trim(),
        'contactName': _contactName.text.trim(),
        'contactEmail': _contactEmail.text.trim(),
        'seats': _seats,
        'billingPeriod': _period,
        'estimatedMonthly': _monthlyTotal,
        'requestedByUid': FirebaseAuth.instance.currentUser?.uid,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      _snack('Erro ao enviar: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B14),
        title: const Text('Solicitação enviada',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Nossa equipe comercial entrará em contato pelo e-mail informado '
          'para finalizar a proposta e o faturamento.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _snack(String m) => SparkSnack.info(context, m);

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('SPARK Business'),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Text(
                  'Treine sua equipe com painel administrativo, relatórios de '
                  'progresso e faturamento via NF-e.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                _label('Razão social'),
                _field(_company, 'Empresa Ltda.'),
                const SizedBox(height: 16),
                _label('CNPJ'),
                _field(_cnpj, '00.000.000/0001-00',
                    keyboard: TextInputType.number),
                const SizedBox(height: 16),
                _label('Nome do contato'),
                _field(_contactName, 'Responsável'),
                const SizedBox(height: 16),
                _label('E-mail de contato'),
                _field(_contactEmail, 'contato@empresa.com.br',
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 24),
                _label('Número de licenças (mín. $kBusinessMinSeats)'),
                _SeatStepper(
                  seats: _seats,
                  onChanged: (v) => setState(() => _seats = v),
                ),
                const SizedBox(height: 20),
                _label('Período de faturamento'),
                Row(
                  children: [
                    _periodChip('Anual', 'yearly'),
                    const SizedBox(width: 10),
                    _periodChip('Mensal', 'monthly'),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimativa mensal',
                          style: TextStyle(color: AppColors.textSecondary)),
                      Text('R\$ $_monthlyTotal',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _submitting
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.surfaceAlt))
                          : const Text('SOLICITAR PROPOSTA',
                              style: TextStyle(
                                  color: AppColors.surfaceAlt,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodChip(String label, String value) {
    final selected = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.cardBorder.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  Widget _field(TextEditingController c, String hint, {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9./-]'))]
          : null,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

class _SeatStepper extends StatelessWidget {
  final int seats;
  final ValueChanged<int> onChanged;
  const _SeatStepper({required this.seats, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _btn(Icons.remove, () {
            if (seats > kBusinessMinSeats) onChanged(seats - 1);
          }),
          Text('$seats usuários',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          _btn(Icons.add, () => onChanged(seats + 1)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      );
}
