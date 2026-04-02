import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/achievements_screen.dart';
import 'package:spark_app/screens/clan_screen.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/controllers/energy_controller.dart';
import 'package:spark_app/screens/pocket_card_screen.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Tela de Perfil do usuário.
///
/// 🔒 Easter egg: 7 toques rápidos no avatar ativam/desativam o Modo Dev.
/// Funciona apenas em kDebugMode.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final EnergyController _energyCtrl = EnergyController();

  // ── Trigger oculto: 7 toques no avatar ──────────────────────
  int _avatarTapCount = 0;
  static const int _triggerTaps = 7;

  void _onAvatarTap() {
    if (!kDebugMode) return;

    _avatarTapCount++;

    // Feedback tátil a cada toque
    if (_avatarTapCount < _triggerTaps) {
      final remaining = _triggerTaps - _avatarTapCount;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔧 Dev: $remaining toque(s) restantes...',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          duration: const Duration(milliseconds: 800),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      // Ativação!
      _avatarTapCount = 0;
      final isActive = ref.read(devModeProvider);
      ref.read(devModeProvider.notifier).toggle();

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isActive ? Icons.bug_report_outlined : Icons.bug_report,
                color: isActive ? Colors.grey : Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isActive
                    ? '🔒 Modo Dev DESATIVADO'
                    : '🔓 Modo Dev ATIVADO — Tudo desbloqueado!',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: isActive ? AppColors.card : const Color(0xFF1A1200),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          child: Text(
                            'MEU PERFIL',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2),
                          ),
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

                  // ── Avatar + Nome ───────────────────────────────
                  // 🔒 Easter egg: 7 toques aqui ativam o Modo Dev
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
                            child: CachedNetworkImage(
                              imageUrl: 'https://i.pravatar.cc/150?img=11',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                              errorWidget: (context, url, error) => const Icon(Icons.person, color: AppColors.primary, size: 52),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: -8,
                        child: ListenableBuilder(
                          listenable: _energyCtrl,
                          builder: (context, _) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                              child: Text('Lvl ${_energyCtrl.userLevel}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                            );
                          }
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Alex Rodriguez', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'TÉCNICO LÍDER',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5),
                  ),
                  const SizedBox(height: 14),

                  // 👇 Botão Credencial
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PocketCardScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C402), Color(0xFF1D5F31)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C402).withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'VER CREDENCIAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 14),

                  // ── Pontos Spark ────────────────────────────────
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
                      child: ListenableBuilder(
                        listenable: _energyCtrl,
                        builder: (context, _) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt, color: AppColors.primary, size: 18),
                              const SizedBox(width: 6),
                              Text('${_energyCtrl.sparkPoints} Pontos Spark', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: 8),
                              const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 16),
                            ],
                          );
                        }
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 28),

                  // ── Stats ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListenableBuilder(
                      listenable: _energyCtrl,
                      builder: (context, _) {
                        return Row(
                          children: [
                            Expanded(child: _statCard('Dias Ativos', '42', 'dias', Icons.calendar_today_outlined)),
                            const SizedBox(width: 12),
                            Expanded(child: _statCard('Taxa de Acerto', '94', '%', Icons.gps_fixed)),
                            const SizedBox(width: 12),
                            Expanded(child: _statCard('Experiência', '${_energyCtrl.xp}', 'XP', Icons.star_border)),
                          ],
                        );
                      }
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Conquistas ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CONQUISTAS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                            child: const Text('Ver Tudo ↗', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
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
                      children: [
                        _badge('Mestre\nNR-10', Icons.electrical_services, true),
                        const SizedBox(width: 12),
                        _badge('Expert\nNFPA 70E', Icons.shield_outlined, false),
                        const SizedBox(width: 12),
                        _badge('Pro em\nSegurança', Icons.verified_outlined, false),
                        const SizedBox(width: 12),
                        _badge('Streak\n7 dias', Icons.local_fire_department, true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Meu Clã ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ClanSection(context: context),
                  ),
                  const SizedBox(height: 28),

                  // ── Ranking ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RANKING SEMANAL', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
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
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(child: Text('#3', style: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800))),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Placar Global', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                    SizedBox(height: 4),
                                    Text('Top 5% dos técnicos desta semana', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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

  Widget _badge(String label, IconData icon, bool active) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withValues(alpha: 0.10) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.35) : AppColors.cardBorder.withValues(alpha: 0.3)),
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
            child: Icon(icon, color: active ? AppColors.primary : AppColors.textMuted, size: 20),
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

// ── Seção Meu Clã ──────────────────────────────────────────────
class _ClanSection extends StatefulWidget {
  final BuildContext context;
  const _ClanSection({required this.context});

  @override
  State<_ClanSection> createState() => _ClanSectionState();
}

class _ClanSectionState extends State<_ClanSection> {
  bool _hasClan = true;

  @override
  Widget build(BuildContext context) {
    if (!_hasClan) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CLÃ', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
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
                    onPressed: () => Navigator.push(widget.context, MaterialPageRoute(builder: (_) => const ClanScreen(isCreating: true))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('CRIAR CLÃ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(widget.context, MaterialPageRoute(builder: (_) => const ClanScreen(isCreating: false))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('ENTRAR', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mock: com clã ativo
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MEU CLÃ', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXS Técnicos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Membro · 5 membros', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final deleted = await Navigator.push(widget.context, MaterialPageRoute(builder: (_) => const ClanScreen(isViewingActive: true)));
                    if (deleted == true && mounted) {
                      setState(() => _hasClan = false);
                    }
                  },
                  icon: const Icon(Icons.groups, size: 18, color: Colors.white),
                  label: const Text('VISUALIZAR CLÃ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white)),
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