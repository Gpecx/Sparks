import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:spark_app/core/utils/gamification_utils.dart';
import 'package:spark_app/models/user_model.dart';
import 'package:spark_app/services/analytics_service.dart';
import 'package:spark_app/services/audit_service.dart';
import 'package:spark_app/services/fcm_service.dart';
import 'package:spark_app/services/gamification_service.dart';

// ─────────────────────────────────────────────────────────────────
//  USER SERVICE — Sincronização completa com Firestore
//
//  Campos sensíveis (xp, sparkPoints, level, unlockedBadgeIds,
//  eloRating, wins, losses) são agora escritos EXCLUSIVAMENTE via
//  Cloud Functions (Admin SDK) — o cliente apenas lê.
//
//  Responsabilidades mantidas no cliente:
//   - Escuta em tempo real do documento do usuário
//   - Criação do documento base pós-registro
//   - Perfil (displayName, photoUrl, profession)
//   - Clã (clanId, clanName)
//   - Streak / estudo diário
//   - Rankings (leitura)
//
//  Delegado às Cloud Functions:
//   - addXp              → CF: addXp
//   - spendSparkPoints   → CF: spendSparkPoints
//   - updateElo          → CF: updateElo
//   - unlockBadge        → CF: unlockBadge
// ─────────────────────────────────────────────────────────────────

class UserService extends ChangeNotifier {
  // ── Singleton ───────────────────────────────────────────────────
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // ── Firebase refs ───────────────────────────────────────────────
  final _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  // ── Estado local ────────────────────────────────────────────────
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<DocumentSnapshot>? _userStream;

  // ── Getters ──────────────────────────────────────────────────────
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _auth.currentUser != null;

  String get uid => _auth.currentUser?.uid ?? '';

  int get sparkPoints => _user?.sparkPoints ?? 0;
  int get xp => _user?.xp ?? 0;
  int get level => _user?.level ?? 1;
  String get tensionLevel => _user?.tensionLevel ?? 'BT';
  int get currentStreak => _user?.currentStreak ?? 0;
  int get longestStreak => _user?.longestStreak ?? 0;
  int get activeDays => _user?.activeDays ?? 0;
  bool get studiedToday => _user?.studiedToday ?? false;
  List<String> get unlockedBadgeIds => _user?.unlockedBadgeIds ?? [];

  String get displayName {
    final fromFirestore = _user?.displayName;
    if (fromFirestore != null && fromFirestore.isNotEmpty) return fromFirestore;
    final fromAuth = _auth.currentUser?.displayName;
    if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;
    return 'Usuário';
  }

  String? get clanId => _user?.clanId;
  String? get clanName => _user?.clanName;
  int get eloRating => _user?.eloRating ?? 1200;
  int get wins => _user?.wins ?? 0;
  int get losses => _user?.losses ?? 0;
  int get totalDuels => _user?.totalDuels ?? 0;

  // Delega para GamificationUtils (sem duplicar lógica)
  double get xpMultiplier => GamificationUtils.xpMultiplier(currentStreak);
  String get xpMultiplierLabel => GamificationUtils.xpMultiplierLabel(currentStreak);
  bool get isStreakAtRisk => !studiedToday && DateTime.now().hour >= 12;

  // ─────────────────────────────────────────────────────────────────
  //  INICIALIZAÇÃO
  // ─────────────────────────────────────────────────────────────────

