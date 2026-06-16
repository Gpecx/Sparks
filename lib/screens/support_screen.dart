import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _sending = false;
  bool _sent = false;

  String _selectedCategory = 'Dúvida geral';
  final _categories = [
    'Dúvida geral',
    'Problema técnico',
    'Sugestão de melhoria',
    'Erro em conteúdo',
    'Problema com conta',
    'Outro',
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    try {
      final user = UserService().user;
      await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      ).collection('support_tickets').add({
        'uid': user?.uid ?? 'anon',
        'email': user?.email ?? '',
        'displayName': user?.displayName ?? '',
        'category': _selectedCategory,
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });

      if (mounted) setState(() { _sending = false; _sent = true; });
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        SparkSnack.error(context, 'Erro ao enviar. Tente novamente.');
      }
    }
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
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'AJUDA & SUPORTE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
            centerTitle: true,
          ),
          body: _sent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2),
              ),
              child: const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.supportMessageSent,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Nossa equipe vai analisar seu chamado e responder pelo e-mail cadastrado em até 48 horas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'VOLTAR AO INÍCIO',
                style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canais rápidos
          _sectionTitle('CONTATO RÁPIDO'),
          const SizedBox(height: 12),
          Row(
            children: [
              _quickContactCard(
                icon: Icons.email_outlined,
                label: AppLocalizations.of(context)!.supportEmail,
                sublabel: AppLocalizations.of(context)!.supportEmailAddress,
                color: AppColors.blue,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: AppLocalizations.of(context)!.supportEmailAddress));
                  SparkSnack.success(context, 'E-mail copiado!');
                },
              ),
              const SizedBox(width: 12),
              _quickContactCard(
                icon: Icons.chat_bubble_outline,
                label: AppLocalizations.of(context)!.supportWhatsApp,
                sublabel: AppLocalizations.of(context)!.supportWhatsAppHours,
                color: const Color(0xFF25D366),
                onTap: () {
                  SparkSnack.info(context, 'WhatsApp em breve!');
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          // FAQ
          _sectionTitle('PERGUNTAS FREQUENTES'),
          const SizedBox(height: 12),
          _faqItem('Como funciona o sistema de XP?',
              'Você ganha XP ao completar lições e responder perguntas corretamente. O XP aumenta seu nível e desbloqueia novos conteúdos.'),
          _faqItem('Como resetar minha senha?',
              'Acesse a tela de Login e clique em "Esqueci minha senha". Você receberá um link de redefinição no seu e-mail.'),
          _faqItem('Os pactos semanais resetam quando?',
              'Os pactos resetam toda segunda-feira às 00:00. Seu progresso é zerado e você pode escolher novos pactos.'),
          _faqItem('Como entrar em contato para erros de conteúdo?',
              'Use o formulário abaixo e selecione "Erro em conteúdo". Nossa equipe vai revisar e corrigir o mais rápido possível.'),

          const SizedBox(height: 32),

          // Formulário
          _sectionTitle('ENVIAR MENSAGEM'),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categoria
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      dropdownColor: AppColors.card,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(Icons.expand_more, color: AppColors.textMuted),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Assunto
                TextFormField(
                  controller: _subjectCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Assunto',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o assunto' : null,
                ),
                const SizedBox(height: 12),

                // Mensagem
                TextFormField(
                  controller: _messageCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.supportMessageHint,
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Mensagem muito curta (mín. 10 caracteres)'
                      : null,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : const Text(
                            'ENVIAR MENSAGEM',
                            style: TextStyle(
                              color: AppColors.background,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      );

  Widget _quickContactCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(sublabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textMuted,
        title: Text(
          question,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
