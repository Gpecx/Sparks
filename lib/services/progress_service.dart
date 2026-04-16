import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/fs.dart';
import '../models/progress_model.dart';
import '../models/user_model.dart';
import '../services/achievement_service.dart';
import '../data/lessons_registry.dart';

class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  String _calcTension(int xp) {
    if (xp < 5000) return 'BT';
    if (xp < 15000) return 'MT';
    if (xp < 30000) return 'AT';
    return 'EAT';
  }

  Future<ProgressModel?> getProgress(String uid, String moduleId) async {
    final snap = await _fs.collection(FS.users).doc(uid)
        .collection(FS.progress).where(FS.moduleId, isEqualTo: moduleId).limit(1).get();
        
    if (snap.docs.isEmpty) return null;
    return ProgressModel.fromFirestore(snap.docs.first);
  }

  Future<List<ProgressModel>> getAllProgress(String uid) async {
    final snap = await _fs.collection(FS.users).doc(uid).collection(FS.progress).get();
    return snap.docs.map((d) => ProgressModel.fromFirestore(d)).toList();
  }

  Future<void> markLessonComplete(String uid, String catId, String modId, String lessonId, int xpEarned, int spEarned) async {
    final userRef = _fs.collection(FS.users).doc(uid);
    final userDoc = await userRef.get();
    
    if (!userDoc.exists) return;
    final userData = UserModel.fromFirestore(userDoc);
    
    final progSnap = await userRef.collection(FS.progress)
        .where(FS.moduleId, isEqualTo: modId).limit(1).get();
    
    final batch = _fs.batch();
    
    DocumentReference pRef;
    if (progSnap.docs.isNotEmpty) {
      pRef = progSnap.docs.first.reference;
    } else {
      pRef = userRef.collection(FS.progress).doc();
      batch.set(pRef, {
        FS.moduleId: modId,
        FS.categoryId: catId,
        FS.completedLessons: [],
        FS.progressPercent: 0.0,
        FS.isCompleted: false,
        FS.startedAt: FieldValue.serverTimestamp(),
        FS.lastAccessed: FieldValue.serverTimestamp(),
        FS.bestScore: 0,
        FS.attempts: 0,
      });
    }

    // Calcula o progresso real com base no número de lições do módulo no registry.
    // Busca as lições concluídas atuais + a nova lição sendo marcada.
    List<String> alreadyCompleted = [];
    if (progSnap.docs.isNotEmpty) {
      final existingData = progSnap.docs.first.data() as Map<String, dynamic>;
      alreadyCompleted = List<String>.from(existingData[FS.completedLessons] ?? []);
    }
    // Garante que a lição atual está incluída no conjunto
    final completedSet = {...alreadyCompleted, lessonId};
    final totalLessons = getLessonsForModule(modId).length;
    final double updatedProgress = totalLessons > 0
        ? (completedSet.length / totalLessons).clamp(0.0, 1.0)
        : 1.0; // Se o módulo não está no registry, assume completo
    final bool moduleCompleted = updatedProgress >= 1.0;

    batch.update(pRef, {
      FS.completedLessons: FieldValue.arrayUnion([lessonId]),
      FS.lastAccessed: FieldValue.serverTimestamp(),
      FS.progressPercent: double.parse(updatedProgress.toStringAsFixed(2)),
      FS.isCompleted: moduleCompleted,
      if (moduleCompleted) FS.completedAt: FieldValue.serverTimestamp(),
    });

    final newXp = userData.xp + xpEarned;

    batch.update(userRef, {
      FS.xp: FieldValue.increment(xpEarned),
      FS.weeklyXp: FieldValue.increment(xpEarned),
      FS.monthlyXp: FieldValue.increment(xpEarned),
      FS.sparkPoints: FieldValue.increment(spEarned),
      FS.tensionLevel: _calcTension(newXp),
      FS.totalLessonsCompleted: FieldValue.increment(1),
    });

    if (userData.clanId != null && userData.clanId!.isNotEmpty) {
       final clanRef = _fs.collection(FS.clans).doc(userData.clanId);
       batch.update(clanRef, {
         FS.totalXp: FieldValue.increment(xpEarned),
         FS.weeklyXp: FieldValue.increment(xpEarned),
       });
       
       final memberRef = clanRef.collection(FS.members).doc(uid);
       batch.update(memberRef, {
         'xpContribution': FieldValue.increment(xpEarned),
         'weeklyContribution': FieldValue.increment(xpEarned),
       });
    }

    await batch.commit();

    // Invoca verificação de badging após conclusão no banco global.
    await AchievementService().checkLessonAchievements(uid, userData.totalLessonsCompleted + 1);
  }

  Future<bool> isModuleUnlocked(String uid, String requiredModuleId) async {
    final progress = await getProgress(uid, requiredModuleId);
    return progress?.isCompleted ?? false;
  }

  Future<void> saveBestScore(String uid, String modId, int score) async {
    final p = await getProgress(uid, modId);
    if (p != null && score > p.bestScore) {
      await _fs.collection(FS.users).doc(uid).collection(FS.progress).doc(p.id).update({
        FS.bestScore: score,
        FS.lastAccessed: FieldValue.serverTimestamp(),
      });
    }
  }
}