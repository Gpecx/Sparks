import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────
//  NOME DE EXIBIÇÃO — fonte única de verdade para o fallback de nome.
//
//  Antes o fallback era o literal 'Usuário', o que fazia contas sem
//  displayName (ex.: admins criados pelo console do Firebase Auth, que
//  nascem sem "Display name") aparecerem como "Usuário" no dashboard e
//  no perfil. Agora derivamos um nome legível a partir do e-mail.
//  Ex.: "joao.silva@empresa.com" → "Joao Silva".
// ─────────────────────────────────────────────────────────────────
String resolveDisplayName({String? displayName, String? email}) {
  final name = displayName?.trim();
  if (name != null && name.isNotEmpty && name != 'Usuário') return name;

  final local = email?.split('@').first.trim() ?? '';
  if (local.isEmpty) return 'Usuário';

  final parts =
      local.split(RegExp(r'[._\-+]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'Usuário';

  return parts
      .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
      .join(' ');
}

// ─────────────────────────────────────────────────────────────────
//  MODELO PRINCIPAL DO USUÁRIO — Firestore: users/{uid}
//
//  CAMPOS REMOVIDOS (gerenciados via subcoleções):
//   - lessonProgress → users/{uid}/progress  (ProgressService)
//   - covenantProgress → users/{uid}/covenants (CovenantService)
// ─────────────────────────────────────────────────────────────────

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String role;
  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  /// Verdadeiro para qualquer usuário com acesso pago ativo
  /// (premium, em trial, ou com plano pro/premium/student/business).
  /// Usado p/ liberar a bateria infinita e demais benefícios.
  bool get isSubscriber {
    if (isPremium || isOnTrial) return true;
    final plan = subscriptionPlanId?.trim().toLowerCase();
    return plan == 'pro' ||
        plan == 'premium' ||
        plan == 'student' ||
        plan == 'business';
  }
  final String? profession;
  final int xp;
  final int level;
  final String tensionLevel; // 'BT' | 'MT' | 'AT' | 'EAT'
  final int currentStreak;
  final int longestStreak;
  final int activeDays;
  final bool isPremium;
  // ── Trial ──────────────────────────────────────────────────────
  final bool isOnTrial;
  final DateTime? trialEndsAt;
  final String? subscriptionPlanId;   // 'pro' | 'premium' | 'student' | 'business'
  final String? asaasSubscriptionId;
  final DateTime? lastStudyDate;
  final bool studiedToday;
  /// Momento em que o usuário concluiu o último Desafio Diário.
  /// O próximo só fica disponível 24h depois (mesma hora do dia seguinte ou após).
  final DateTime? lastDailyChallengeCompletedAt;
  final String? clanId;
  final String? clanName;
  final List<String> unlockedBadgeIds;
  final int weeklyXp;
  // ── Duelo ──────────────────────────────────────────────────────
  final int eloRating;
  final int wins;
  final int losses;
  final int totalDuels;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.role = 'Técnico',
    this.profession,
    this.xp = 0,
    this.level = 1,
    this.tensionLevel = 'BT',
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.activeDays = 0,
    this.isPremium = false,
    this.isOnTrial = false,
    this.trialEndsAt,
    this.subscriptionPlanId,
    this.asaasSubscriptionId,
    this.lastStudyDate,
    this.studiedToday = false,
    this.lastDailyChallengeCompletedAt,
    this.clanId,
    this.clanName,
    this.unlockedBadgeIds = const [],
    this.weeklyXp = 0,
    this.eloRating = 0,
    this.wins = 0,
    this.losses = 0,
    this.totalDuels = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── fromFirestore (BLINDADO) ───────────────────────────────────────────────
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    // 1. Garante que se o doc.data() vier nulo, ele vira um Map vazio em vez de quebrar
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserModel(
      uid: doc.id,
      // O .toString() garante que mesmo que o Firebase grave um número ali, não quebra.
      // Se não houver nome (ou estiver gravado o legado 'Usuário'), deriva do e-mail.
      displayName: resolveDisplayName(
        displayName: (data['displayName'] ?? data['name'])?.toString(),
        email: data['email']?.toString(),
      ),
      email: data['email']?.toString() ?? '',
      photoUrl: data['photoUrl']?.toString(),
      role: (data['role']?.toString() ?? 'Técnico').trim(),
      profession: data['profession']?.toString(),
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      tensionLevel: data['tensionLevel']?.toString() ?? 'BT',
      currentStreak: (data['currentStreak'] as num?)?.toInt() ??
          (data['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      activeDays: (data['activeDays'] as num?)?.toInt() ?? 0,
      isPremium: data['isPremium'] == true,
      isOnTrial: data['isOnTrial'] == true,
      trialEndsAt: data['trialEndsAt'] is Timestamp
          ? (data['trialEndsAt'] as Timestamp).toDate()
          : null,
      subscriptionPlanId: data['subscriptionPlanId']?.toString(),
      asaasSubscriptionId: data['asaasSubscriptionId']?.toString(),

      // Datas: verifica especificamente se é um Timestamp do Firebase
      lastStudyDate: data['lastStudyDate'] is Timestamp
          ? (data['lastStudyDate'] as Timestamp).toDate()
          : null,
      lastDailyChallengeCompletedAt: data['lastDailyChallengeCompletedAt'] is Timestamp
          ? (data['lastDailyChallengeCompletedAt'] as Timestamp).toDate()
          : null,

      // Booleano: a comparação == true evita quebra se vier nulo ou texto
      studiedToday: data['studiedToday'] == true,
      
      clanId: data['clanId']?.toString(),
      clanName: data['clanName']?.toString(),
      
      // Lista: Blindagem pesada contra listas corrompidas ou nulas
      unlockedBadgeIds: ((data['unlockedBadgeIds'] ?? data['badges']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
          
      weeklyXp: (data['weeklyXp'] as num?)?.toInt() ?? 0,
      eloRating: (data['eloRating'] as num?)?.toInt() ?? 0,
      wins: (data['wins'] as num?)?.toInt() ?? 0,
      losses: (data['losses'] as num?)?.toInt() ?? 0,
      totalDuels: (data['totalDuels'] as num?)?.toInt() ?? 0,
      
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // ── toFirestore ─────────────────────────────────────────────────
  // Nota: não inclui lessonProgress nem covenantProgress — gerenciados via subcoleções
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'profession': profession,
      'xp': xp,
      'level': level,
      'tensionLevel': tensionLevel,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'activeDays': activeDays,
      'isPremium': isPremium,
      'isOnTrial': isOnTrial,
      'trialEndsAt': trialEndsAt != null ? Timestamp.fromDate(trialEndsAt!) : null,
      'subscriptionPlanId': subscriptionPlanId,
      'asaasSubscriptionId': asaasSubscriptionId,
      'lastStudyDate':
          lastStudyDate != null ? Timestamp.fromDate(lastStudyDate!) : null,
      'lastDailyChallengeCompletedAt': lastDailyChallengeCompletedAt != null
          ? Timestamp.fromDate(lastDailyChallengeCompletedAt!)
          : null,
      'studiedToday': studiedToday,
      'clanId': clanId,
      'clanName': clanName,
      'unlockedBadgeIds': unlockedBadgeIds,
      'weeklyXp': weeklyXp,
      'eloRating': eloRating,
      'wins': wins,
      'losses': losses,
      'totalDuels': totalDuels,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ── copyWith ────────────────────────────────────────────────────
  UserModel copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? role,
    String? profession,
    int? xp,
    int? level,
    String? tensionLevel,
    int? currentStreak,
    int? longestStreak,
    int? activeDays,
    bool? isPremium,
    bool? isOnTrial,
    DateTime? trialEndsAt,
    String? subscriptionPlanId,
    String? asaasSubscriptionId,
    DateTime? lastStudyDate,
    bool? studiedToday,
    DateTime? lastDailyChallengeCompletedAt,
    String? clanId,
    String? clanName,
    List<String>? unlockedBadgeIds,
    int? weeklyXp,
    int? eloRating,
    int? wins,
    int? losses,
    int? totalDuels,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      profession: profession ?? this.profession,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      tensionLevel: tensionLevel ?? this.tensionLevel,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      activeDays: activeDays ?? this.activeDays,
      isPremium: isPremium ?? this.isPremium,
      isOnTrial: isOnTrial ?? this.isOnTrial,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      subscriptionPlanId: subscriptionPlanId ?? this.subscriptionPlanId,
      asaasSubscriptionId: asaasSubscriptionId ?? this.asaasSubscriptionId,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      studiedToday: studiedToday ?? this.studiedToday,
      lastDailyChallengeCompletedAt:
          lastDailyChallengeCompletedAt ?? this.lastDailyChallengeCompletedAt,
      clanId: clanId ?? this.clanId,
      clanName: clanName ?? this.clanName,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      eloRating: eloRating ?? this.eloRating,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      totalDuels: totalDuels ?? this.totalDuels,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}