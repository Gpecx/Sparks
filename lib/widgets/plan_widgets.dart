import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/services/access_control_service.dart';
import 'package:spark_app/services/analytics_service.dart';

// ─────────────────────────────────────────────────────────────────
//  COMPONENTES DE PLANO / UPGRADE (reutilizáveis) — PDF §5
// ─────────────────────────────────────────────────────────────────

/// Selo do plano atual (Free, Pro, Premium, Student, Business).
class PlanBadge extends StatelessWidget {
  final UserPlan plan;
  final bool compact;
  const PlanBadge({super.key, required this.plan, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (plan) {
      UserPlan.free => ('FREE', const Color(0xFF6B7280), Icons.explore_outlined),
      UserPlan.pro => ('PRO', AppColors.primary, Icons.workspace_premium_outlined),
      UserPlan.premium => ('PREMIUM', AppColors.gold, Icons.diamond_outlined),
      UserPlan.student => ('STUDENT', const Color(0xFF3B82F6), Icons.school_outlined),
      UserPlan.business => ('BUSINESS', const Color(0xFF8B5CF6), Icons.business_outlined),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 12 : 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner pequeno com cadeado + CTA de upgrade.
class LockedFeatureBanner extends StatelessWidget {
  final String message;
  final String? feature;
  final String? trigger;
  const LockedFeatureBanner({
    super.key,
    required this.message,
    this.feature,
    this.trigger,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => UpgradePromptBottomSheet.show(
        context,
        feature: feature,
        trigger: trigger,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Upgrade',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Contador de trial (mostrar no topo da home durante o trial).
class TrialCountdown extends ConsumerWidget {
  const TrialCountdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessControlProvider);
    if (!access.isOnTrial) return const SizedBox.shrink();
    final days = access.trialDaysRemaining;
    return GestureDetector(
      onTap: () => context.push('/store'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.primary.withValues(alpha: 0.08),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                days > 0
                    ? 'Trial Pro ativo — ${days == 1 ? '1 dia restante' : '$days dias restantes'}'
                    : 'Seu trial Pro termina hoje',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Text(
              'Gerenciar',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet padronizado de upgrade (PDF §5 — UpgradePromptBottomSheet).
class UpgradePromptBottomSheet {
  static Future<void> show(
    BuildContext context, {
    String? feature,
    String? trigger,
  }) {
    HapticFeedback.mediumImpact();
    AnalyticsService().logUpgradePromptShown(trigger: trigger);
    final message = AccessControl.fromUser(null).upgradeMessageFor(feature ?? '');
    var clicked = false;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UpgradeSheet(
        message: message,
        onUpgrade: () {
          clicked = true;
          AnalyticsService().logUpgradePromptClicked(trigger: trigger);
        },
      ),
    ).then((_) {
      if (!clicked) AnalyticsService().logUpgradePromptDismissed();
    });
  }
}

class _UpgradeSheet extends StatelessWidget {
  final String message;
  final VoidCallback onUpgrade;
  const _UpgradeSheet({required this.message, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.primary.withValues(alpha: 0.3),
                AppColors.primary.withValues(alpha: 0.05),
              ]),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 18),
          const Text(
            'Recurso exclusivo do Pro',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _cta(
            label: 'INICIAR TRIAL DE 7 DIAS',
            primary: true,
            onTap: () {
              onUpgrade();
              Navigator.pop(context);
              context.push('/store');
            },
          ),
          const SizedBox(height: 10),
          _cta(
            label: 'Ver planos',
            primary: false,
            onTap: () {
              onUpgrade();
              Navigator.pop(context);
              context.push('/store');
            },
          ),
        ],
      ),
    );
  }

  Widget _cta({
    required String label,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: primary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primary ? AppColors.surfaceAlt : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
