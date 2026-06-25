import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/screens/achievements_screen.dart';
import 'package:spark_app/screens/clan_screen.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/pocket_card_screen.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';
import 'package:spark_app/providers/user_provider.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/services/access_control_service.dart';
import 'package:spark_app/widgets/plan_widgets.dart';
import 'package:spark_app/models/badge_model.dart';
import 'package:spark_app/core/utils/rank_utils.dart';

// ─────────────────────────────────────────────────────────────────
//  PROFILE SCREEN — Versão com Firebase
//  MUDANÇAS:
//  - Todos os dados (nome, XP, Spark, streak, level, dias ativos,
//    conquistas, clã, ranking) vêm do Firestore via UserService
//  - Conquistas desbloqueadas vêm de unlockedBadgeIds no Firestore
//  - Posição no ranking é buscada em tempo real
// ─────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {

  int _avatarTapCount = 0;
  static const int _triggerTaps = 7;

  // Posição no ranking (carregada de forma assíncrona)
  int _rankingPosition = 0;
  bool _rankingLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRankingPosition();
  }

  /// Busca a posição do usuário no ranking semanal global.
  Future<void> _loadRankingPosition() async {
    final userService = ref.read(userServiceProvider);
    final ranking = await userService.getGlobalWeeklyRanking();
    final uid = userService.uid;
    final index = ranking.indexWhere((e) => e.uid == uid);
    if (mounted) {
      setState(() {
        _rankingPosition = index >= 0 ? index + 1 : 0;
        _rankingLoaded = true;
      });
    }
  }

  void _onAvatarTap() {
    if (!kDebugMode) return;

    final userAsync = ref.read(userModelProvider);
    final userService = ref.read(userServiceProvider);
    final user = userAsync.value ?? userService.user;
    
    _avatarTapCount++;

    if (user == null || !user.isAdmin) {
      if (_avatarTapCount >= _triggerTaps) {
        _avatarTapCount = 0;
        SparkSnack.error(context, AppLocalizations.of(context)!.accessDeniedAdminOnly);
      }
      return;
    }

    if (_avatarTapCount < _triggerTaps) {
      final remaining = _triggerTaps - _avatarTapCount;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🔧 Dev: $remaining toque(s) restantes...', style: const TextStyle(color: Colors.white, fontSize: 13)),
        duration: const Duration(milliseconds: 800),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } else {
      _avatarTapCount = 0;
      final isActive = ref.read(devModeProvider);
      ref.read(devModeProvider.notifier).toggle();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(isActive ? Icons.bug_report_outlined : Icons.bug_report, color: isActive ? Colors.grey : Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text(isActive ? AppLocalizations.of(context)!.devModeDisabled : AppLocalizations.of(context)!.devModeEnabled,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
        duration: const Duration(seconds: 3),
        backgroundColor: isActive ? AppColors.card : const Color(0xFF1A1200),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // userServiceProvider = Provider simples (não reconstrói sozinho)
    final userService = ref.watch(userServiceProvider);
    // userModelProvider = StreamProvider — reconstrói quando Firestore responde
    final userAsync = ref.watch(userModelProvider);
    final userModel = userAsync.value;
    // Alias para manter compatibilidade com uso de user?.photoUrl etc.
    final user = userModel ?? userService.user;

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Header ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(AppLocalizations.of(context)!.myProfile,
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => context.push('/settings'),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.settings_outlined, color: AppColors.textMuted, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Avatar + Nome ────────────────────────────────
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: _onAvatarTap,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2.5),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 3)],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
                            clipBehavior: Clip.antiAlias,
                            child: user?.photoUrl != null
                                ? Image.network(
                                    user!.photoUrl!,
                                    fit: BoxFit.cover,
                                    width: 102,
                                    height: 102,
                                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                                    loadingBuilder: (context, child, progress) =>
                                        progress == null
                                            ? child
                                            : const Center(
                                                child: CircularProgressIndicator(color: AppColors.primary),
                                              ),
                                    errorBuilder: (context, error, stack) =>
                                        const Icon(Icons.person, color: AppColors.primary, size: 52),
                                  )
                                : const Icon(Icons.person, color: AppColors.primary, size: 52),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                          // ✅ Nível real do Firestore
                          child: Text('Lvl ${userService.level}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ✅ Nome real do Firestore
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(userService.displayName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            (user?.role ?? AppLocalizations.of(context)!.technicianRole).toUpperCase(),
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PlanBadge(plan: ref.watch(accessControlProvider).plan, compact: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Botão Credencial ─────────────────────────────
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PocketCardScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cardBorder]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.viewCredential,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Stats ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // ✅ Dias ativos reais
                        Expanded(child: _statCard(AppLocalizations.of(context)!.activeDays, '${userService.activeDays}', AppLocalizations.of(context)!.daysLabel, Icons.calendar_today_outlined)),
                        const SizedBox(width: 12),
                        // ✅ Streak atual
                        Expanded(child: _statCard(AppLocalizations.of(context)!.streakLabel, '${userService.currentStreak}', AppLocalizations.of(context)!.streakDaysFire, Icons.local_fire_department)),
                        const SizedBox(width: 12),
                        // ✅ XP real
                        Expanded(child: _statCard(AppLocalizations.of(context)!.experienceLabel, '${userService.xp}', AppLocalizations.of(context)!.xpLabel, Icons.star_border)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Patente PvP (Duelo) ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _pvpRankCard(userService.eloRating),
                  ),
                  const SizedBox(height: 28),

                  // ── Debug Info (Apenas quando Modo Dev está ativo) ──
                  if (kDebugMode && ref.watch(devModeProvider)) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.debugInfoTitle, style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('UID: ${userService.uid}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                            Text('Role Firestore: ${user?.role ?? "Nula"}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            Text('isAdmin Getter: ${user?.isAdmin ?? "false"}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Painel Admin (role == admin) — usa maybeWhen para reagir ao async
                  Builder(builder: (context) {
                    final user = userAsync.value;
                    final isAdmin = (user != null && user.isAdmin);
                    if (!isAdmin) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/admin'),
                              icon: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                              label: Text(
                                AppLocalizations.of(context)!.adminPanel,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8C00),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 4,
                                shadowColor: const Color(0xFFFF8C00).withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  }),

                  // ── Conquistas ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.of(context)!.achievementsTitle,
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                            child: Text(AppLocalizations.of(context)!.seeAll,
                                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 115,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: _buildBadgesList(context, userService.unlockedBadgeIds),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Clã ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ClanSection(
                      clanId: userService.clanId,
                      clanName: userService.clanName,
                      context: context,
                      userService: userService,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Ranking ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context)!.weeklyRankingTitle,
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Center(
                                  child: _rankingLoaded
                                      ? Text(
                                          _rankingPosition > 0 ? '#$_rankingPosition' : '--', // ✅ Posição real
                                          style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800),
                                        )
                                      : const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppLocalizations.of(context)!.globalLeaderboard,
                                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _rankingPosition > 0
                                          ? AppLocalizations.of(context)!.rankingPositionWeek(_rankingPosition)
                                          : AppLocalizations.of(context)!.completeLessonsToEnterRanking,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.trending_up, color: AppColors.primary, size: 26),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói a lista de badges baseada nos IDs desbloqueados no Firestore.
  List<Widget> _buildBadgesList(BuildContext context, List<String> unlockedIds) {
    final widgets = <Widget>[];

    // ✅ Pega apenas as badges desbloqueadas
    final badgesToShow = BadgeRegistry.allBadges.where((b) => unlockedIds.contains(b.id)).toList();

    if (badgesToShow.isEmpty) {
      return [
        Container(
          width: MediaQuery.of(context).size.width - 40,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_outlined, color: AppColors.textMuted, size: 28),
              SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.noAchievementsYet,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.letsLearnAndUnlockRewards,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        )
      ];
    }

    for (int i = 0; i < badgesToShow.length; i++) {
      final badge = badgesToShow[i];
      if (i > 0) widgets.add(const SizedBox(width: 12));
      widgets.add(_badge(badge.title, badge.emoji, true));
    }

    return widgets;
  }

  /// Card da patente do Duelo (PvP). Reaproveita o sistema de patentes
  /// (RankUtils) — mesma fonte de verdade usada no perfil público.
  Widget _pvpRankCard(int elo) {
    final p = RankUtils.fromElo(elo);
    final hint = p.isMaster
        ? 'Patente máxima — topo do ranking.'
        : 'Faltam ${p.eloToNext} de ELO para a próxima.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('PATENTE DUELO',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.color.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_kabaddi, color: p.color, size: 13),
                  const SizedBox(width: 4),
                  Text('PvP',
                      style: TextStyle(
                          color: p.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.color.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(p.icon, color: p.color, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.label,
                            style: TextStyle(
                                color: p.color,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        Text('$elo de ELO',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: p.tierProgress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor:
                        AppColors.background.withValues(alpha: 0.6),
                    valueColor: AlwaysStoppedAnimation(p.color),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(hint,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, String suffix, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 16),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          Text(suffix, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _badge(String label, String emoji, bool active) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withValues(alpha: 0.10) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active ? AppColors.primary.withValues(alpha: 0.35) : AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.primary.withValues(alpha: 0.12) : AppColors.inputBackground,
              border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: active ? Colors.white : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Seção Clã com dados reais ───────────────────────────────────
class _ClanSection extends StatelessWidget {
  final String? clanId;
  final String? clanName;
  final BuildContext context;
  final UserService userService;

  const _ClanSection({
    required this.clanId,
    required this.clanName,
    required this.context,
    required this.userService,
  });

  @override
  Widget build(BuildContext ctx) {
    // ✅ Usa clanId real do Firestore
    final hasClan = clanId != null && clanId!.isNotEmpty;

    if (!hasClan) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.clanTitle,
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.shield_moon, size: 40, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.joinAClan,
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context)!.clanDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClanScreen(isCreating: true))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Text(AppLocalizations.of(context)!.createClanUpper,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClanScreen(isCreating: false))),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(AppLocalizations.of(context)!.enterUpper,
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.myClanTitle,
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.primary, width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Nome do clã real do Firestore
                        Text(clanName ?? AppLocalizations.of(context)!.myClanFallback,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(AppLocalizations.of(context)!.clanMemberRole, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClanScreen(isViewingActive: true)),
                  ),
                  icon: const Icon(Icons.groups, size: 18, color: Colors.white),
                  label: Text(AppLocalizations.of(context)!.viewClanUpper,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
