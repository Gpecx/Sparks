import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/core/utils/currency_utils.dart';
import 'package:spark_app/screens/checkout_screen.dart';
import 'package:spark_app/screens/main_shell_screen.dart';
import 'package:spark_app/screens/trial_checkout_screen.dart';
import 'package:spark_app/providers/user_provider.dart';
import 'package:spark_app/services/analytics_service.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void add(CartItem item) {
    state = [...state, item];
  }

  void clear() {
    state = [];
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

// ─── Modelos de Plano ───────────────────────────────────────────────────────

class SubscriptionPlan {
  final String id;
  final String name;
  final String subtitle;
  final double monthlyPrice;
  final double? annualPrice;
  final String annualLabel;
  final String targetAudience;
  final List<String> features;
  final IconData icon;
  final Color accentColor;
  final bool highlighted;
  final bool perUser;
  final int? minUsers;
  final String? badge;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.monthlyPrice,
    this.annualPrice,
    this.annualLabel = '',
    required this.targetAudience,
    required this.features,
    required this.icon,
    required this.accentColor,
    this.highlighted = false,
    this.perUser = false,
    this.minUsers,
    this.badge,
  });
}

List<SubscriptionPlan> subscriptionPlans(BuildContext context) => [
  SubscriptionPlan(
    id: 'free',
    name: 'SPARK Free',
    subtitle: AppLocalizations.of(context)!.storeStartJourney,
    monthlyPrice: 0,
    targetAudience: 'Curioso / experimentador',
    icon: Icons.explore_outlined,
    accentColor: Color(0xFF6B7280),
    features: [
      AppLocalizations.of(context)!.storeFeatBasicModules,
      AppLocalizations.of(context)!.storeFeatLimitedBattery,
      AppLocalizations.of(context)!.storeFeatPublicRanking,
      AppLocalizations.of(context)!.storeFeatBasicAchievements,
    ],
  ),
  SubscriptionPlan(
    id: 'student',
    name: 'SPARK Student',
    subtitle: AppLocalizations.of(context)!.storePlanForStudents,
    monthlyPrice: 19.90,
    annualPrice: 199,
    annualLabel: AppLocalizations.of(context)!.storeSave17,
    targetAudience: 'Estudante (com comprovação)',
    icon: Icons.school_outlined,
    accentColor: Color(0xFF3B82F6),
    features: [
      AppLocalizations.of(context)!.storeFeatAllFree,
      AppLocalizations.of(context)!.storeFeatInfiniteBattery,
      AppLocalizations.of(context)!.storeFeatIntermediateModules,
      AppLocalizations.of(context)!.storeFeatChatSupport,
      AppLocalizations.of(context)!.storeFeatEnrollmentProof,
    ],
    badge: AppLocalizations.of(context)!.storeBadgeAffordable,
  ),
  SubscriptionPlan(
    id: 'pro',
    name: 'SPARK Pro',
    subtitle: AppLocalizations.of(context)!.storePlanForIndividuals,
    monthlyPrice: 39.90,
    annualPrice: 399,
    annualLabel: AppLocalizations.of(context)!.storeSave17,
    targetAudience: 'Profissional individual',
    icon: Icons.workspace_premium_outlined,
    accentColor: AppColors.primary,
    highlighted: true,
    features: [
      AppLocalizations.of(context)!.storeFeatAllStudent,
      AppLocalizations.of(context)!.storeFeatInfiniteBattery,
      AppLocalizations.of(context)!.storeFeatAllModulesUnlocked,
      AppLocalizations.of(context)!.storeFeatPvpDuels,
      AppLocalizations.of(context)!.storeFeatDigitalCertificates,
      AppLocalizations.of(context)!.storeFeatPrioritySupport,
    ],
    badge: AppLocalizations.of(context)!.storeBadgeMostPopular,
  ),
  SubscriptionPlan(
    id: 'premium',
    name: 'SPARK Premium',
    subtitle: AppLocalizations.of(context)!.storePlanForSeniors,
    monthlyPrice: 79.90,
    annualPrice: 799,
    annualLabel: AppLocalizations.of(context)!.storeSave17,
    targetAudience: 'Sênior / consultor',
    icon: Icons.diamond_outlined,
    accentColor: AppColors.gold,
    features: [
      AppLocalizations.of(context)!.storeFeatAllPro,
      AppLocalizations.of(context)!.storeFeatInfiniteBattery,
      AppLocalizations.of(context)!.storeFeatExclusiveAdvanced,
      AppLocalizations.of(context)!.storeFeatMonthlyMentoring,
      AppLocalizations.of(context)!.storeFeatEarlyAccess,
    ],
    badge: AppLocalizations.of(context)!.storeBadgePremium,
  ),
  SubscriptionPlan(
    id: 'business',
    name: 'SPARK Business',
    subtitle: AppLocalizations.of(context)!.storePlanForBusiness,
    monthlyPrice: 29,
    annualPrice: null,
    annualLabel: AppLocalizations.of(context)!.storeBilledAnnual,
    targetAudience: 'Empresas e consultorias',
    icon: Icons.business_outlined,
    accentColor: Color(0xFF8B5CF6),
    perUser: true,
    minUsers: 5,
    features: [
      AppLocalizations.of(context)!.storeFeatAllPremiumPerUser,
      AppLocalizations.of(context)!.storeFeatInfiniteBatteryAll,
    ],
    badge: AppLocalizations.of(context)!.storeBadgeBusiness,
  ),
];

