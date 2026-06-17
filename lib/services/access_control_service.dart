import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/models/user_model.dart';
import 'package:spark_app/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────
//  ACCESS CONTROL — núcleo do gating (bloqueio por plano)
//
//  Centraliza TODA a lógica de "o que cada plano pode acessar".
//  Regras conforme o plano de precificação aprovado (Fábio, Jun/2026):
//   - Free: vê tudo, mas só acessa a 1ª trilha de cada módulo,
//           o 1º capítulo de cada e-book e 3 ferramentas básicas.
//   - Pro/Student: tudo desbloqueado.
//   - Premium: Pro + tutoria/early access/suporte prioritário.
//   - Business: Premium + painel/relatórios/NF-e.
//
//  IMPORTANTE: isto é só UX (mostrar cadeado / abrir upgrade). A
//  decisão crítica de acesso deve ser validada no servidor.
// ─────────────────────────────────────────────────────────────────

enum UserPlan { free, pro, premium, student, business }

/// IDs das 3 ferramentas liberadas no Free (PDF §2).
const Set<String> kFreeToolIds = {
  'symmetrical_components', // Componentes Simétricas
  'per_unit', // Valor por Unidade (PU)
  'rtc_rtp', // RTC / RTP
};

/// Matriz de funcionalidades por plano (espelha plans_catalog do PDF).
class PlanFeatures {
  /// `true` = trilhas ilimitadas; `false` = só a 1ª trilha do módulo.
  final bool allTrails;

  /// `true` = todos os capítulos; `false` = só o 1º capítulo.
  final bool allEbookChapters;

  /// `true` = todas as ferramentas; `false` = apenas [kFreeToolIds].
  final bool allTools;

  final bool certificates;
  final bool offlineMode;
  final bool noAds;
  final bool advancedStats;
  final bool customization;
  final bool monthlyTutoring;
  final bool earlyAccess;
  final bool prioritySupport;
  final bool teamPanel;
  final bool teamReports;
  final bool invoicing;

  const PlanFeatures({
    this.allTrails = false,
    this.allEbookChapters = false,
    this.allTools = false,
    this.certificates = false,
    this.offlineMode = false,
    this.noAds = false,
    this.advancedStats = false,
    this.customization = false,
    this.monthlyTutoring = false,
    this.earlyAccess = false,
    this.prioritySupport = false,
    this.teamPanel = false,
    this.teamReports = false,
    this.invoicing = false,
  });

  /// Plano pago completo (Pro / Student) — tudo de conteúdo liberado.
  static const PlanFeatures _paidBase = PlanFeatures(
    allTrails: true,
    allEbookChapters: true,
    allTools: true,
    certificates: true,
    offlineMode: true,
    noAds: true,
    advancedStats: true,
    customization: true,
  );

  /// Acesso irrestrito — TODAS as features ligadas. Usado por admins.
  static const PlanFeatures everything = PlanFeatures(
    allTrails: true,
    allEbookChapters: true,
    allTools: true,
    certificates: true,
    offlineMode: true,
    noAds: true,
    advancedStats: true,
    customization: true,
    monthlyTutoring: true,
    earlyAccess: true,
    prioritySupport: true,
    teamPanel: true,
    teamReports: true,
    invoicing: true,
  );
}

/// Catálogo padrão de features por plano. (Pode futuramente vir do
/// Firestore `plans_catalog/{planId}` sem deploy — ver PDF §3.)
const Map<UserPlan, PlanFeatures> kPlanCatalog = {
  UserPlan.free: PlanFeatures(), // tudo false → gating ativo
  UserPlan.pro: PlanFeatures._paidBase,
  UserPlan.student: PlanFeatures._paidBase,
  UserPlan.premium: PlanFeatures(
    allTrails: true,
    allEbookChapters: true,
    allTools: true,
    certificates: true,
    offlineMode: true,
    noAds: true,
    advancedStats: true,
    customization: true,
    monthlyTutoring: true,
    earlyAccess: true,
    prioritySupport: true,
  ),
  UserPlan.business: PlanFeatures(
    allTrails: true,
    allEbookChapters: true,
    allTools: true,
    certificates: true,
    offlineMode: true,
    noAds: true,
    advancedStats: true,
    customization: true,
    earlyAccess: true,
    prioritySupport: true,
    teamPanel: true,
    teamReports: true,
    invoicing: true,
  ),
};

