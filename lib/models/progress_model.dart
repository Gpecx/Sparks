import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/fs.dart';

class ProgressModel {
  final String id;
  final String moduleId;
  final String categoryId;
  final String moduleName;          // Nome human-readable do módulo
  final List<String> completedLessons;
  final double progressPercent;
  final bool isCompleted;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime lastAccessed;
  final int bestScore;
  final int attempts;

  const ProgressModel({
    required this.id,
    required this.moduleId,
    required this.categoryId,
    this.moduleName = '',
    required this.completedLessons,
    required this.progressPercent,
    required this.isCompleted,
    required this.startedAt,
    this.completedAt,
    required this.lastAccessed,
    required this.bestScore,
    required this.attempts,
  });

  factory ProgressModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProgressModel(
      id: doc.id,
      moduleId: d[FS.moduleId] as String,
      categoryId: d[FS.categoryId] as String,
      moduleName: d['moduleName'] as String? ?? '',
      completedLessons: List<String>.from(d[FS.completedLessons] as List),
      progressPercent: (d[FS.progressPercent] as num).toDouble(),
      isCompleted: d[FS.isCompleted] as bool,
      startedAt: (d[FS.startedAt] as Timestamp).toDate(),
      completedAt: d[FS.completedAt] != null
          ? (d[FS.completedAt] as Timestamp).toDate()
          : null,
      lastAccessed: (d[FS.lastAccessed] as Timestamp).toDate(),
      bestScore: (d[FS.bestScore] as num).toInt(),
      attempts: (d[FS.attempts] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        FS.moduleId: moduleId,
        FS.categoryId: categoryId,
        'moduleName': moduleName,
        FS.completedLessons: completedLessons,
        FS.progressPercent: progressPercent,
        FS.isCompleted: isCompleted,
        FS.startedAt: Timestamp.fromDate(startedAt),
        FS.completedAt:
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        FS.lastAccessed: Timestamp.fromDate(lastAccessed),
        FS.bestScore: bestScore,
        FS.attempts: attempts,
      };
}