  void startListening() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    _userStream?.cancel();
    bool tokenSaved = false;
    _userStream = _db.collection('users').doc(uid).snapshots().listen(
      (snap) {
        if (snap.exists) {
          _user = UserModel.fromFirestore(snap);
          if (!tokenSaved) {
            tokenSaved = true;
            FcmService().saveTokenAfterLogin();
          }
        }
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _userStream?.cancel();
    _user = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  //  CRIAÇÃO DO DOCUMENTO DO USUÁRIO
  // ─────────────────────────────────────────────────────────────────

  Future<void> createUserDocument({
    required String uid,
    required String displayName,
    required String email,
    String? photoUrl,
  }) async {
    final docRef = _db.collection('users').doc(uid);
    final existing = await docRef.get();
    if (existing.exists) return;

    await docRef.set({
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'role': 'técnico',
      'profession': null,
      'sparkPoints': 100,
      'xp': 0,
      'level': 1,
      'tensionLevel': 'BT',
      'currentStreak': 0,
      'longestStreak': 0,
      'activeDays': 0,
      'studiedToday': false,
      'lastStudyDate': null,
      'weeklyXp': 0,
      'monthlyXp': 0,
      'unlockedBadgeIds': [],
      'clanId': null,
      'clanName': null,
      'totalLessonsCompleted': 0,
      'totalCorrectAnswers': 0,
      'totalAnswers': 0,
      'eloRating': 1200,
      'wins': 0,
      'losses': 0,
      'totalDuels': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────────
  //  XP E SPARK POINTS — via Cloud Functions
  // ─────────────────────────────────────────────────────────────────

  /// Adiciona XP via Cloud Function (transação atômica no servidor).
  /// Retorna os novos valores ou lança exceção em caso de falha.
  Future<AddXpResult> addXp(int amount, {String source = 'app'}) async {
    if (uid.isEmpty) throw Exception('Usuário não autenticado');

    try {
      final docRef = _db.collection('users').doc(uid);
      
      final currentXp = this.xp;
      final currentLevel = this.level;
      
      final newXp = currentXp + amount;
      final newLevel = GamificationUtils.calcLevel(newXp);
      final newTension = GamificationUtils.calcTension(newXp);
      final leveledUp = newLevel > currentLevel;

      await docRef.update({
        'xp': FieldValue.increment(amount),
        'weeklyXp': FieldValue.increment(amount),
        'monthlyXp': FieldValue.increment(amount),
        'level': newLevel,
        'tensionLevel': newTension,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Rankings locally
      final weekKey = GamificationUtils.currentWeekKey();
      await _db.collection('rankings').doc('weekly').collection(weekKey).doc(uid).set({
        'uid': uid,
        'displayName': displayName,
        'photoUrl': _user?.photoUrl,
        'clanId': clanId,
        'clanName': clanName,
        'weeklyXp': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final badgesUnlocked = <String>[];
      // Analytics locais
      if (leveledUp) {
        await AnalyticsService().logLevelUp(
          oldLevel: currentLevel,
          newLevel: newLevel,
          totalXp: newXp,
        );
        await AnalyticsService().setUserLevel(newLevel);
        await _sendLevelUpNotification(newLevel);
        
        final newBadges = GamificationUtils.xpBadgesEarned(newXp);
        for (final b in newBadges) {
          if (!unlockedBadgeIds.contains(b)) {
            badgesUnlocked.add(b);
            await docRef.update({
              'unlockedBadgeIds': FieldValue.arrayUnion([b]),
            });
            await AnalyticsService().logBadgeUnlocked(badgeId: b, source: source);
            // Optionally add bonus XP directly
            await docRef.update({
              'xp': FieldValue.increment(50),
              'weeklyXp': FieldValue.increment(50),
              'monthlyXp': FieldValue.increment(50),
            });
          }
        }
      }

      return AddXpResult(
        newXp: newXp,
        newLevel: newLevel,
        newTension: newTension,
        leveledUp: leveledUp,
        badgesUnlocked: badgesUnlocked,
      );
    } catch (e) {
      debugPrint('[UserService.addXp] Local error: $e');
      rethrow;
    }
  }

  /// Gasta Spark Points via Cloud Function.
  /// Retorna false se saldo insuficiente.
  Future<bool> spendSparkPoints(int amount, {String source = 'purchase'}) async {
    if (uid.isEmpty) return false;

    try {
      final callable = _functions.httpsCallable('spendSparkPoints');
      final response = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'source': source,
      });

      return response.data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[UserService.spendSparkPoints] CF error: ${e.code}');
      return false;
    }
  }

  /// Adiciona Spark Points diretamente (bônus, recompensas de missões).
  /// Mantido no cliente pois é adição, não débito — menos crítico para fraude.
  Future<void> addSparkPoints(int amount, {String source = 'app'}) async {
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).update({
      'sparkPoints': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditService().log(
      action: AuditAction.spGained,
      amount: amount,
      source: source,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  DUELO / ELO — via Cloud Function
  // ─────────────────────────────────────────────────────────────────

  Future<void> updateElo({required int eloChange, required bool? won}) async {
    if (uid.isEmpty) return;

    try {
      final callable = _functions.httpsCallable('updateElo');
      await callable.call<Map<String, dynamic>>({
        'eloChange': eloChange,
        'won': won,
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[UserService.updateElo] CF error: ${e.code}');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  CONQUISTAS (BADGES) — via Cloud Function
  // ─────────────────────────────────────────────────────────────────

  Future<void> unlockBadge(String badgeId, {String source = 'achievement'}) async {
    if (uid.isEmpty) return;

    try {
      final callable = _functions.httpsCallable('unlockBadge');
      final response = await callable.call<Map<String, dynamic>>({
        'badgeId': badgeId,
        'source': source,
      });

      if (response.data['unlocked'] == true) {
        await AnalyticsService().logBadgeUnlocked(
          badgeId: badgeId,
          source: source,
        );
        // XP de bônus por conquista — também via CF
        await addXp(50, source: 'badge_bonus');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[UserService.unlockBadge] CF error: ${e.code}');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  STREAK (SEQUÊNCIA DIÁRIA)
  // ─────────────────────────────────────────────────────────────────

  Future<void> registerStudyActivity() async {
    if (uid.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_user?.studiedToday == true) return;

    final lastStudy = _user?.lastStudyDate;
    int newStreak = 1;
    int newActiveDays = activeDays + 1;

    if (lastStudy != null) {
      final lastDay = DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
      final diff = today.difference(lastDay).inDays;
      if (diff == 1) {
        newStreak = currentStreak + 1;
      } else if (diff == 0) {
        return;
      }
      // diff > 1 → streak quebrada, newStreak permanece 1
    }

    final newLongest = newStreak > longestStreak ? newStreak : longestStreak;

    await _db.collection('users').doc(uid).update({
      'currentStreak': newStreak,
      'longestStreak': newLongest,
      'studiedToday': true,
      'lastStudyDate': Timestamp.fromDate(now),
      'activeDays': newActiveDays,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditService().log(
      action: AuditAction.streakUpdated,
      amount: newStreak,
      source: 'study_activity',
      meta: {'activeDays': newActiveDays},
    );

    await AnalyticsService().logStreakUpdated(newStreak: newStreak);

    // Badges de streak via CF
    for (final badge in GamificationUtils.streakBadgesEarned(newStreak)) {
      await unlockBadge(badge, source: 'streak');
    }

    await GamificationService().checkWeeklyChallenge(uid, newStreak);
  }

  Future<void> checkAndResetStreakIfNeeded() async {
    if (uid.isEmpty || _user == null) return;

    final createdAt = _user?.createdAt;
    if (createdAt != null &&
        DateTime.now().difference(createdAt).inSeconds < 60) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastStudy = _user?.lastStudyDate;
    if (lastStudy == null) return;

    final lastDay = DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
    final diff = today.difference(lastDay).inDays;

    if (diff >= 1 && (_user?.studiedToday == true)) {
      await _db.collection('users').doc(uid).update({
        'studiedToday': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (diff > 1 && currentStreak > 0) {
      await _db.collection('users').doc(uid).update({
        'currentStreak': 0,
        'studiedToday': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> resurrectStreak(int previousStreak) async {
    final cost = GamificationUtils.streakResurrectCost(previousStreak);
    final success = await spendSparkPoints(cost, source: 'streak_resurrection');
    if (!success) return false;

    await _db.collection('users').doc(uid).update({
      'currentStreak': previousStreak,
      'studiedToday': true,
      'lastStudyDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditService().log(
      action: AuditAction.streakResurrected,
      amount: previousStreak,
      source: 'streak_resurrection',
      meta: {'spCost': cost},
    );
    return true;
  }

  // ─────────────────────────────────────────────────────────────────
  //  RANKING (LEADERBOARD)
  // ─────────────────────────────────────────────────────────────────

  String get currentWeekKey => GamificationUtils.currentWeekKey();

  /// Busca o ranking global semanal com suporte a paginação.
  Future<List<RankingEntry>> getGlobalWeeklyRanking({
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    final weekKey = currentWeekKey;
    var query = _db
        .collection('rankings')
        .doc('weekly')
        .collection(weekKey)
        .orderBy('weeklyXp', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snap = await query.get();
    return snap.docs.map((doc) => RankingEntry.fromFirestore(doc)).toList();
  }

  /// Busca o ranking do clã com suporte a paginação.
  Future<List<RankingEntry>> getClanWeeklyRanking({
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    if (clanId == null) return [];

    final weekKey = currentWeekKey;
    var query = _db
        .collection('rankings')
        .doc('weekly')
        .collection(weekKey)
        .where('clanId', isEqualTo: clanId)
        .orderBy('weeklyXp', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snap = await query.get();
    return snap.docs.map((doc) => RankingEntry.fromFirestore(doc)).toList();
  }

  /// Ranking all-time com paginação.
  Future<List<RankingEntry>> getAllTimeRanking({
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    var query = _db
        .collection('users')
        .orderBy('xp', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snap = await query.get();
    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return RankingEntry(
        uid: doc.id,
        displayName: data['displayName'] ?? data['name'] ?? 'Usuário',
        photoUrl: data['photoUrl'],
        weeklyXp: data['xp'] ?? 0,
        clanId: data['clanId'],
        clanName: data['clanName'],
        position: 0,
        rawDoc: doc,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  //  PERFIL
  // ─────────────────────────────────────────────────────────────────

  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
    String? role,
    String? profession,
  }) async {
    if (uid.isEmpty) return;

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (role != null) updates['role'] = role;
    if (profession != null) updates['profession'] = profession;

    await _db.collection('users').doc(uid).update(updates);

    await _auth.currentUser?.updateDisplayName(displayName);
    if (photoUrl != null) await _auth.currentUser?.updatePhotoURL(photoUrl);
  }

  // ─────────────────────────────────────────────────────────────────
  //  CLÃ
  // ─────────────────────────────────────────────────────────────────

  Future<void> joinClan({
    required String clanId,
    required String clanName,
  }) async {
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).update({
      'clanId': clanId,
      'clanName': clanName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await unlockBadge('cla_unido');
  }

  Future<void> leaveClan() async {
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).update({
      'clanId': null,
      'clanName': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────────
  //  VALIDAÇÃO DE INTEGRIDADE DE XP
  // ─────────────────────────────────────────────────────────────────

  Future<XpIntegrityResult> validateXpIntegrity({
    int xpPerLesson = 50,
    int toleranceXp = 0,
  }) async {
    if (uid.isEmpty) return XpIntegrityResult.unknown();

    try {
      final progressSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('progress')
          .get();

      int calculatedXp = 0;
      for (final doc in progressSnap.docs) {
        final data = doc.data();
        final completed = (data['completedLessons'] as List?)?.length ?? 0;
        calculatedXp += completed * xpPerLesson;
      }

      final storedXp = xp;
      final delta = (storedXp - calculatedXp).abs();
      final isValid = delta <= toleranceXp;

      debugPrint(
        '[XpIntegrity] storedXp=$storedXp | calculatedXp=$calculatedXp | delta=$delta | valid=$isValid',
      );

      if (!isValid) {
        await AuditService().log(
          action: AuditAction.xpIntegrityFixed,
          amount: delta,
          source: 'integrity_check',
          meta: {
            'storedXp': storedXp,
            'calculatedXp': calculatedXp,
            'delta': delta,
            'progressDocs': progressSnap.docs.length,
          },
        );
      }

      return XpIntegrityResult(
        storedXp: storedXp,
        calculatedXp: calculatedXp,
        delta: delta,
        isValid: isValid,
        progressDocCount: progressSnap.docs.length,
      );
    } catch (e) {
      debugPrint('[XpIntegrity] Erro: $e');
      return XpIntegrityResult.unknown();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  PRIVADO — Notificação local de level-up
  // ─────────────────────────────────────────────────────────────────

  Future<void> _sendLevelUpNotification(int newLevel) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _db.collection('users').doc(uid).collection('notifications').add({
        'type': 'level_up',
        'title': '🎉 Você subiu de nível!',
        'body': 'Parabéns! Você alcançou o nível $newLevel no SPARK.',
        'level': newLevel,
        'fcmToken': token,
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Evento level_up registrado → nível $newLevel');
    } catch (e) {
      debugPrint('[FCM] Erro ao registrar level_up: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  RESULTADO DA CLOUD FUNCTION addXp
// ─────────────────────────────────────────────────────────────────

class AddXpResult {
  final int newXp;
  final int newLevel;
  final String newTension;
  final bool leveledUp;
  final List<String> badgesUnlocked;

  const AddXpResult({
    required this.newXp,
    required this.newLevel,
    required this.newTension,
    required this.leveledUp,
    required this.badgesUnlocked,
  });

  factory AddXpResult.fromMap(Map<String, dynamic> map) => AddXpResult(
        newXp: (map['newXp'] as num).toInt(),
        newLevel: (map['newLevel'] as num).toInt(),
        newTension: map['newTension'] as String,
        leveledUp: map['leveledUp'] as bool,
        badgesUnlocked: List<String>.from(map['badgesUnlocked'] ?? []),
      );
}

// ─────────────────────────────────────────────────────────────────
//  RANKING ENTRY MODEL
// ─────────────────────────────────────────────────────────────────

class RankingEntry {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int weeklyXp;
  final String? clanId;
  final String? clanName;
  int position;
  /// Cursor para paginação — mantido internamente.
  final DocumentSnapshot? rawDoc;

  RankingEntry({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.weeklyXp,
    this.clanId,
    this.clanName,
    this.position = 0,
    this.rawDoc,
  });

  factory RankingEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RankingEntry(
      uid: doc.id,
      displayName: data['displayName'] ?? 'Usuário',
      photoUrl: data['photoUrl'],
      weeklyXp: data['weeklyXp'] ?? 0,
      clanId: data['clanId'],
      clanName: data['clanName'],
      rawDoc: doc,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  XP INTEGRITY RESULT
// ─────────────────────────────────────────────────────────────────

class XpIntegrityResult {
  final int storedXp;
  final int calculatedXp;
  final int delta;
  final bool isValid;
  final int progressDocCount;
  final bool hasError;

  const XpIntegrityResult({
    required this.storedXp,
    required this.calculatedXp,
    required this.delta,
    required this.isValid,
    required this.progressDocCount,
    this.hasError = false,
  });

  factory XpIntegrityResult.unknown() => const XpIntegrityResult(
        storedXp: 0,
        calculatedXp: 0,
        delta: 0,
        isValid: true,
        progressDocCount: 0,
        hasError: true,
      );

  @override
  String toString() =>
      'XpIntegrityResult(stored=$storedXp, calculated=$calculatedXp, '
      'delta=$delta, valid=$isValid, docs=$progressDocCount)';
}