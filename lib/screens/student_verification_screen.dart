import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────
//  VERIFICAÇÃO DE ESTUDANTE — PDF §8
//
//  Fluxo (sem backend de pagamento):
//   1. Usuário informa instituição + e-mail institucional (.edu.br)
//      OU anexa comprovante (foto/PDF).
//   2. Grava em student_verifications/{uid} com status.
//   3. E-mail .edu.br conhecido ⇒ auto-aprovação (MVP). Caso contrário
//      fica 'pending' p/ revisão de admin.
//   4. A ativação efetiva do plano Student (preço/cobrança) é feita no
//      fluxo de pagamento — fora do escopo desta tela.
// ─────────────────────────────────────────────────────────────────

/// Domínios .edu.br liberados p/ auto-aprovação (MVP — PDF anexo B).
/// Lista completa pode vir do Firestore config/student_domains.
const Set<String> kApprovedStudentDomains = {
  'usp.br',
  'unicamp.br',
  'ufmg.edu.br',
  'ufrj.br',
  'ufpe.br',
  'ufsc.br',
  'ufrgs.br',
  'unesp.br',
  'ufba.br',
  'unb.br',
};

bool isApprovedStudentEmail(String email) {
  final e = email.trim().toLowerCase();
  final at = e.indexOf('@');
  if (at < 0) return false;
  final domain = e.substring(at + 1);
  if (domain.endsWith('.edu.br')) return true;
  return kApprovedStudentDomains.any((d) => domain == d || domain.endsWith('.$d'));
}

final _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

/// Stream do status de verificação do usuário atual.
final studentVerificationProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return _db
      .collection('student_verifications')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? s.data() : null);
});

class StudentVerificationScreen extends ConsumerStatefulWidget {
  const StudentVerificationScreen({super.key});

  @override
  ConsumerState<StudentVerificationScreen> createState() =>
      _StudentVerificationScreenState();
}

class _StudentVerificationScreenState
    extends ConsumerState<StudentVerificationScreen> {
  final _institutionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  XFile? _proof;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pré-preenche com o e-mail da conta, se houver.
    final user = ref.read(userModelProvider).value;
    if (user?.email != null) _emailCtrl.text = user!.email;
  }

  @override
  void dispose() {
    _institutionCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) setState(() => _proof = picked);
    } catch (_) {
      _snack('Não foi possível selecionar o arquivo.');
    }
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final institution = _institutionCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (institution.isEmpty) {
      _snack('Informe o nome da instituição.');
      return;
    }
    if (email.isEmpty && _proof == null) {
      _snack('Informe o e-mail institucional ou anexe um comprovante.');
      return;
    }

    setState(() => _submitting = true);
    try {
      String? proofUrl;
      if (_proof != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref('student_proofs/$uid/${_proof!.name}');
          await ref.putData(await _proof!.readAsBytes());
          proofUrl = await ref.getDownloadURL();
        } catch (_) {
          // Falha no upload não bloqueia: segue como pendente sem anexo.
        }
      }

      // Segurança: o cliente sempre grava 'pending'. A aprovação (incl.
      // o fast-track de e-mail .edu.br) é feita por admin/Cloud Function,
      // que confere o campo `autoEligible`. Assim ninguém se auto-aprova.
      final autoEligible = email.isNotEmpty && isApprovedStudentEmail(email);

      await _db.collection('student_verifications').doc(uid).set({
        'uid': uid,
        'institution': institution,
        'email': email,
        'method': _proof != null ? 'document' : 'email',
        if (proofUrl != null) 'proofUrl': proofUrl,
        'status': 'pending',
        'autoEligible': autoEligible,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      if (!mounted) return;
      SparkSnack.success(context, autoEligible
          ? 'E-mail institucional reconhecido! Aprovação em instantes.'
          : 'Comprovante enviado. Análise em até 48h.');
    } catch (e) {
      if (!mounted) return;
      SparkSnack.error(context, 'Erro ao enviar: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    SparkSnack.info(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(studentVerificationProvider);
    final status = statusAsync.value?['status'] as String?;

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Verificação de estudante'),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (status != null) _StatusBanner(status: status),
                const SizedBox(height: 16),
                const Text(
                  'Comprove sua matrícula para liberar o preço Student (50% off).',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 24),
                _label('Instituição de ensino'),
                _field(_institutionCtrl, 'Ex.: Universidade Federal de...'),
                const SizedBox(height: 20),
                _label('E-mail institucional (.edu.br) — aprovação imediata'),
                _field(_emailCtrl, 'voce@instituicao.edu.br',
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 20),
                _label('Ou anexe um comprovante de matrícula'),
                _ProofPicker(proof: _proof, onTap: _pickProof),
                const SizedBox(height: 28),
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
                          : const Text('ENVIAR PARA VERIFICAÇÃO',
                              style: TextStyle(
                                  color: AppColors.surfaceAlt,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A revalidação é exigida a cada 12 meses.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
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

  Widget _field(TextEditingController c, String hint,
      {TextInputType? keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
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

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'approved' => ('Matrícula verificada', const Color(0xFF22C55E), Icons.verified),
      'rejected' => ('Comprovante rejeitado — reenvie', AppColors.error, Icons.error_outline),
      _ => ('Em análise (até 48h)', const Color(0xFFF59E0B), Icons.hourglass_top),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ProofPicker extends StatelessWidget {
  final XFile? proof;
  final VoidCallback onTap;
  const _ProofPicker({required this.proof, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.4),
              style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(proof == null ? Icons.upload_file : Icons.check_circle,
                color: proof == null ? AppColors.textMuted : const Color(0xFF22C55E),
                size: 28),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                proof == null ? 'Selecionar foto/PDF' : proof!.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
