import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/achievements_screen.dart';
import 'package:spark_app/screens/technical_standards_screen.dart';
import 'package:spark_app/screens/edit_profile_screen.dart';
import 'package:spark_app/screens/change_password_screen.dart';
import 'package:spark_app/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _studyReminders = true;
  bool _rankingAlerts = true;
  bool _normUpdates = false;
  bool _emailNotifications = false;
  double _textScale = 1.0;

  // Smart Notifications
  bool _streakAlerts = true;
  bool _friendActivity = true;
  bool _dailyChallengeAlert = true;
  bool _tournamentAlerts = true;
  bool _achievementAlerts = true;
  bool _silentMode = false;
  bool _quietHoursEnabled = true;
  String _notifFrequency = 'Normal';

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
            title: const Text(
              'CONFIGURAÇÕES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _sectionTitle('CONTA E PERFIL'),
              _tile(
                icon: Icons.person_outline,
                title: 'Editar Perfil',
                subtitle: 'Nome, e-mail, cargo',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              ),
              _tile(
                icon: Icons.emoji_events_outlined,
                title: 'Ver Minhas Conquistas',
                subtitle: 'Página de troféus e insígnias',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
              ),
              _tile(
                icon: Icons.trending_up,
                title: 'Meu Progresso',
                subtitle: 'Normas técnicas recomendadas',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TechnicalStandardsScreen())),
              ),
              _tile(
                icon: Icons.lock_outline,
                title: 'Alterar Senha',
                subtitle: 'Segurança da conta',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
              ),
              _tile(
                icon: Icons.card_membership_outlined,
                title: 'Gerir Plano',
                subtitle: 'Premium, planos ativos',
                onTap: () => context.push('/store'),
              ),
              _tile(
                icon: Icons.delete_outline,
                title: 'Eliminar Conta',
                subtitle: 'Apagar permanentemente',
                titleColor: AppColors.error,
                onTap: _deleteDialog,
              ),
              const SizedBox(height: 8),

              _sectionTitle('NOTIFICAÇÕES INTELIGENTES'),
              _switchTile(
                icon: Icons.local_fire_department,
                title: 'Alertas de Streak',
                subtitle: 'Quando seu streak está em risco',
                value: _streakAlerts,
                onChanged: (v) => setState(() => _streakAlerts = v),
              ),
              _switchTile(
                icon: Icons.person_search_outlined,
                title: 'Amigos Online',
                subtitle: 'Quando um amigo está estudando',
                value: _friendActivity,
                onChanged: (v) => setState(() => _friendActivity = v),
              ),
              _switchTile(
                icon: Icons.bolt,
                title: 'Desafio Diário',
                subtitle: 'Lembrete do desafio rápido',
                value: _dailyChallengeAlert,
                onChanged: (v) => setState(() => _dailyChallengeAlert = v),
              ),
              _switchTile(
                icon: Icons.emoji_events_outlined,
                title: 'Torneio Semanal',
                subtitle: 'Novos torneios e posição no ranking',
                value: _tournamentAlerts,
                onChanged: (v) => setState(() => _tournamentAlerts = v),
              ),
              _switchTile(
                icon: Icons.star_outline,
                title: 'Conquistas',
                subtitle: 'Quando você desbloquear badges',
                value: _achievementAlerts,
                onChanged: (v) => setState(() => _achievementAlerts = v),
              ),
              const SizedBox(height: 8),

              _sectionTitle('PERSONALIZAÇÃO DE NOTIFICAÇÕES'),
              _switchTile(
                icon: Icons.volume_off_outlined,
                title: 'Modo Silencioso',
                subtitle: 'Pausa todas as notificações',
                value: _silentMode,
                onChanged: (v) => setState(() => _silentMode = v),
              ),
              _switchTile(
                icon: Icons.schedule_outlined,
                title: 'Horário Silencioso',
                subtitle: 'Sem notificações das 22h às 7h',
                value: _quietHoursEnabled,
                onChanged: (v) => setState(() => _quietHoursEnabled = v),
              ),
              _buildFrequencySelector(),
              const SizedBox(height: 8),

              _sectionTitle('NOTIFICAÇÕES GERAIS'),
              _switchTile(
                icon: Icons.school_outlined,
                title: 'Lembretes de Estudo',
                subtitle: 'Notificações diárias de prática',
                value: _studyReminders,
                onChanged: (v) => setState(() => _studyReminders = v),
              ),
              _switchTile(
                icon: Icons.leaderboard_outlined,
                title: 'Alertas de Ranking',
                subtitle: 'Quando alguém te ultrapassar',
                value: _rankingAlerts,
                onChanged: (v) => setState(() => _rankingAlerts = v),
              ),
              _switchTile(
                icon: Icons.new_releases_outlined,
                title: 'Atualizações de Normas',
                subtitle: 'Novas normas disponíveis',
                value: _normUpdates,
                onChanged: (v) => setState(() => _normUpdates = v),
              ),
              _switchTile(
                icon: Icons.email_outlined,
                title: 'E-mails',
                subtitle: 'Newsletter e novidades',
                value: _emailNotifications,
                onChanged: (v) => setState(() => _emailNotifications = v),
              ),
              const SizedBox(height: 8),

              // ── ACESSIBILIDADE ────────────────────────────────
              _sectionTitle('ACESSIBILIDADE'),
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.text_fields, color: AppColors.textMuted, size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tamanho do Texto',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Ajuste o tamanho da fonte em todo o app',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '${(_textScale * 100).round()}%',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('A', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: AppColors.inputBackground,
                                thumbColor: AppColors.primary,
                                overlayColor: AppColors.primary.withValues(alpha: 0.2),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _textScale,
                                min: 0.8,
                                max: 1.4,
                                divisions: 12,
                                onChanged: (v) => setState(() => _textScale = v),
                              ),
                            ),
                          ),
                          const Text('A', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      // Preview
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Exemplo de texto com o tamanho selecionado.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14 * _textScale,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── SOBRE ──────────────────────────────────────────
              _sectionTitle('SOBRE'),
              _tile(
                icon: Icons.info_outline,
                title: 'Versão do App',
                subtitle: 'SPARK v1.0.0 · EXS Solutions',
                onTap: () {},
              ),
              _tile(
                icon: Icons.school_outlined,
                title: 'Refazer Tutorial',
                subtitle: 'Minigame interativo do app',
                onTap: () => context.push('/onboarding'),
              ),
              _tile(
                icon: Icons.description_outlined,
                title: 'Termos de Uso',
                subtitle: 'Leia nossos termos',
                onTap: () => _snack('Termos de Uso'),
              ),
              _tile(
                icon: Icons.privacy_tip_outlined,
                title: 'Política de Privacidade',
                subtitle: 'Como usamos seus dados',
                onTap: () => _snack('Privacidade'),
              ),
              _tile(
                icon: Icons.headset_mic_outlined,
                title: 'Suporte',
                subtitle: 'Reporte um problema ou tire dúvidas',
                onTap: _showSupportDialog,
              ),
              _tile(
                icon: Icons.help_outline,
                title: 'Central de Ajuda / FAQ',
                subtitle: 'Perguntas frequentes',
                onTap: _showFaqDialog,
              ),
              const SizedBox(height: 20),

              // Logout
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    'SAIR DA CONTA',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(
      t,
      style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2),
    ),
  );

  Widget _tile({required IconData icon, required String title, String? subtitle, Color? titleColor, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: titleColor ?? AppColors.textMuted, size: 22),
        title: Text(title, style: TextStyle(color: titleColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      ),
    );
  }

  Widget _switchTile({required IconData icon, required String title, String? subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textMuted, size: 22),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)) : null,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          inactiveThumbColor: AppColors.textMuted,
          inactiveTrackColor: AppColors.inputBackground,
        ),
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.primary));

  Widget _buildFrequencySelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: const Icon(Icons.tune, color: AppColors.textMuted, size: 22),
        title: const Text('Frequência', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: const Text('Quantidade de notificações', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _notifFrequency,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 18),
              items: ['Mínimo', 'Normal', 'Todas'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => setState(() => _notifFrequency = v ?? 'Normal'),
            ),
          ),
        ),
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.primary, width: 1),
        ),
        title: Row(
          children: const [
            Icon(Icons.headset_mic, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('Suporte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entre em contato com nossa equipe de suporte para relatar problemas, tirar dúvidas ou dar sugestões.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.email_outlined, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('suporte@exssolutions.com.br', style: TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _snack('E-mail de suporte copiado!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('ENVIAR E-MAIL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFaqDialog() {
    final faqs = [
      {'q': 'Como funciona o sistema de energia?', 'a': 'Cada lição consome 1 ponto de energia. Você recupera energia automaticamente com o tempo ou pode recarregar usando Pontos Spark.'},
      {'q': 'O que são Pontos Spark?', 'a': 'Pontos Spark são a moeda do app. Você pode comprar na loja para recarregar energia, desbloquear conteúdos premium e muito mais.'},
      {'q': 'Como posso melhorar meu ranking?', 'a': 'Conclua lições, acerte perguntas do quiz e mantenha streaks de acertos para ganhar mais XP e subir no ranking.'},
      {'q': 'O que é o modo Premium?', 'a': 'Com o Premium você tem energia ilimitada, acesso a todos os módulos e conteúdos exclusivos sem restrição.'},
      {'q': 'Como entrar em um grupo/clã?', 'a': 'Vá até o Perfil e clique em "Meu Clã". Você pode criar um clã ou entrar em um existente com a senha do grupo ou por convite.'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: AppColors.primary, size: 24),
                    SizedBox(width: 10),
                    Text('Central de Ajuda / FAQ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: faqs.length,
                  itemBuilder: (_, i) => _FaqTile(q: faqs[i]['q']!, a: faqs[i]['a']!),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.error, width: 1)),
        title: const Text('Eliminar Conta?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Esta ação é permanente e não pode ser desfeita.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            child: const Text('ELIMINAR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String q;
  final String a;
  const _FaqTile({required this.q, required this.a});

  @override
  State<_FaqTile> createState() => __FaqTileState();
}

class __FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _expanded ? AppColors.primary.withValues(alpha: 0.4) : AppColors.cardBorder.withValues(alpha: 0.3),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: Icon(
            Icons.help_outline,
            color: _expanded ? AppColors.primary : AppColors.textMuted,
            size: 20,
          ),
          title: Text(
            widget.q,
            style: TextStyle(
              color: _expanded ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.a,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}