import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/widgets/spark_snack.dart';

/// Política de Privacidade (LGPD). Rota pública `/privacy-policy` — também
/// serve como a URL pública exigida pela Play Store / App Store.
///
/// IMPORTANTE (revisão antes de publicar): confirmar com o jurídico a razão
/// social/CNPJ do controlador, o e-mail do encarregado (DPO) e os prazos de
/// retenção. O texto abaixo é uma base sólida, não aconselhamento jurídico.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _contactEmail = 'suporte@exs.com.br';

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
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            title: const Text(
              'POLÍTICA DE PRIVACIDADE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _sectionTitle('SEÇÕES'),
                const SizedBox(height: 12),
                _tile(
                  title: '1. Quem somos',
                  content:
                      'O SPARK é uma plataforma de capacitação em engenharia eletrotécnica '
                      'operada pela EXS Solutions ("nós"). Esta Política explica quais dados '
                      'pessoais coletamos, como os usamos e quais são os seus direitos, em '
                      'conformidade com a Lei Geral de Proteção de Dados (LGPD, Lei 13.709/2018).',
                ),
                _tile(
                  title: '2. Dados que coletamos',
                  content:
                      '• Cadastro: nome, e-mail, foto de perfil (opcional) e, no login com '
                      'Google, os dados básicos da conta Google.\n'
                      '• Uso do app: progresso de estudos, XP, respostas de quizzes, '
                      'participação em clãs, duelos e ranking.\n'
                      '• Verificação de estudante (opcional): documentos enviados por você '
                      'para comprovar matrícula, tratados apenas para essa finalidade.\n'
                      '• Pagamentos: quando você assina ou compra, os dados de pagamento são '
                      'processados pelo nosso parceiro (Asaas). Não armazenamos os dados '
                      'completos do seu cartão.\n'
                      '• Dados técnicos: identificadores do dispositivo, tokens de notificação '
                      '(FCM), logs de uso e diagnósticos para segurança e estabilidade.',
                ),
                _tile(
                  title: '3. Como usamos os dados',
                  content:
                      'Usamos seus dados para: criar e manter sua conta; personalizar e '
                      'registrar sua jornada de aprendizado; operar gamificação (XP, clãs, '
                      'duelos, ranking); processar compras e assinaturas; enviar notificações '
                      'relevantes; prevenir fraudes e abusos; e cumprir obrigações legais.',
                ),
                _tile(
                  title: '4. Compartilhamento com terceiros',
                  content:
                      'Compartilhamos dados apenas com prestadores necessários ao '
                      'funcionamento do app:\n'
                      '• Google Firebase (autenticação, banco de dados, hospedagem, '
                      'notificações e analytics);\n'
                      '• Asaas (processamento de pagamentos).\n'
                      'Não vendemos seus dados pessoais. O compartilhamento ocorre no limite '
                      'necessário e sob obrigações de confidencialidade.',
                ),
                _tile(
                  title: '5. Armazenamento e segurança',
                  content:
                      'Seus dados são armazenados na infraestrutura do Google Firebase, com '
                      'controles de acesso, regras de segurança e limites de requisição. '
                      'Mantemos os dados pelo tempo necessário às finalidades descritas ou '
                      'conforme exigido por lei (ex.: registros financeiros). Adotamos medidas '
                      'técnicas e organizacionais para proteger seus dados, embora nenhum '
                      'sistema seja 100% imune a incidentes.',
                ),
                _tile(
                  title: '6. Seus direitos (LGPD)',
                  content:
                      'Você pode, a qualquer momento, solicitar: confirmação e acesso aos '
                      'seus dados; correção de dados incompletos ou desatualizados; '
                      'anonimização ou eliminação; portabilidade; e informações sobre '
                      'compartilhamento. Para exercer esses direitos, fale conosco pelo '
                      'e-mail $_contactEmail.',
                ),
                _tile(
                  title: '7. Exclusão da conta e dos dados',
                  content:
                      'Você pode excluir permanentemente sua conta diretamente no app, em '
                      'Configurações → Eliminar Conta. A exclusão remove seu perfil, progresso, '
                      'posição no ranking, vínculos com clãs e sua conta de acesso. Alguns '
                      'registros podem ser retidos quando exigido por obrigação legal.',
                ),
                _tile(
                  title: '8. Crianças e adolescentes',
                  content:
                      'O SPARK é destinado a profissionais e estudantes da área. O uso por '
                      'menores deve ocorrer com consentimento e supervisão dos responsáveis, '
                      'nos termos da legislação aplicável.',
                ),
                _tile(
                  title: '9. Alterações desta Política',
                  content:
                      'Podemos atualizar esta Política periodicamente. Mudanças relevantes '
                      'serão comunicadas no app. A data da última atualização consta no topo '
                      'desta tela.',
                ),
                const SizedBox(height: 24),
                _buildContact(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Sua privacidade',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Última atualização: Junho de 2026',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Levamos a sério a proteção dos seus dados. Abaixo, de forma transparente, '
            'explicamos o que coletamos e como você controla suas informações.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _tile({required String title, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textMuted,
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          children: [
            Text(
              content,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Encarregado de dados / contato',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: _contactEmail));
                    SparkSnack.info(context, 'E-mail copiado: $_contactEmail');
                  },
                  child: const Text(
                    _contactEmail,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
