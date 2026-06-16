import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/spark_card.dart';
import 'package:spark_app/widgets/spark_skeleton.dart';
import 'package:spark_app/screens/main_shell_screen.dart';
import 'package:spark_app/screens/settings_screen.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/achievements_screen.dart';
import 'package:spark_app/services/covenant_service.dart';
import 'package:spark_app/services/auth_service.dart';
import 'package:spark_app/services/user_service.dart';

import 'package:spark_app/models/progress_model.dart';
import 'package:spark_app/providers/user_provider.dart';
import 'package:spark_app/providers/progress_provider.dart';
import 'package:spark_app/services/notification_service.dart';
import 'package:spark_app/models/spark_admin_models.dart';
import 'package:spark_app/providers/content_providers.dart';
import 'package:spark_app/models/user_model.dart';
import 'package:spark_app/core/utils/gamification_utils.dart';
import 'package:spark_app/widgets/plan_widgets.dart';
// ─────────────────────────────────────────────────────────────────
//  DASHBOARD — Versão com Firebase
//  MUDANÇAS:
//  - Saudação usa displayName do UserService (Firestore)
//  - Streak lê do UserService (persistido)
//  - "Continue Aprendendo" usa getLastActiveModule() real
//  - Pactos Semanais lêem progress do Firestore
//  - Level, XP e Spark Points vêm do Firestore
// ─────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    CovenantService().addListener(_onCovenantUpdate);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    CovenantService().removeListener(_onCovenantUpdate);
    super.dispose();
  }

  void _onCovenantUpdate() {
    if (mounted) setState(() {});
  }

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  void _showProfileMenu(UserModel? userModel) {
    final userService = ref.read(userServiceProvider);
    final displayName = userModel?.displayName ?? userService.displayName;
    final photoUrl = userModel?.photoUrl ?? userService.user?.photoUrl;
    final email = userModel?.email ?? userService.user?.email ?? '';
    final role = userModel?.role ?? userService.user?.role ?? 'Técnico';
    final isAdmin = userModel?.isAdmin ?? userService.user?.isAdmin ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: ClipOval(
                        child: photoUrl != null
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                                errorBuilder: (_, _, _) => Container(
                                  color: AppColors.surface,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.person, color: AppColors.accent, size: 30),
                                ),
                              )
                            : Container(
                                color: AppColors.surface,
                                alignment: Alignment.center,
                                child: const Icon(Icons.person, color: AppColors.accent, size: 30),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role,
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: AppColors.cardBorder.withValues(alpha: 0.5), height: 1),
              _buildProfileMenuItem(
                icon: Icons.person_outline,
                label: 'Meu Perfil',
                onTap: () {
                  Navigator.pop(ctx);
                  final shell = context.findAncestorStateOfType<MainShellScreenState>();
                  shell?.switchTab(5);
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.settings_outlined,
                label: 'Configurações',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              if (isAdmin)
                _buildProfileMenuItem(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Painel Admin',
                  color: const Color(0xFFFF8C00),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/admin');
                  },
                ),
              _buildProfileMenuItem(
                icon: Icons.emoji_events_outlined,
                label: 'Minhas Conquistas',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()));
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.trending_up,
                label: 'Meu Progresso',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/my-progress');
                },
              ),
              _buildProfileMenuItem(
                icon: Icons.help_outline,
                label: 'Ajuda / Suporte',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/support');
                },
              ),
              Divider(color: AppColors.cardBorder.withValues(alpha: 0.5), height: 1),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text('NOVAS MECÂNICAS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              // PvP — Duelo de Faíscas (liberado para todos os usuários)
              _buildProfileMenuItem(
                icon: Icons.flash_on,
                label: 'Duelo de Faíscas (PvP)',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/duel');
                },
              ),
              Divider(color: AppColors.cardBorder.withValues(alpha: 0.5), height: 1),
              _buildProfileMenuItem(
                icon: Icons.logout,
                label: 'Sair',
                color: AppColors.error,
                onTap: () async {
                  Navigator.pop(ctx);
                  await AuthService().signOut();
                  UserService().stopListening();
                  if (mounted) context.go('/');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final itemColor = color ?? Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: itemColor.withValues(alpha: 0.8), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: itemColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: itemColor.withValues(alpha: 0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, [VoidCallback? onSeeAll]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        if (onSeeAll != null)
          _ResponsiveTapWidget(
            onTap: onSeeAll,
            child: const Row(
              children: [
                Text('Ver todas', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 12),
              ],
            ),
          ),
      ],
    );
  }

  // ── Banner de Trial Ativo ────────────────────────────────────────
  // ── Header com nome real do Firestore ───────────────────────────
  Widget _buildHeader(UserModel? userModel) {
    final userService = ref.watch(userServiceProvider);
    final displayName = userModel?.displayName ?? userService.displayName;
    final firstName = displayName.split(' ').first;
    final photoUrl = userModel?.photoUrl ?? userService.user?.photoUrl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getDynamicGreeting()},',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              Text(
                '$firstName!',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            _buildNotificationBell(),
            const SizedBox(width: 16),
            _ResponsiveTapWidget(
              onTap: () => _showProfileMenu(userModel),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          width: 46,
                          height: 46,
                          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.person, color: AppColors.textSecondary, size: 24),
                        ),
                      )
                    : const Icon(Icons.person, color: AppColors.textSecondary, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationBell() {
    final notificationService = ref.watch(notificationServiceProvider);

    return ListenableBuilder(
      listenable: notificationService,
      builder: (context, child) {
        final unreadCount = notificationService.unreadCount;
        return _ResponsiveTapWidget(
          onTap: () => _showNotificationBottomSheet(notificationService),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(color: AppColors.background, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationBottomSheet(NotificationService service) {
    final uid = ref.read(userServiceProvider).user?.uid;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Notificações', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        if (service.unreadCount > 0)
                          TextButton(
                            onPressed: () {
                              service.markAllRead(uid);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Marcar todas como lidas', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(color: AppColors.cardBorder.withValues(alpha: 0.5), height: 1),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final service = ref.watch(notificationServiceProvider);
                        return ListenableBuilder(
                          listenable: service,
                          builder: (context, child) {
                            final notifs = service.notifications;
                            if (notifs.isEmpty) {
                              return const Center(
                                child: Text('Nenhuma notificação no momento.', style: TextStyle(color: AppColors.textMuted)),
                              );
                            }
                            return ListView.builder(
                              controller: scrollController,
                              itemCount: notifs.length,
                              itemBuilder: (context, index) {
                                final notif = notifs[index];
                                return Dismissible(
                                  key: Key(notif.id),
                                  background: Container(
                                    color: AppColors.error,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) => service.deleteNotification(uid, notif.id),
                                  child: ListTile(
                                    onTap: () {
                                      if (!notif.read) service.markAsRead(uid, notif.id);
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: notif.read ? AppColors.surface : AppColors.primary.withValues(alpha: 0.2),
                                      child: Text(notif.emoji, style: const TextStyle(fontSize: 18)),
                                    ),
                                    title: Text(
                                      notif.title,
                                      style: TextStyle(
                                        color: notif.read ? AppColors.textSecondary : Colors.white,
                                        fontWeight: notif.read ? FontWeight.w400 : FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      notif.body,
                                      style: TextStyle(
                                        color: AppColors.textSecondary.withValues(alpha: notif.read ? 0.6 : 1),
                                      ),
                                    ),
                                    trailing: notif.read ? null : const Icon(Icons.circle, color: AppColors.primary, size: 10),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userModelProvider);
    final userModel = userAsync.value;

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(userModel),
                  const SizedBox(height: 16),
                  if (userModel?.isOnTrial == true) const TrialCountdown(),
                  const SizedBox(height: 16),
                  _buildGamificationCenter(userModel),
                  const SizedBox(height: 16),
                  _ResponsiveTapWidget(
                    onTap: () {
                      final shell = context.findAncestorStateOfType<MainShellScreenState>();
                      shell?.switchTab(1);
                    },
                    child: _buildContinueLearningCard(),
                  ),
                  const SizedBox(height: 40),
                  _buildSectionHeader('Pactos Semanais', () => context.push('/covenants')),
                  const SizedBox(height: 16),
                  _isLoading ? _buildCovenantSkeleton() : _buildCovenantList(),
                  const SizedBox(height: 40),
                  _buildSectionHeader('Módulos em Destaque'),
                  const SizedBox(height: 16),
                  _isLoading ? _buildModulesSkeleton() : _buildTopModulesList(context),
                  const SizedBox(height: 40),
                  _buildPowerplayBanner(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Skeletons ───────────────────────────────────────────────────
  Widget _buildCovenantSkeleton() {
    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: 2,
        separatorBuilder: (ctx, index) => const SizedBox(width: 16),
        itemBuilder: (ctx, index) => const SparkSkeleton(width: 280, height: 145),
      ),
    );
  }

  Widget _buildModulesSkeleton() {
    return SizedBox(
      height: 165,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: 3,
        separatorBuilder: (ctx, index) => const SizedBox(width: 16),
        itemBuilder: (ctx, index) => const SparkSkeleton(width: 140, height: 165),
      ),
    );
  }

  // ── Gamification Center com dados reais ─────────────────────────
  Widget _buildGamificationCenter(UserModel? userModel) {
    final userService = ref.watch(userServiceProvider);
    final streak = userModel?.currentStreak ?? userService.currentStreak;
    final level = userModel?.level ?? userService.level;
    final xp = userModel?.xp ?? userService.xp;
    final multiplier = userModel != null ? GamificationUtils.xpMultiplier(streak) : userService.xpMultiplier;

    // A cada 500 XP sobe um nível
    final int xpInCurrentLevel = xp % 500;
    final double progress = xpInCurrentLevel / 500.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seu Progresso',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Técnico Nível $level',
                      style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ResponsiveTapWidget(
                onTap: () {
                  SparkSnack.success(context, '🔥 Streak de $streak dias! Multiplicador de ${multiplier}x.');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: AppColors.gold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$streak Dias',
                        style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Barra Física de Progresso de XP ──
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFF141414),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$xpInCurrentLevel / 500 XP',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Rótulo descritivo do XP total
          Text(
            'XP Total: $xp XP',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.cardBorder, height: 1),
          ),
          // Desafio Diário — Em Breve
          Builder(
            builder: (context) {
              final isAdmin = userModel?.isAdmin ?? userService.user?.isAdmin ?? false;
              if (isAdmin) {
                return _ResponsiveTapWidget(
                  onTap: () {
                    SparkSnack.info(context, 'Desafio Diário: Em desenvolvimento (Acesso Admin)');
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.timer, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Desafio Diário', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            Text('Acesso Teste Admin', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 14),
                    ],
                  ),
                );
              }
              return Opacity(
                opacity: 0.45,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer, color: Colors.grey, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Desafio Diário', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w700)),
                          Text('Em breve...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: const Text('EM BREVE', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ),
                  ],
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  // ── Continue Aprendendo com dados reais (ProgressService) ───────
  Widget _buildContinueLearningCard() {
    final userProgressAsync = ref.watch(userProgressProvider);
    
    return userProgressAsync.when(
      loading: () => const SparkSkeleton(width: double.infinity, height: 120),
      error: (e, st) => const SizedBox(height: 120, child: Center(child: Text('Erro ao carregar progresso', style: TextStyle(color: AppColors.error)))),
      data: (list) {
        if (list.isEmpty) return _buildContinueLearningContent(null);
        
        final incomplete = list.where((p) => !p.isCompleted).toList()
          ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
        final lastModule = incomplete.isNotEmpty ? incomplete.first : list.last;
        
        return _buildContinueLearningContent(lastModule);
      },
    );
  }

  Widget _buildContinueLearningContent(ProgressModel? lastModule) {
    final moduleName = lastModule != null
        ? lastModule.moduleName.isNotEmpty
            ? lastModule.moduleName
            : 'Módulo ${lastModule.moduleId.split('_').last}'
        : 'Nenhum módulo iniciado';
    final moduleSubtitle = lastModule != null
        ? '${lastModule.completedLessons.length} lição(ões) concluída(s)'
        : 'Acesse o Caminho de Aprendizado para começar';
    final progress = lastModule?.progressPercent ?? 0.0;
    final progressText = lastModule != null ? '${(progress * 100).toInt()}%' : '';

    return SparkCard(
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue Aprendendo',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moduleName,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      moduleSubtitle,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: progress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        backgroundColor: AppColors.inputBackground,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                progressText,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDailyChallengeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.timer, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Desafio Diário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teste seus conhecimentos em NR-10! Complete 3 perguntas rápidas para receber recompensas.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [Text('💰 +50 XP', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)), Text('Recompensa', style: TextStyle(color: AppColors.textMuted, fontSize: 10))]),
                  Column(children: [Text('⏱️ 3 min', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)), Text('Tempo Est.', style: TextStyle(color: AppColors.textMuted, fontSize: 10))]),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('AGORA NÃO', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              SparkSnack.info(context, 'Iniciando desafio diário...');
            },
            child: const Text('INICIAR DESAFIO', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Covenant List com dados reais da subcoleção ─────────────────
  Widget _buildCovenantList() {
    // CovenantService já sincroniza com users/{uid}/covenants em tempo real
    final covenants = CovenantService().activeCovenants;

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: covenants.isEmpty ? 1 : covenants.length,
        separatorBuilder: (ctx, index) => const SizedBox(width: 16),
        itemBuilder: (ctx, index) {
          if (covenants.isEmpty) {
            return Container(
              width: 280,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.textMuted, size: 28),
                  const SizedBox(height: 8),
                  const Text('Nenhum Pacto Ativo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Expanded(
                    child: Text(
                      'Vá até a aba Pactos para criar o compromisso!', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => context.push('/covenants'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('ACEITAR PACTO', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700, fontSize: 11)),
                  )
                ],
              ),
            );
          }
          final cov = covenants[index];

          // ✅ Progresso já sincronizado pelo CovenantService (subcoleção)
          final realProgress = cov.currentProgress;
          final progressPercent = cov.maxProgress > 0 ? realProgress / cov.maxProgress : 0.0;
          final isCompleted = realProgress >= cov.maxProgress;

          return Container(
            width: 280,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : AppColors.cardBorder.withValues(alpha: 0.5),
              ),
              boxShadow: isCompleted
                  ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 1)]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isCompleted ? Icons.check_circle : Icons.commit,
                            color: isCompleted ? AppColors.gold : AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              cov.title,
                              style: TextStyle(
                                color: isCompleted ? AppColors.gold : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(cov.reward, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    cov.objective,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(3)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progressPercent.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCompleted ? AppColors.gold : AppColors.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$realProgress/${cov.maxProgress} ${cov.trackingType}', // ✅ Progresso real
                      style: TextStyle(
                        color: isCompleted ? AppColors.gold : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopModulesList(BuildContext context) {
    final asyncModules = ref.watch(topModulesStreamProvider);

    return asyncModules.when(
      data: (modules) {
        if (modules.isEmpty) {
          return SparkCard(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_mosaic_outlined, color: AppColors.textMuted, size: 28),
                SizedBox(height: 8),
                Text(
                  'Nenhum módulo em destaque no momento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Continue explorando para descobrir novos conteúdos!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final top3Modules = modules.take(3).toList();

        return SizedBox(
          height: 165,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: top3Modules.length,
            separatorBuilder: (_, index) => const SizedBox(width: 16),
            itemBuilder: (ctx, i) {
              final m = top3Modules[i];
              return SizedBox(
                width: 140,
                child: _buildTopModuleCard(context, m),
              );
            },
          ),
        );
      },
      loading: () => _buildModulesSkeleton(),
      error: (err, stack) => SizedBox(
        height: 165,
        child: Center(
          child: Text('Erro ao carregar módulos', style: TextStyle(color: Colors.red.shade300)),
        ),
      ),
    );
  }

  Widget _buildTopModuleCard(BuildContext context, SPARKModule module) {
    return _ResponsiveTapWidget(
      onTap: () {
        context.push('/module/${module.categoryId}/${module.id}');
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.star, color: AppColors.primary, size: 24),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  module.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (module.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    module.subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildPowerplayBanner() {
    return _ResponsiveTapWidget(
      onTap: () => context.push('/standard-detail'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.background, AppColors.card],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1)],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cardBorder], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)],
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PowerPlay Streaming', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Vídeos técnicos e conteúdos exclusivos para seu aprendizado',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cardBorder]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Saiba mais', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Responsive Tap Widget ────────────────────────────────────────
class _ResponsiveTapWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ResponsiveTapWidget({required this.child, required this.onTap});

  @override
  State<_ResponsiveTapWidget> createState() => _ResponsiveTapWidgetState();
}

class _ResponsiveTapWidgetState extends State<_ResponsiveTapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.7).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Opacity(
            opacity: _opacityAnim.value,
            child: Transform.scale(scale: _scaleAnim.value, child: child),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
