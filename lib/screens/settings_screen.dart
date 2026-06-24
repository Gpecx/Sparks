import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/widgets/sparky_tutorial.dart';
import 'package:spark_app/screens/achievements_screen.dart';
import 'package:spark_app/screens/edit_profile_screen.dart';
import 'package:spark_app/screens/change_password_screen.dart';
import 'package:spark_app/services/auth_service.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/services/access_code_service.dart';
import 'package:spark_app/services/notification_service.dart';
import 'package:spark_app/providers/user_provider.dart';
import 'package:spark_app/providers/colorblind_provider.dart';
import 'package:spark_app/providers/language_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _textScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final notif = ref.watch(notificationServiceProvider);
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
              AppLocalizations.of(context)!.settingsTitle,
              style: const TextStyle(
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
              _sectionTitle(AppLocalizations.of(context)!.accountAndProfile),
              _tile(
                icon: Icons.person_outline,
                title: AppLocalizations.of(context)!.settingsEditProfile,
                subtitle: AppLocalizations.of(context)!.settingsEditProfileDesc,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              ),
              _tile(
                icon: Icons.emoji_events_outlined,
                title: AppLocalizations.of(context)!.myAchievements,
                subtitle: AppLocalizations.of(context)!.settingsAchievementsDesc,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
              ),
              _tile(
                icon: Icons.trending_up,
                title: AppLocalizations.of(context)!.settingsMyProgress,
                subtitle: AppLocalizations.of(context)!.settingsTrackProgress,
                onTap: () => context.push('/my-progress'),
              ),
              _tile(
                icon: Icons.lock_outline,
                title: AppLocalizations.of(context)!.settingsChangePassword,
                subtitle: AppLocalizations.of(context)!.settingsChangePasswordDesc,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
              ),
              _tile(
                icon: Icons.card_membership_outlined,
                title: AppLocalizations.of(context)!.settingsManagePlan,
                subtitle: AppLocalizations.of(context)!.settingsManagePlanDesc,
                onTap: () => context.push('/store'),
              ),
              _tile(
                icon: Icons.bolt_outlined,
                title: 'Rever tutorial',
                subtitle: 'Veja o tour do Sparky na tela de Início',
                onTap: () {
                  // Fecha as Configurações (revela o shell por baixo) e pede o
                  // tour, que vai para a aba Início e aponta os itens reais.
                  final nav = Navigator.of(context);
                  if (nav.canPop()) nav.pop();
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => sparkyTourReplayRequest.value++,
                  );
                },
              ),
              _tile(
                icon: Icons.delete_outline,
                title: AppLocalizations.of(context)!.settingsDeleteAccount,
                subtitle: AppLocalizations.of(context)!.settingsDeleteAccountDesc,
                titleColor: AppColors.error,
                onTap: _deleteDialog,
              ),
              const SizedBox(height: 8),

              ListenableBuilder(
                listenable: notif,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle(AppLocalizations.of(context)!.smartNotifications),
                    _switchTile(
                      icon: Icons.local_fire_department,
                      title: AppLocalizations.of(context)!.settingsStreakAlerts,
                      subtitle: AppLocalizations.of(context)!.settingsStreakAlertsDesc,
                      value: notif.streakAlerts,
                      onChanged: notif.setStreakAlerts,
                    ),
                    _switchTile(
                      icon: Icons.person_search_outlined,
                      title: AppLocalizations.of(context)!.settingsOnlineFriends,
                      subtitle: AppLocalizations.of(context)!.settingsOnlineFriendsDesc,
                      value: notif.friendActivity,
                      onChanged: notif.setFriendActivity,
                    ),
                    _switchTile(
                      icon: Icons.bolt,
                      title: AppLocalizations.of(context)!.settingsDailyChallenge,
                      subtitle: AppLocalizations.of(context)!.settingsDailyChallengeDesc,
                      value: notif.dailyChallengeAlert,
                      onChanged: notif.setDailyChallengeAlert,
                    ),
                    _switchTile(
                      icon: Icons.emoji_events_outlined,
                      title: AppLocalizations.of(context)!.settingsWeeklyTournament,
                      subtitle: AppLocalizations.of(context)!.settingsWeeklyTournamentDesc,
                      value: notif.tournamentAlerts,
                      onChanged: notif.setTournamentAlerts,
                    ),
                    _switchTile(
                      icon: Icons.star_outline,
                      title: AppLocalizations.of(context)!.settingsAchievements,
                      subtitle: AppLocalizations.of(context)!.settingsAlertFreqDesc,
                      value: notif.achievementAlerts,
                      onChanged: notif.setAchievementAlerts,
                    ),
                    const SizedBox(height: 8),

                    _sectionTitle(AppLocalizations.of(context)!.notificationCustomization),
                    _switchTile(
                      icon: Icons.volume_off_outlined,
                      title: AppLocalizations.of(context)!.settingsSilentMode,
                      subtitle: AppLocalizations.of(context)!.settingsSilentModeDesc,
                      value: notif.silentMode,
                      onChanged: notif.setSilentMode,
                    ),
                    _switchTile(
                      icon: Icons.headset_mic_outlined,
                      title: AppLocalizations.of(context)!.settingsSilentHours,
                      subtitle: AppLocalizations.of(context)!.settingsSilentHoursDesc,
                      value: notif.quietHoursEnabled,
                      onChanged: notif.setQuietHoursEnabled,
                    ),
                    _buildFrequencySelector(notif),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              _sectionTitle(AppLocalizations.of(context)!.accessibility),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.settingsTextSize,
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  AppLocalizations.of(context)!.settingsTextSizeDesc,
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
                      Row(
                        children: [
                          Icon(Icons.language_outlined, color: AppColors.textMuted, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.settingsLanguage,
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  AppLocalizations.of(context)!.settingsLanguageDesc,
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
                          final currentLocale = ref.watch(languageProvider);
                          // Só PT/EN disponíveis por enquanto; evita crash se houver 'es' salvo.
                          final selectedLang = ['pt', 'en'].contains(currentLocale.languageCode)
                              ? currentLocale.languageCode
                              : 'pt';
                          return DropdownButtonFormField<String>(
                            value: selectedLang,
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
                            items: [
                              DropdownMenuItem(value: 'pt', child: Text(AppLocalizations.of(context)!.settingsPortuguese, style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'en', child: Text(AppLocalizations.of(context)!.settingsEnglish, style: TextStyle(color: Colors.white))),
                              // Espanhol será reativado quando a tradução ES estiver concluída.
                            ],
                            onChanged: (code) {
                              if (code != null) {
                                ref.read(languageProvider.notifier).setLanguage(Locale(code));
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
                          Icon(Icons.remove_red_eye_outlined, color: AppColors.textMuted, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.settingsColorBlindMode,
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  AppLocalizations.of(context)!.settingsColorBlindDesc,
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
                            items: [
                              DropdownMenuItem(value: ColorblindMode.none, child: Text(AppLocalizations.of(context)!.settingsNone, style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: ColorblindMode.protanopia, child: Text(AppLocalizations.of(context)!.settingsProtanopia, style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: ColorblindMode.deuteranopia, child: Text(AppLocalizations.of(context)!.settingsDeuteranopia, style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: ColorblindMode.tritanopia, child: Text(AppLocalizations.of(context)!.settingsTritanopia, style: TextStyle(color: Colors.white))),
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
                final user = userAsync.value;
                final isAdmin = (user != null && user.isAdmin);

                if (!isAdmin) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(AppLocalizations.of(context)!.admin),
                    _tile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: AppLocalizations.of(context)!.settingsAdminPanel,
                      subtitle: AppLocalizations.of(context)!.settingsAdminPanelDesc,
                      titleColor: const Color(0xFFFF8C00),
                      onTap: () => context.push('/admin'),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }),

              _sectionTitle(AppLocalizations.of(context)!.settingsAccessSection),
              _tile(
                icon: Icons.vpn_key_outlined,
                title: AppLocalizations.of(context)!.settingsRedeemCode,
                subtitle: AppLocalizations.of(context)!.settingsRedeemCodeDesc,
                onTap: _showRedeemCodeDialog,
              ),
              const SizedBox(height: 8),

              _sectionTitle(AppLocalizations.of(context)!.settingsAboutSupportSection),
              _tile(
                icon: Icons.info_outline,
                title: AppLocalizations.of(context)!.settingsAppVersion,
                subtitle: AppLocalizations.of(context)!.settingsAppVersionDesc,
                onTap: () {},
              ),
              _tile(
                icon: Icons.help_outline,
                title: AppLocalizations.of(context)!.settingsHelpCenter,
                subtitle: AppLocalizations.of(context)!.settingsHelpCenterDesc,
                onTap: _showFaqDialog,
              ),
              _tile(
                icon: Icons.headset_mic_outlined,
                title: AppLocalizations.of(context)!.settingsTechSupport,
                subtitle: AppLocalizations.of(context)!.settingsTechSupportDesc,
                onTap: () => context.push('/support'),
              ),
              _tile(
                icon: Icons.description_outlined,
                title: AppLocalizations.of(context)!.settingsTermsOfUse,
                subtitle: AppLocalizations.of(context)!.settingsTermsOfUseDesc,
                onTap: () => context.push('/terms-of-use'),
              ),
              _tile(
                icon: Icons.privacy_tip_outlined,
                title: 'Política de Privacidade',
                subtitle: 'Como tratamos e protegemos seus dados',
                onTap: () => context.push('/privacy-policy'),
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
                  label: Text(AppLocalizations.of(context)!.settingsLogout,
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

  String _freqLabel(BuildContext context, String f) {
    final l = AppLocalizations.of(context)!;
    switch (f) {
      case 'Mínima': return l.notifFreqMin;
      case 'Alta': return l.notifFreqHigh;
      default: return l.notifFreqNormal;
    }
  }

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

  Widget _buildFrequencySelector(NotificationService notif) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3))),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.speed_outlined, color: AppColors.textMuted, size: 22), SizedBox(width: 12), Text(AppLocalizations.of(context)!.settingsAlertFreq, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 12),
          Row(children: ['Mínima', 'Normal', 'Alta'].map((f) {
            final isSelected = notif.frequency == f;
            return Expanded(child: GestureDetector(onTap: () => notif.setFrequency(f), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: isSelected ? AppColors.primary : AppColors.inputBackground, borderRadius: BorderRadius.circular(6)), child: Center(child: Text(_freqLabel(context, f), style: TextStyle(color: isSelected ? Colors.white : AppColors.textMuted, fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400))))));
          }).toList()),
        ],
      ),
    ),
  );

  void _showRedeemCodeDialog() {
    final controller = TextEditingController();
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(AppLocalizations.of(context)!.settingsRedeemCode,
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.redeemCodeDialogDesc,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                    color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'PROF-XXXX-XXXX',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  errorText: error,
                  enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.textMuted)),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context)!.settingsCancel, style: const TextStyle(color: AppColors.textMuted)),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final code = controller.text.trim().toUpperCase();
                      if (code.isEmpty) {
                        setSt(() => error = AppLocalizations.of(context)!.enterCode);
                        return;
                      }
                      setSt(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        final until =
                            await AccessCodeService.instance.redeem(code);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        final d =
                            '${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')}/${until.year}';
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.primary,
                            content: Text(AppLocalizations.of(context)!.accessGrantedUntil(d)),
                          ),
                        );
                      } on AccessCodeException catch (e) {
                        setSt(() {
                          loading = false;
                          error = e.message;
                        });
                      } catch (_) {
                        setSt(() {
                          loading = false;
                          error = AppLocalizations.of(context)!.redeemError;
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(AppLocalizations.of(context)!.settingsRedeem),
            ),
          ],
        ),
      ),
    );
  }

  void _showFaqDialog() {
    final l10n = AppLocalizations.of(context)!;
    final faqs = [
      {'q': l10n.supportFaqQ1, 'a': l10n.supportFaqA1},
      {'q': l10n.supportFaqQ2, 'a': l10n.supportFaqA2},
      {'q': l10n.supportFaqQ3, 'a': l10n.supportFaqA3},
      {'q': l10n.supportFaqQ4, 'a': l10n.supportFaqA4},
      {'q': l10n.supportFaqQ5, 'a': l10n.supportFaqA5},
      {'q': l10n.supportFaqQ6, 'a': l10n.supportFaqA6},
      {'q': l10n.supportFaqQ7, 'a': l10n.supportFaqA7},
      {'q': l10n.supportFaqQ8, 'a': l10n.supportFaqA8},
      {'q': l10n.supportFaqQ9, 'a': l10n.supportFaqA9},
      {'q': l10n.faqEnergyQ, 'a': l10n.faqEnergyA},
    ];
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => DraggableScrollableSheet(initialChildSize: 0.75, builder: (_, scrollCtrl) => Container(decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Column(children: [const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))), Expanded(child: ListView.builder(controller: scrollCtrl, padding: const EdgeInsets.all(20), itemCount: faqs.length, itemBuilder: (_, i) => _FaqTile(q: faqs[i]['q']!, a: faqs[i]['a']!)))]))));
  }

  void _deleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(AppLocalizations.of(context)!.deleteAccountConfirmTitle, style: const TextStyle(color: Colors.white)),
        content: Text(
          AppLocalizations.of(context)!.deleteAccountWarning,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.settingsCancel),
          ),
          ElevatedButton(
            onPressed: () => _confirmDelete(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.settingsDeleteAction),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext dialogCtx) async {
    final router = GoRouter.of(context);
    Navigator.pop(dialogCtx); // fecha o diálogo de confirmação

    // Diálogo de progresso (não-cancelável)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      await AuthService().deleteAccount();
      UserService().stopListening();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // fecha o progresso
      router.go('/');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // fecha o progresso
      if (!mounted) return;
      SparkSnack.error(context, AppLocalizations.of(context)!.deleteAccountFailed(e.toString()));
    }
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