UserPlan _planFromId(String? id) {
  switch (id) {
    case 'pro':
      return UserPlan.pro;
    case 'premium':
      return UserPlan.premium;
    case 'student':
      return UserPlan.student;
    case 'business':
      return UserPlan.business;
    default:
      return UserPlan.pro; // pago sem id explícito ⇒ trata como Pro
  }
}

/// Snapshot imutável de acesso do usuário atual.
class AccessControl {
  final UserPlan plan;
  final bool isOnTrial;
  final DateTime? trialEndsAt;

  /// Quando definido, sobrepõe o catálogo de features do [plan].
  /// Admins recebem [PlanFeatures.everything] aqui (acesso irrestrito).
  final PlanFeatures? _featuresOverride;

  const AccessControl({
    required this.plan,
    this.isOnTrial = false,
    this.trialEndsAt,
    PlanFeatures? featuresOverride,
  }) : _featuresOverride = featuresOverride;

  factory AccessControl.fromUser(UserModel? u) {
    // Admins têm acesso IRRESTRITO: todas as ferramentas, trilhas, lições e
    // demais recursos liberados, independentemente de pagamento/trial.
    if (u?.isAdmin ?? false) {
      return AccessControl(
        plan: UserPlan.premium, // rótulo do badge; features vêm do override
        isOnTrial: u?.isOnTrial ?? false,
        trialEndsAt: u?.trialEndsAt,
        featuresOverride: PlanFeatures.everything,
      );
    }
    // Trial e assinatura ativa dão acesso de plano pago.
    final paid = (u?.isPremium ?? false) || (u?.isOnTrial ?? false);
    final plan = !paid ? UserPlan.free : _planFromId(u?.subscriptionPlanId);
    return AccessControl(
      plan: plan,
      isOnTrial: u?.isOnTrial ?? false,
      trialEndsAt: u?.trialEndsAt,
    );
  }

  PlanFeatures get features =>
      _featuresOverride ?? kPlanCatalog[plan] ?? const PlanFeatures();
  bool get isFree => plan == UserPlan.free;

  // ── Gating de conteúdo ──────────────────────────────────────────
  /// Trilha liberada se for paga ou se for a 1ª trilha do módulo.
  bool canAccessTrail({required bool isFirstTrail}) =>
      features.allTrails || isFirstTrail;

  /// Capítulo liberado se for pago ou se for o 1º (índice 0).
  bool canAccessEbookChapter(int chapterIndex) =>
      features.allEbookChapters || chapterIndex == 0;

  /// Ferramenta liberada se for paga ou se estiver nas 3 do Free.
  bool canAccessTool(String toolId) =>
      features.allTools || kFreeToolIds.contains(toolId);

  bool canDownloadCertificate() => features.certificates;
  bool canUseOfflineMode() => features.offlineMode;
  bool shouldShowAds() => !features.noAds;
  bool canUseAdvancedStats() => features.advancedStats;
  bool canUseCustomization() => features.customization;

  // ── Trial ───────────────────────────────────────────────────────
  int get trialDaysRemaining {
    final end = trialEndsAt;
    if (!isOnTrial || end == null) return 0;
    final diff = end.difference(DateTime.now()).inHours;
    if (diff <= 0) return 0;
    return (diff / 24).ceil();
  }

  /// Mensagem contextual de upgrade por feature bloqueada.
  String upgradeMessageFor(String feature) {
    switch (feature) {
      case 'trail':
        return 'Desbloqueie todas as trilhas deste módulo com o Pro.';
      case 'ebook':
        return 'Leia todos os capítulos dos e-books com o Pro.';
      case 'tool':
        return 'Acesse todas as calculadoras com o Pro.';
      case 'certificate':
        return 'Baixe certificados de conclusão com o Pro.';
      case 'offline':
        return 'Use o modo offline com o Pro.';
      default:
        return 'Faça upgrade para o Pro e desbloqueie tudo.';
    }
  }
}

/// Provider reativo do controle de acesso do usuário logado.
final accessControlProvider = Provider<AccessControl>((ref) {
  final user = ref.watch(userModelProvider).value;
  return AccessControl.fromUser(user);
});