// ─── Tela da Loja ───────────────────────────────────────────────────────────

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnnual = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    AnalyticsService().logPricingViewed();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // URL do app web do Spark (rota hash do GoRouter). Em mobile, a assinatura é
  // concluída aqui, no navegador, para cumprir a política do Google Play (bem
  // digital não pode ser cobrado por gateway externo dentro do app). Na web o
  // checkout in-app é mantido.
  static const String _webSubscribeUrl =
      'https://site-pv4ke3lupq-rj.a.run.app/#/store';

  /// Abre o site no navegador para o usuário concluir a assinatura.
  Future<void> _openWebSubscription() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Assinar pelo site', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Para concluir a assinatura com segurança, você será levado ao nosso '
          'site no navegador. Entre com a MESMA conta e finalize o pagamento. '
          'Ao voltar ao app, seu plano estará ativo automaticamente.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (go != true) return;
    final ok = await launchUrl(
      Uri.parse(_webSubscribeUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o navegador.')),
      );
    }
  }

  void _onSubscribe(SubscriptionPlan plan) {
    AnalyticsService().logPlanSelected(
        plan: plan.id, period: _isAnnual ? 'yearly' : 'monthly');

    // Mobile: paga pelo navegador (Play Billing policy). Web: checkout in-app.
    if (!kIsWeb) {
      _openWebSubscription();
      return;
    }

    final period = _isAnnual && plan.annualPrice != null ? AppLocalizations.of(context)!.yearly : AppLocalizations.of(context)!.monthly;
    final price = (_isAnnual && plan.annualPrice != null)
        ? plan.annualPrice!
        : plan.monthlyPrice;

    final item = CartItem(
      name: '${plan.name} — $period',
      description: plan.subtitle,
      price: price,
      icon: plan.icon,
      isSubscription: true,
      planId: plan.id,
    );

    ref.read(cartProvider.notifier).add(item);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(items: [item])),
    ).then((_) => ref.read(cartProvider.notifier).clear());
  }

  void _onTrial(SubscriptionPlan plan) {
    // Mobile: trial/assinatura concluídos pelo navegador (Play Billing policy).
    if (!kIsWeb) {
      _openWebSubscription();
      return;
    }
    final info = TrialPlanInfo(
      planId: plan.id,
      planName: plan.name,
      monthlyPrice: plan.monthlyPrice,
      accentColor: plan.accentColor,
      icon: plan.icon,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrialCheckoutScreen(plan: info)),
    );
  }

  Widget _buildSmartBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          final shell = context.findAncestorStateOfType<MainShellScreenState>();
          shell?.switchTab(0);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 20, 0),
                  child: Row(
                    children: [
                      _buildSmartBackButton(),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.storeTitle,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2)),
                            SizedBox(height: 2),
                            Text(AppLocalizations.of(context)!.storeSubtitle,
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Toggle Mensal / Anual ───────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.cardBorder.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        _buildToggleOption(AppLocalizations.of(context)!.monthly, !_isAnnual, () {
                          setState(() => _isAnnual = false);
                        }),
                        _buildToggleOption(AppLocalizations.of(context)!.yearly, _isAnnual, () {
                          setState(() => _isAnnual = true);
                        }, badge: AppLocalizations.of(context)!.save17Percent),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Lista de Planos ─────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    itemCount: subscriptionPlans(context).length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _buildPlanCard(subscriptionPlans(context)[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption(String label, bool selected, VoidCallback onTap,
      {String? badge}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isFree = plan.monthlyPrice == 0;
    final isAnnualAvailable = plan.annualPrice != null;
    final showAnnual = _isAnnual && isAnnualAvailable;

    final l10n = AppLocalizations.of(context)!;
    final displayPrice = isFree
        ? l10n.freePlanPrice
        : showAnnual
            ? '${CurrencyUtils.format(context, plan.annualPrice! / 12)}${l10n.storePerMonth}'
            : '${CurrencyUtils.format(context, plan.monthlyPrice)}${plan.perUser ? l10n.storePerUserPerMonth : l10n.storePerMonth}';

    final subPrice = isFree
        ? null
        : showAnnual
            ? '${CurrencyUtils.format(context, plan.annualPrice!, decimals: 0)} ${l10n.storeBilledAnnuallySuffix}'
            : plan.perUser
                ? l10n.storeMinUsersBilledAnnual(plan.minUsers ?? 0)
                : (isAnnualAvailable ? l10n.storeOrAnnualPlan(plan.annualLabel) : plan.annualLabel);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: plan.highlighted
            ? plan.accentColor.withValues(alpha: 0.08)
            : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.highlighted
              ? plan.accentColor.withValues(alpha: 0.6)
              : AppColors.cardBorder.withValues(alpha: 0.3),
          width: plan.highlighted ? 1.5 : 1,
        ),
        boxShadow: plan.highlighted
            ? [
                BoxShadow(
                  color: plan.accentColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho do card ─────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: plan.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: plan.accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(plan.icon, color: plan.accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                // Nome e público
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (plan.badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: plan.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color:
                                        plan.accentColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                plan.badge!,
                                style: TextStyle(
                                  color: plan.accentColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.subtitle,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Preço
                Flexible(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayPrice,
                      maxLines: 2,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isFree ? AppColors.textMuted : plan.accentColor,
                        fontSize: isFree ? 16 : 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subPrice,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                  ],
                ),
                ),
              ],
            ),
          ),

          // ── Features ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: plan.features
                  .map((f) => _buildFeatureRow(f, plan.accentColor))
                  .toList(),
            ),
          ),

          const SizedBox(height: 14),

          // ── Botões contextuais ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildPlanButtons(plan),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text, Color color) {
    final isInfinity = text.contains('∞');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isInfinity ? Icons.all_inclusive : Icons.check_circle_outline,
            color: isInfinity ? color : color.withValues(alpha: 0.7),
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isInfinity
                    ? color
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    isInfinity ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ── Botões contextuais baseados no estado do usuário ─────────────────────

  Widget _buildPlanButtons(SubscriptionPlan plan) {
    final user = ref.watch(userModelProvider).value;
    final isFree = plan.monthlyPrice == 0;

    if (isFree) {
      final isCurrentPlan = user == null || (!user.isPremium && !user.isOnTrial);
      return _disabledButton(isCurrentPlan ? AppLocalizations.of(context)!.yourCurrentPlan : AppLocalizations.of(context)!.basicPlan);
    }

    // Em trial nesse plano
    if (user?.isOnTrial == true && user?.subscriptionPlanId == plan.id) {
      final remaining = _trialDaysRemaining(user!.trialEndsAt);
      return _disabledButton(
        remaining > 0
            ? AppLocalizations.of(context)!.trialActiveRemaining(remaining)
            : AppLocalizations.of(context)!.trialEnded,
        color: plan.accentColor,
      );
    }

    // Já assina esse plano
    if (user?.isPremium == true && user?.isOnTrial != true && user?.subscriptionPlanId == plan.id) {
      return _disabledButton(AppLocalizations.of(context)!.currentPlanActive, color: plan.accentColor);
    }

    // Student exige comprovação de matrícula antes de assinar (PDF §8).
    if (plan.id == 'student') {
      return _routeButton(AppLocalizations.of(context)!.verifyEnrollment,
          color: plan.accentColor,
          icon: Icons.school_outlined,
          route: '/student-verification');
    }

    // Business é B2B — leva ao formulário de proposta (PDF §9).
    if (plan.id == 'business') {
      return _routeButton(AppLocalizations.of(context)!.requestProposal,
          color: plan.accentColor,
          icon: Icons.business_outlined,
          route: '/business-setup');
    }

    // Assinante de outro plano — upgrade
    if (user?.isPremium == true || user?.isOnTrial == true) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: () => _onSubscribe(plan),
          style: ElevatedButton.styleFrom(
            backgroundColor: plan.accentColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            AppLocalizations.of(context)!.upgradeToPlan(plan.name.split(' ').last.toUpperCase()),
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
        ),
      );
    }

    // Usuário Free — Assinar + Trial
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => _onSubscribe(plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: plan.accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              AppLocalizations.of(context)!.subscribeToPlan(plan.name.split(' ').last.toUpperCase()),
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 38,
          child: OutlinedButton.icon(
            onPressed: () => _onTrial(plan),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: plan.accentColor.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(Icons.all_inclusive, color: plan.accentColor, size: 14),
            label: Text(
              AppLocalizations.of(context)!.test7DaysFree,
              style: TextStyle(
                  color: plan.accentColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _routeButton(String label,
      {required Color color, required IconData icon, required String route}) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () => context.push(route),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(icon, color: Colors.white, size: 15),
        label: Text(
          label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8),
        ),
      ),
    );
  }

  Widget _disabledButton(String label, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: (color ?? AppColors.textMuted).withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color ?? AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5),
        ),
      ),
    );
  }

  int _trialDaysRemaining(DateTime? endsAt) {
    if (endsAt == null) return 0;
    final diff = endsAt.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inDays;
  }

}
