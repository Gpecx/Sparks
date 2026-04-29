import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/achievements_screen.dart';
import 'package:spark_app/screens/clan_screen.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/controllers/energy_controller.dart';
import 'package:spark_app/screens/pocket_card_screen.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';
import 'package:spark_app/providers/user_provider.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/models/badge_model.dart';
import 'package:spark_app/scripts/seed_curriculum.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final EnergyController _energyCtrl = EnergyController();

  int _avatarTapCount = 0;
  static const int _triggerTaps = 7;

  // Posição no ranking (carregada de forma assíncrona)
  int _rankingPosition = 0;
  bool _rankingLoaded = false;
  bool _seeding = false;

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

  /// Executa o seed de lições + questões no Firestore (somente kDebugMode).
  /// Também aplica um AUTO-FIX na conta do usuário, transformando-o em admin
  /// e corrigindo o bug da conta "fantasma" / "Usuário".
  Future<void> _runSeed() async {
    if (_seeding) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Confirmar Auto-Fix + Seed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          '1. Isso aplicará um FIX na sua conta atual (recuperando seu usuário fantasma e te dando permissão de admin).\n\n'
          '2. Em seguida, vai popular o Firestore com as lições.\n\nExecute apenas UMA VEZ.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('⚡ EXECUTAR FIX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _seeding = true);
    try {
      // ── AUTO-FIX DA CONTA "FANTASMA" ──
      // Pega o Auth UID do celular e FORÇA a criação do documento dele com role=admin
      final auth = FirebaseAuth.instance.currentUser;
      if (auth != null) {
        await FirebaseFirestore.instance.collection('users').doc(auth.uid).set({
          'uid': auth.uid,
          'displayName': 'Admin Supremo', // Substitui o nome de "Usuario" para confirmar que arrumou
          'email': auth.email ?? '',
          'role': 'admin',
          'sparkPoints': 9999, // Presente pra confirmar que atualizou!
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[AutoFix] Conta corrigida e promovida para admin!');
        
        // Dá 2 segundos para as regras do Firestore processarem a mudança
        await Future.delayed(const Duration(seconds: 2));
      }

      await seedLessonsAndQuestions(catId: 'capacitacao_tecnica');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Fix + Seed concluído com sucesso!', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF00C402),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Erro no seed: $e', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _onAvatarTap() {
    if (!kDebugMode) return;
    _avatarTapCount++;

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
          Text(isActive ? '🔒 Modo Dev DESATIVADO' : '🔓 Modo Dev ATIVADO — Tudo desbloqueado!',
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
    // ✅ Observa UserService reativamente
    final userService = ref.watch(userServiceProvider);
    final user = userService.user;

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
                        const Expanded(
                          child: Text('MEU PERFIL',
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
                                ? CachedNetworkImage(
                                    imageUrl: user!.photoUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(color: AppColors.primary),
                                    ),
                                    errorWidget: (context, url, error) =>
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
                  Text(userService.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    (user?.role ?? 'TÉCNICO').toUpperCase(),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5),
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
                          gradient: const LinearGradient(colors: [Color(0xFF00C402), Color(0xFF1D5F31)]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: const Color(0xFF00C402).withValues(alpha: 0.3), blurRadius: 10)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('VER CREDENCIAL',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Pontos Spark ─────────────────────────────────
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => context.push('/store'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt, color: AppColors.primary, size: 18),
                            const SizedBox(width: 6),
                            // ✅ Spark Points reais do Firestore
                            Text('${userService.sparkPoints} Pontos Spark',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(width: 8),
                            const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 16),
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
                        Expanded(child: _statCard('Dias Ativos', '${userService.activeDays}', 'dias', Icons.calendar_today_outlined)),
                        const SizedBox(width: 12),
                        // ✅ Streak atual
                        Expanded(child: _statCard('Streak', '${userService.currentStreak}', 'dias 🔥', Icons.local_fire_department)),
                        const SizedBox(width: 12),
                        // ✅ XP real
                        Expanded(child: _statCard('Experiência', '${userService.xp}', 'XP', Icons.star_border)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Dev Tools (somente debug) ────────────────────
                  if (kDebugMode) ...[  
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('DEV TOOLS', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _seeding ? null : _runSeed,
                          icon: _seeding
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                              : const Icon(Icons.bolt, color: AppColors.primary, size: 18),
                          label: Text(
                            _seeding ? 'Populando Firestore...' : '⚡ SEED FIRESTORE',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Conquistas ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CONQUISTAS',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                            child: const Text('Ver Tudo ↗',
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
                      children: _buildBadgesList(userService.unlockedBadgeIds),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Meu Clã ───────────────────────────────────────
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

                  // ── Ranking ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RANKING SEMANAL',
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
                                    const Text('Placar Global',
                                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _rankingPosition > 0
                                          ? 'Você está em ${_rankingPosition}º lugar esta semana'
                                          : 'Complete lições para entrar no ranking',
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
  List<Widget> _buildBadgesList(List<String> unlockedIds) {
    final widgets = <Widget>[];

    // Mapeia as badges do registro com o estado real do Firestore
    final badgesToShow = BadgeRegistry.allBadges.take(4).toList();

    for (int i = 0; i < badgesToShow.length; i++) {
      final badge = badgesToShow[i];
      // ✅ Verifica se está desbloqueada no Firestore
      final isUnlocked = unlockedIds.contains(badge.id);

      if (i > 0) widgets.add(const SizedBox(width: 12));
      widgets.add(_badge(badge.title, badge.emoji, isUnlocked));
    }

    return widgets;
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
          Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(suffix, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
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
          const Text('CLÃ',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ClanScreen(isCreating: true))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('CRIAR CLÃ',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ClanScreen(isCreating: false))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('ENTRAR',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
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
        const Text('MEU CLÃ',
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
                        Text(clanName ?? 'Meu Clã',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Membro', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                  label: const Text('VISUALIZAR CLÃ',
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