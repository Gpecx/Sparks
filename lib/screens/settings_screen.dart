import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/achievements_screen.dart';
import 'package:spark_app/screens/edit_profile_screen.dart';
import 'package:spark_app/screens/change_password_screen.dart';
import 'package:spark_app/services/auth_service.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/providers/user_provider.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';
import 'package:spark_app/providers/colorblind_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
                subtitle: 'Acompanhar progresso nos módulos',
                onTap: () => context.push('/my-progress'),
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
                icon: Icons.headset_mic_outlined,
                title: 'Horário Silencioso',
                subtitle: 'Sem notificações das 22h às 7h',
                value: _quietHoursEnabled,
                onChanged: (v) => setState(() => _quietHoursEnabled = v),
              ),
              _buildFrequencySelector(),
              const SizedBox(height: 8),

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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

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
                      const Row(
                        children: [
                          Icon(Icons.remove_red_eye_outlined, color: AppColors.textMuted, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Modo Daltônico',
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Ajuste as cores para diferentes tipos de daltonismo',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, child) {
                          final currentMode = ref.watch(colorblindProvider);
                          return DropdownButtonFormField<ColorblindMode>(
                            initialValue: currentMode,
                            dropdownColor: AppColors.card,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.inputBackground,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: ColorblindMode.none, child: Text('Nenhum', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: ColorblindMode.protanopia, child: Text('Protanopia (Vermelho-Verde)', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: ColorblindMode.deuteranopia, child: Text('Deuteranopia (Verde-Vermelho)', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: ColorblindMode.tritanopia, child: Text('Tritanopia (Azul-Amarelo)', style: TextStyle(color: Colors.white))),
                            ],
                            onChanged: (mode) {
                              if (mode != null) {
                                ref.read(colorblindProvider.notifier).setMode(mode);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── ADMINISTRAÇÃO ──────────────────────────────────
              Builder(builder: (context) {
                final userAsync = ref.watch(userModelProvider);
                final isDevMode = ref.watch(devModeProvider);
                final user = userAsync.value;
                final isAdmin = (user != null && user.isAdmin) || isDevMode;

                if (!isAdmin) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('ADMINISTRAÇÃO'),
                    _tile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Painel Admin',
                      subtitle: 'Gerenciar categorias, módulos e lições',
                      titleColor: const Color(0xFFFF8C00),
                      onTap: () => context.push('/admin'),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }),

              _sectionTitle('SOBRE E SUPORTE'),
              _tile(
                icon: Icons.info_outline,
                title: 'Versão do App',
                subtitle: 'SPARK v1.0.4 · EXS Solutions',
                onTap: () {},
              ),
              _tile(
                icon: Icons.help_outline,
                title: 'Central de Ajuda / FAQ',
                subtitle: 'Perguntas frequentes',
                onTap: _showFaqDialog,
              ),
              _tile(
                icon: Icons.headset_mic_outlined,
                title: 'Suporte Técnico',
                subtitle: 'Reporte um problema',
                onTap: () => context.push('/support'),
              ),
              _tile(
                icon: Icons.description_outlined,
                title: 'Termos de Uso',
                subtitle: 'Leia nossos termos',
                onTap: () => context.push('/terms-of-use'),
              ),
              const SizedBox(height: 20),

              // Logout
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    await AuthService().signOut();
                    UserService().stopListening();
                    router.go('/');
                  },
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
    padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
    child: Text(t, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
  );

  Widget _tile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, Color? titleColor}) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3))),
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: titleColor ?? AppColors.textMuted, size: 22),
      title: Text(title, style: TextStyle(color: titleColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
    ),
  );

  Widget _switchTile({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3))),
    child: SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      secondary: Icon(icon, color: AppColors.textMuted, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ),
  );

  Widget _buildFrequencySelector() => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3))),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.speed_outlined, color: AppColors.textMuted, size: 22), SizedBox(width: 12), Text('Frequência de Alertas', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 12),
          Row(children: ['Mínima', 'Normal', 'Alta'].map((f) {
            final isSelected = _notifFrequency == f;
            return Expanded(child: GestureDetector(onTap: () => setState(() => _notifFrequency = f), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: isSelected ? AppColors.primary : AppColors.inputBackground, borderRadius: BorderRadius.circular(6)), child: Center(child: Text(f, style: TextStyle(color: isSelected ? Colors.white : AppColors.textMuted, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))))));
          }).toList()),
        ],
      ),
    ),
  );

  void _showFaqDialog() {
    final faqs = [
      {'q': 'Como funciona o sistema de energia?', 'a': 'Cada lição consome 1 ponto de energia.'},
      {'q': 'O que são Pontos Spark?', 'a': 'Moeda do app para conteúdos premium.'},
    ];
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => DraggableScrollableSheet(initialChildSize: 0.75, builder: (_, scrollCtrl) => Container(decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Column(children: [const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))), Expanded(child: ListView.builder(controller: scrollCtrl, padding: const EdgeInsets.all(20), itemCount: faqs.length, itemBuilder: (_, i) => _FaqTile(q: faqs[i]['q']!, a: faqs[i]['a']!)))]))));
  }

  void _deleteDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: AppColors.card, title: const Text('Eliminar Conta?', style: TextStyle(color: Colors.white)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')), ElevatedButton(onPressed: () => context.go('/'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('ELIMINAR'))]));
  }
}

class _FaqTile extends StatelessWidget {
  final String q, a;
  const _FaqTile({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        title: Text(q, style: const TextStyle(color: Colors.white, fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(a, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
