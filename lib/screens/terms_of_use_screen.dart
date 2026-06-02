import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

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
              'TERMOS DE USO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
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
                _sectionTitle('SEÇÕES DOS TERMOS'),
                const SizedBox(height: 12),
                _buildTermTile(
                  title: '1. Introdução e Objetivo do SPARK',
                  content: 'O SPARK é uma plataforma digital focada no treinamento, capacitação e aprimoramento profissional na área de engenharia eletrotécnica e normas do setor elétrico. Ao acessar a plataforma, você concorda em cumprir e ser regido por estes Termos de Uso, bem como pela nossa Política de Privacidade.',
                ),
                _buildTermTile(
                  title: '2. Conta, Cadastro e Segurança',
                  content: 'Para acessar as funcionalidades completas, lições e simulação de erros, você deve realizar o cadastro fornecendo dados verídicos e atualizados. A segurança da sua senha é de sua inteira responsabilidade. Qualquer atividade realizada sob sua conta será atribuída a você.',
                ),
                _buildTermTile(
                  title: '3. Spark Points e Assinatura Premium',
                  content: 'O SPARK possui mecânicas de gamificação (XP, Clãs, Torneios) e uma loja virtual. Pontos Spark e assinaturas premium podem ser adquiridos via métodos de pagamento disponíveis. As compras de produtos digitais são definitivas, e o reembolso segue estritamente as diretrizes da legislação nacional aplicável de comércio eletrônico.',
                ),
                _buildTermTile(
                  title: '4. Propriedade Intelectual',
                  content: 'Todos os materiais didáticos, questões, simulações de esquemas de PCI/PCB, códigos, artes visuais e textos disponibilizados no SPARK são de propriedade intelectual exclusiva da EXS Solutions ou devidamente licenciados. É expressamente proibida a reprodução, distribuição ou engenharia reversa destes materiais sem autorização prévia por escrito.',
                ),
                _buildTermTile(
                  title: '5. Conduta na Comunidade (Clãs e Duelos)',
                  content: 'A convivência na área de Clãs e Duelos de Conhecimento deve ser pautada pelo respeito mútuo. Trapaças, uso de scripts maliciosos, ofensas no chat ou qualquer comportamento que prejudique a experiência pedagógica de outros usuários resultará na suspensão imediata ou cancelamento definitivo da conta do infrator.',
                ),
                _buildTermTile(
                  title: '6. Proteção de Dados (LGPD)',
                  content: 'Coletamos e processamos seus dados (como e-mail, nome, progresso de estudos e respostas) com o objetivo exclusivo de aprimorar a sua jornada de aprendizado e validar suas conquistas, respeitando integralmente as disposições da Lei Geral de Proteção de Dados (LGPD).',
                ),
                _buildTermTile(
                  title: '7. Alterações e Limitação de Responsabilidade',
                  content: 'Reservamo-nos o direito de alterar estes termos e atualizar os conteúdos da plataforma a qualquer momento para melhoria contínua. O SPARK não se responsabiliza por eventuais interrupções temporárias de conexão ou bugs de terceiros, mas empenhará os melhores esforços técnicos para rápida resolução de incidentes.',
                ),
                const SizedBox(height: 32),
                _buildFooter(context),
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
                child: const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Termos & Condições',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
            'Leia atentamente as diretrizes abaixo para entender seus direitos, deveres e as regras da nossa plataforma de aprendizado eletrotécnico.',
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

  Widget _buildTermTile({required String title, required String content}) {
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
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.5),
                children: [
                  const TextSpan(text: 'Dúvidas sobre os termos? Entre em contato com a equipe de '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () {
                        context.pop();
                        context.push('/support');
                      },
                      child: const Text(
                        'Suporte Técnico',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
