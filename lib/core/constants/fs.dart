import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FS {
  // ── Root collections ──────────────────────────────────────────────────────
  static const String users = 'users';
  static const String categories = 'categories';
  static const String clans = 'clans';
  static const String rankings = 'rankings';
  static const String matches = 'matches';
  static const String matchmakingQueue = 'matchmaking_queue';
  static const String storeItems = 'store_items';
  static const String transactions = 'transactions';
  static const String voucherRedemptions = 'voucher_redemptions';
  static const String badges = 'badges';
  static const String activeEvents = 'active_events';
  static const String standardsMetadata = 'standards_metadata';

  // ── Sub-collections ───────────────────────────────────────────────────────
  static const String progress = 'progress';
  static const String quizHistory = 'quiz_history';
  static const String modules = 'modules';
  static const String lessons = 'lessons';
  static const String questions = 'questions';
  static const String members = 'members';
  static const String messages = 'messages';
  static const String covenants = 'covenants'; // subcoleção users/{uid}/covenants

  // ── Standards metadata fields ─────────────────────────────────────────────
  static const String clickCount = 'clickCount';
  static const String colorHex = 'colorHex';

  // ── Covenant selection fields ─────────────────────────────────────────────
  static const String isSelected = 'isSelected';
  static const String weekKey = 'weekKey';

  // ── User fields (esquema unificado UserModel) ─────────────────────────────
  static const String uid = 'uid';
  static const String displayName = 'displayName'; // padrão atual
  static const String email = 'email';
  static const String profession = 'profession';
  static const String photoUrl = 'photoUrl';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String sparkPoints = 'sparkPoints';
  static const String xp = 'xp';
  static const String level = 'level';
  static const String tensionLevel = 'tensionLevel';
  static const String currentStreak = 'currentStreak';
  static const String longestStreak = 'longestStreak';
  static const String activeDays = 'activeDays';
  static const String studiedToday = 'studiedToday';
  static const String lastStudyDate = 'lastStudyDate';
  static const String weeklyXp = 'weeklyXp';
  static const String monthlyXp = 'monthlyXp';
  static const String unlockedBadgeIds = 'unlockedBadgeIds'; // padrão atual
  static const String role = 'role';
  static const String clanId = 'clanId';
  static const String clanName = 'clanName';
  static const String totalLessonsCompleted = 'totalLessonsCompleted';
  static const String totalCorrectAnswers = 'totalCorrectAnswers';
  static const String totalAnswers = 'totalAnswers';

  // ── Aliases legados (dados antigos no Firestore — não usar em código novo) ─
  // ignore: constant_identifier_names
  static const String name = 'name';               // legado → use displayName
  // ignore: constant_identifier_names
  static const String streak = 'streak';            // legado → use currentStreak
  // ignore: constant_identifier_names
  static const String userBadges = 'badges';        // legado → use unlockedBadgeIds
  static const String energy = 'energy';
  static const String energyLastRegen = 'energyLastRegen';
  static const String lastLoginDate = 'lastLoginDate';
  static const String isPremium = 'isPremium';

  // ── Progress fields ───────────────────────────────────────────────────────
  static const String moduleId = 'moduleId';
  static const String categoryId = 'categoryId';
  static const String completedLessons = 'completedLessons';
  static const String progressPercent = 'progressPercent';
  static const String isCompleted = 'isCompleted';
  static const String startedAt = 'startedAt';
  static const String completedAt = 'completedAt';
  static const String lastAccessed = 'lastAccessed';
  static const String bestScore = 'bestScore';
  static const String attempts = 'attempts';

  // ── Question fields ───────────────────────────────────────────────────────
  static const String id = 'id';
  static const String order = 'order';
  static const String type = 'type';
  static const String statement = 'statement';
  static const String options = 'options';
  static const String correctIndex = 'correctIndex';
  static const String explanation = 'explanation';
  static const String difficulty = 'difficulty';
  static const String normReference = 'normReference';
  static const String imageUrl = 'imageUrl';
  static const String isActive = 'isActive';

  // ── Clan fields ───────────────────────────────────────────────────────────
  static const String description = 'description';
  static const String logoUrl = 'logoUrl';
  static const String createdBy = 'createdBy';
  static const String memberCount = 'memberCount';
  static const String maxMembers = 'maxMembers';
  static const String totalXp = 'totalXp';
  static const String isPublic = 'isPublic';
  static const String inviteCode = 'inviteCode';
  static const String rank = 'rank';

  // ── Match fields ──────────────────────────────────────────────────────────
  static const String player1Uid = 'player1Uid';
  static const String player2Uid = 'player2Uid';
  static const String status = 'status';
  static const String player1Scores = 'player1Scores';
  static const String player2Scores = 'player2Scores';
  static const String winnerId = 'winnerId';
  static const String finishedAt = 'finishedAt';
}

