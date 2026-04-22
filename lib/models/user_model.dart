import 'package:cloud_firestore/cloud_firestore.dart';

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
  final int sparkPoints;
  final int xp;
  final int level;
  final String tensionLevel; // 'BT' | 'MT' | 'AT' | 'EAT'
  final int currentStreak;
  final int longestStreak;
  final int activeDays;
  final DateTime? lastStudyDate;
  final bool studiedToday;
  final String? clanId;
  final String? clanName;
  final List<String> unlockedBadgeIds;
  final int weeklyXp;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.role = 'Técnico',
    this.sparkPoints = 0,
    this.xp = 0,
    this.level = 1,
    this.tensionLevel = 'BT',
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.activeDays = 0,
    this.lastStudyDate,
    this.studiedToday = false,
    this.clanId,
    this.clanName,
    this.unlockedBadgeIds = const [],
    this.weeklyXp = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── fromFirestore ───────────────────────────────────────────────
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? data['name'] ?? 'Usuário', // fallback legado
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      role: data['role'] ?? 'Técnico',
      sparkPoints: (data['sparkPoints'] as num?)?.toInt() ?? 0,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      tensionLevel: data['tensionLevel'] ?? 'BT',
      currentStreak: (data['currentStreak'] as num?)?.toInt() ??
          (data['streak'] as num?)?.toInt() ?? 0, // fallback legado
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      activeDays: (data['activeDays'] as num?)?.toInt() ?? 0,
      lastStudyDate: (data['lastStudyDate'] as Timestamp?)?.toDate(),
      studiedToday: data['studiedToday'] ?? false,
      clanId: data['clanId'],
      clanName: data['clanName'],
      unlockedBadgeIds: List<String>.from(
        data['unlockedBadgeIds'] ?? data['badges'] ?? [], // fallback legado
      ),
      weeklyXp: (data['weeklyXp'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'sparkPoints': sparkPoints,
      'xp': xp,
      'level': level,
      'tensionLevel': tensionLevel,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'activeDays': activeDays,
      'lastStudyDate':
          lastStudyDate != null ? Timestamp.fromDate(lastStudyDate!) : null,
      'studiedToday': studiedToday,
      'clanId': clanId,
      'clanName': clanName,
      'unlockedBadgeIds': unlockedBadgeIds,
      'weeklyXp': weeklyXp,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ── copyWith ────────────────────────────────────────────────────
  UserModel copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? role,
    int? sparkPoints,
    int? xp,
    int? level,
    String? tensionLevel,
    int? currentStreak,
    int? longestStreak,
    int? activeDays,
    DateTime? lastStudyDate,
    bool? studiedToday,
    String? clanId,
    String? clanName,
    List<String>? unlockedBadgeIds,
    int? weeklyXp,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      sparkPoints: sparkPoints ?? this.sparkPoints,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      tensionLevel: tensionLevel ?? this.tensionLevel,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      activeDays: activeDays ?? this.activeDays,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      studiedToday: studiedToday ?? this.studiedToday,
      clanId: clanId ?? this.clanId,
      clanName: clanName ?? this.clanName,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}