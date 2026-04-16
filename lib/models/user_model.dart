import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/fs.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profession;
  final String photoUrl;
  final DateTime createdAt;
  final int sparkPoints;
  final int xp;
  final int energy;
  final DateTime energyLastRegen;
  final int streak;
  final int longestStreak;
  final DateTime lastLoginDate;
  final bool isPremium;
  final String tensionLevel;
  final String role;
  final String? clanId;
  final int totalLessonsCompleted;
  final int totalCorrectAnswers;
  final int totalAnswers;
  final List<String> badges;
  final int weeklyXp;
  final int monthlyXp;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.profession,
    required this.photoUrl,
    required this.createdAt,
    required this.sparkPoints,
    required this.xp,
    required this.energy,
    required this.energyLastRegen,
    required this.streak,
    required this.longestStreak,
    required this.lastLoginDate,
    required this.isPremium,
    required this.tensionLevel,
    required this.role,
    this.clanId,
    required this.totalLessonsCompleted,
    required this.totalCorrectAnswers,
    required this.totalAnswers,
    required this.badges,
    required this.weeklyXp,
    required this.monthlyXp,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: d[FS.name] as String,
      email: d[FS.email] as String,
      profession: d[FS.profession] as String,
      photoUrl: d[FS.photoUrl] as String,
      createdAt: (d[FS.createdAt] as Timestamp).toDate(),
      sparkPoints: (d[FS.sparkPoints] as num).toInt(),
      xp: (d[FS.xp] as num).toInt(),
      energy: (d[FS.energy] as num).toInt(),
      energyLastRegen: (d[FS.energyLastRegen] as Timestamp).toDate(),
      streak: (d[FS.streak] as num).toInt(),
      longestStreak: (d[FS.longestStreak] as num).toInt(),
      lastLoginDate: (d[FS.lastLoginDate] as Timestamp).toDate(),
      isPremium: d[FS.isPremium] as bool,
      tensionLevel: d[FS.tensionLevel] as String,
      role: d[FS.role] as String,
      clanId: d[FS.clanId] as String?,
      totalLessonsCompleted: (d[FS.totalLessonsCompleted] as num).toInt(),
      totalCorrectAnswers: (d[FS.totalCorrectAnswers] as num).toInt(),
      totalAnswers: (d[FS.totalAnswers] as num).toInt(),
      badges: List<String>.from(d[FS.userBadges] as List),
      weeklyXp: (d[FS.weeklyXp] as num).toInt(),
      monthlyXp: (d[FS.monthlyXp] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        FS.name: name,
        FS.email: email,
        FS.profession: profession,
        FS.photoUrl: photoUrl,
        FS.createdAt: Timestamp.fromDate(createdAt),
        FS.sparkPoints: sparkPoints,
        FS.xp: xp,
        FS.energy: energy,
        FS.energyLastRegen: Timestamp.fromDate(energyLastRegen),
        FS.streak: streak,
        FS.longestStreak: longestStreak,
        FS.lastLoginDate: Timestamp.fromDate(lastLoginDate),
        FS.isPremium: isPremium,
        FS.tensionLevel: tensionLevel,
        FS.role: role,
        FS.clanId: clanId,
        FS.totalLessonsCompleted: totalLessonsCompleted,
        FS.totalCorrectAnswers: totalCorrectAnswers,
        FS.totalAnswers: totalAnswers,
        FS.userBadges: badges,
        FS.weeklyXp: weeklyXp,
        FS.monthlyXp: monthlyXp,
      };
}