// ── QuestionModel ─────────────────────────────────────────────────────────────

class QuestionModel {
  final String id;
  final int order;
  final String type;
  final String statement;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String difficulty;
  final String normReference;
  final String? imageUrl;
  final bool isActive;

  const QuestionModel({
    required this.id,
    required this.order,
    required this.type,
    required this.statement,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.difficulty,
    required this.normReference,
    this.imageUrl,
    required this.isActive,
  });

  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return QuestionModel(
      id: doc.id,
      order: (d[FS.order] as num).toInt(),
      type: d[FS.type] as String,
      statement: d[FS.statement] as String,
      options: List<String>.from(d[FS.options] as List),
      correctIndex: (d[FS.correctIndex] as num).toInt(),
      explanation: d[FS.explanation] as String,
      difficulty: d[FS.difficulty] as String,
      normReference: d[FS.normReference] as String,
      imageUrl: d[FS.imageUrl] as String?,
      isActive: d[FS.isActive] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        FS.id: id,
        FS.order: order,
        FS.type: type,
        FS.statement: statement,
        FS.options: options,
        FS.correctIndex: correctIndex,
        FS.explanation: explanation,
        FS.difficulty: difficulty,
        FS.normReference: normReference,
        FS.imageUrl: imageUrl,
        FS.isActive: isActive,
      };
}

// ── ClanModel ─────────────────────────────────────────────────────────────────

class ClanModel {
  final String id;
  final String name;
  final String description;
  final String logoUrl;
  final DateTime createdAt;
  final String createdBy;
  final int memberCount;
  final int maxMembers;
  final int totalXp;
  final int weeklyXp;
  final bool isPublic;
  final String inviteCode;
  final int rank;

  const ClanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.createdAt,
    required this.createdBy,
    required this.memberCount,
    required this.maxMembers,
    required this.totalXp,
    required this.weeklyXp,
    required this.isPublic,
    required this.inviteCode,
    required this.rank,
  });

  factory ClanModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClanModel(
      id: doc.id,
      name: d[FS.name] as String,
      description: d[FS.description] as String,
      logoUrl: d[FS.logoUrl] as String,
      createdAt: (d[FS.createdAt] as Timestamp).toDate(),
      createdBy: d[FS.createdBy] as String,
      memberCount: (d[FS.memberCount] as num).toInt(),
      maxMembers: (d[FS.maxMembers] as num).toInt(),
      totalXp: (d[FS.totalXp] as num).toInt(),
      weeklyXp: (d[FS.weeklyXp] as num).toInt(),
      isPublic: d[FS.isPublic] as bool,
      inviteCode: d[FS.inviteCode] as String,
      rank: (d[FS.rank] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        FS.id: id,
        FS.name: name,
        FS.description: description,
        FS.logoUrl: logoUrl,
        FS.createdAt: Timestamp.fromDate(createdAt),
        FS.createdBy: createdBy,
        FS.memberCount: memberCount,
        FS.maxMembers: maxMembers,
        FS.totalXp: totalXp,
        FS.weeklyXp: weeklyXp,
        FS.isPublic: isPublic,
        FS.inviteCode: inviteCode,
        FS.rank: rank,
      };
}

// ── MatchModel ────────────────────────────────────────────────────────────────

class MatchModel {
  final String id;
  final String player1Uid;
  final String player2Uid;
  final String status;
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> player1Scores;
  final List<Map<String, dynamic>> player2Scores;
  final String? winnerId;
  final DateTime createdAt;
  final DateTime? finishedAt;

  const MatchModel({
    required this.id,
    required this.player1Uid,
    required this.player2Uid,
    required this.status,
    required this.questions,
    required this.player1Scores,
    required this.player2Scores,
    this.winnerId,
    required this.createdAt,
    this.finishedAt,
  });

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      player1Uid: d[FS.player1Uid] as String,
      player2Uid: d[FS.player2Uid] as String,
      status: d[FS.status] as String,
      questions: List<Map<String, dynamic>>.from(d[FS.questions] as List),
      player1Scores:
          List<Map<String, dynamic>>.from(d[FS.player1Scores] as List),
      player2Scores:
          List<Map<String, dynamic>>.from(d[FS.player2Scores] as List),
      winnerId: d[FS.winnerId] as String?,
      createdAt: (d[FS.createdAt] as Timestamp).toDate(),
      finishedAt: d[FS.finishedAt] != null
          ? (d[FS.finishedAt] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        FS.id: id,
        FS.player1Uid: player1Uid,
        FS.player2Uid: player2Uid,
        FS.status: status,
        FS.questions: questions,
        FS.player1Scores: player1Scores,
        FS.player2Scores: player2Scores,
        FS.winnerId: winnerId,
        FS.createdAt: Timestamp.fromDate(createdAt),
        FS.finishedAt: finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      };
}
