import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:spark_app/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────
//  USER SERVICE — Sincronização completa com Firestore
//
//  Responsabilidades:
//   - XP, Spark Points, Level, TensionLevel
//   - Streak diário (currentStreak, longestStreak, studiedToday)
//   - Conquistas (unlockedBadgeIds)
//   - Perfil (displayName, photoUrl, role)
//   - Clã (clanId, clanName)
//   - Rankings (global, clã, all-time)
//
//  NÃO gerencia (ver ProgressService e CovenantService):
//   - Progresso de lições → users/{uid}/progress
//   - Progresso de covenants → users/{uid}/covenants
// ─────────────────────────────────────────────────────────────────

class UserService extends ChangeNotifier {
  // ── Singleton ───────────────────────────────────────────────────
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // ── Firebase refs ───────────────────────────────────────────────
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

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

  // Atalhos convenientes — refletem o UserModel padronizado
  int get sparkPoints => _user?.sparkPoints ?? 0;
  int get xp => _user?.xp ?? 0;
  int get level => _user?.level ?? 1;
  String get tensionLevel => _user?.tensionLevel ?? 'BT';
  int get currentStreak => _user?.currentStreak ?? 0;
  int get longestStreak => _user?.longestStreak ?? 0;
  int get activeDays => _user?.activeDays ?? 0;
  bool get studiedToday => _user?.studiedToday ?? false;
  List<String> get unlockedBadgeIds => _user?.unlockedBadgeIds ?? [];
  String get displayName => _user?.displayName ?? 'Usuário';
  String? get clanId => _user?.clanId;
  String? get clanName => _user?.clanName;
  // Duelo
  int get eloRating => _user?.eloRating ?? 1200;
  int get wins => _user?.wins ?? 0;
  int get losses => _user?.losses ?? 0;
  int get totalDuels => _user?.totalDuels ?? 0;

  // ─────────────────────────────────────────────────────────────────
  //  INICIALIZAÇÃO
  // ─────────────────────────────────────────────────────────────────

  /// Inicia escuta em tempo real do usuário logado.
  void startListening() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    _userStream?.cancel();
    _userStream = _db.collection('users').doc(uid).snapshots().listen(
      (snap) {
        if (snap.exists) {
          _user = UserModel.fromFirestore(snap);
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

  /// Para a escuta (usar no logout).
  void stopListening() {
    _userStream?.cancel();
    _user = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  //  CRIAÇÃO DO DOCUMENTO DO USUÁRIO (pós-registro)
  // ─────────────────────────────────────────────────────────────────

  /// Cria o documento base no Firestore quando o usuário se registra.
  /// Esquema exato do UserModel — não inclui lessonProgress/covenantProgress.
  Future<void> createUserDocument({
    required String uid,
    required String displayName,
    required String email,
    String? photoUrl,
  }) async {
    final docRef = _db.collection('users').doc(uid);
    final existing = await docRef.get();
    if (existing.exists) return; // Não sobrescreve se já existe

    await docRef.set({
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'role': 'Técnico',
      'sparkPoints': 100, // Bônus de boas-vindas
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
      // Campos de duelo
      'eloRating': 1200,
      'wins': 0,
      'losses': 0,
      'totalDuels': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────────
  //  XP E SPARK POINTS
  // ─────────────────────────────────────────────────────────────────

  /// Adiciona XP e recalcula o nível e tensionLevel.
  Future<void> addXp(int amount) async {
    if (uid.isEmpty) return;

    final newXp = xp + amount;
    final newLevel = (newXp ~/ 500) + 1;
    final newWeeklyXp = (_user?.weeklyXp ?? 0) + amount;
    final newTension = _calcTension(newXp);

    await _db.collection('users').doc(uid).update({
      'xp': FieldValue.increment(amount),
      'weeklyXp': FieldValue.increment(amount),
      'monthlyXp': FieldValue.increment(amount),
      'level': newLevel,
      'tensionLevel': newTension,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _updateWeeklyRanking(newWeeklyXp);
    await _checkXpBadges(newXp);
  }

  String _calcTension(int totalXp) {
    if (totalXp < 5000) return 'BT';
    if (totalXp < 15000) return 'MT';
    if (totalXp < 30000) return 'AT';
    return 'EAT';
  }

  /// Adiciona Pontos Spark (moeda).
  Future<void> addSparkPoints(int amount) async {
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).update({
      'sparkPoints': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gasta Pontos Spark. Retorna false se saldo insuficiente.
  Future<bool> spendSparkPoints(int amount) async {
    if (uid.isEmpty || sparkPoints < amount) return false;
    await _db.collection('users').doc(uid).update({
      'sparkPoints': FieldValue.increment(-amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  // ─────────────────────────────────────────────────────────────────
  //  DUELO / ELO
  // ─────────────────────────────────────────────────────────────────

  /// Atualiza o resultado do duelo no Firestore.
  ///
  /// [eloChange] pode ser positivo (vitória) ou negativo (derrota) ou 0 (empate).
  /// [won] true = vitória, false = derrota, null = empate.
  Future<void> updateElo({required int eloChange, required bool? won}) async {
    if (uid.isEmpty) return;
    final Map<String, dynamic> data = {
      'eloRating': FieldValue.increment(eloChange),
      'totalDuels': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (won == true) data['wins'] = FieldValue.increment(1);
    if (won == false) data['losses'] = FieldValue.increment(1);

    await _db.collection('users').doc(uid).update(data);

    // Badge de primeiro duelo
    if (totalDuels == 0) {
      await unlockBadge('primeiro_duelo');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  STREAK (SEQUÊNCIA DIÁRIA)
  // ─────────────────────────────────────────────────────────────────

  /// Registra atividade de estudo. Atualiza streak e dias ativos.
  Future<void> registerStudyActivity() async {
    if (uid.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_user?.studiedToday == true) return;

    final lastStudy = _user?.lastStudyDate;
    int newStreak = 1;
    int newActiveDays = activeDays + 1;

    if (lastStudy != null) {
      final lastDay =
          DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
      final diff = today.difference(lastDay).inDays;

      if (diff == 1) {
        newStreak = currentStreak + 1;
      } else if (diff == 0) {
        return;
      } else {
        newStreak = 1;
      }
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

    await _checkStreakBadges(newStreak);
  }

  /// Verifica e reseta o streak se o usuário não estudou.
  Future<void> checkAndResetStreakIfNeeded() async {
    if (uid.isEmpty || _user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastStudy = _user?.lastStudyDate;

    if (lastStudy == null) return;

    final lastDay =
        DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
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

  /// Ressurreição de streak com Spark Points.
  Future<bool> resurrectStreak(int previousStreak) async {
    final cost = _getResurrectCost(previousStreak);
    final success = await spendSparkPoints(cost);
    if (!success) return false;

    await _db.collection('users').doc(uid).update({
      'currentStreak': previousStreak,
      'studiedToday': true,
      'lastStudyDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  int _getResurrectCost(int streak) {
    if (streak >= 30) return 200;
    if (streak >= 7) return 100;
    return 50;
  }

  // ─────────────────────────────────────────────────────────────────
  //  CONQUISTAS (BADGES)
  // ─────────────────────────────────────────────────────────────────

  /// Desbloqueia uma conquista se ainda não foi desbloqueada.
  Future<void> unlockBadge(String badgeId) async {
    if (uid.isEmpty) return;
    if (unlockedBadgeIds.contains(badgeId)) return;

    await _db.collection('users').doc(uid).update({
      'unlockedBadgeIds': FieldValue.arrayUnion([badgeId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Bônus de XP por conquista
    await addXp(50);
  }

  Future<void> _checkStreakBadges(int streak) async {
    if (streak >= 7) await unlockBadge('streak_7');
    if (streak >= 30) await unlockBadge('streak_30');
    if (streak >= 100) await unlockBadge('streak_100');
  }

  Future<void> _checkXpBadges(int totalXp) async {
    if (totalXp >= 1000) await unlockBadge('xp_1000');
    if (totalXp >= 5000) await unlockBadge('xp_5000');
    if (totalXp >= 10000) await unlockBadge('xp_10000');
  }

  // ─────────────────────────────────────────────────────────────────
  //  RANKING (LEADERBOARD)
  // ─────────────────────────────────────────────────────────────────

  String get currentWeekKey {
    final now = DateTime.now();
    final weekNum = _getWeekNumber(now);
    return '${now.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  int _getWeekNumber(DateTime date) {
    final dayOfYear =
        date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Future<void> _updateWeeklyRanking(int weeklyXp) async {
    if (uid.isEmpty) return;

    final weekKey = currentWeekKey;
    final rankingDoc = _db
        .collection('rankings')
        .doc('weekly')
        .collection(weekKey)
        .doc(uid);

    await rankingDoc.set({
      'uid': uid,
      'displayName': displayName,
      'photoUrl': _user?.photoUrl,
      'weeklyXp': weeklyXp,
      'clanId': clanId,
      'clanName': clanName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<RankingEntry>> getGlobalWeeklyRanking() async {
    final weekKey = currentWeekKey;
    final snap = await _db
        .collection('rankings')
        .doc('weekly')
        .collection(weekKey)
        .orderBy('weeklyXp', descending: true)
        .limit(50)
        .get();

    return snap.docs
        .map((doc) => RankingEntry.fromFirestore(doc))
        .toList();
  }

  Future<List<RankingEntry>> getClanWeeklyRanking() async {
    if (clanId == null) return [];

    final weekKey = currentWeekKey;
    final snap = await _db
        .collection('rankings')
        .doc('weekly')
        .collection(weekKey)
        .where('clanId', isEqualTo: clanId)
        .orderBy('weeklyXp', descending: true)
        .get();

    return snap.docs
        .map((doc) => RankingEntry.fromFirestore(doc))
        .toList();
  }

  Future<List<RankingEntry>> getAllTimeRanking() async {
    final snap = await _db
        .collection('users')
        .orderBy('xp', descending: true)
        .limit(50)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return RankingEntry(
        uid: doc.id,
        displayName: data['displayName'] ?? data['name'] ?? 'Usuário',
        photoUrl: data['photoUrl'],
        weeklyXp: data['xp'] ?? 0,
        clanId: data['clanId'],
        clanName: data['clanName'],
        position: 0,
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
  }) async {
    if (uid.isEmpty) return;

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (role != null) updates['role'] = role;

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
  //  XP MULTIPLIER (STREAK BONUS)
  // ─────────────────────────────────────────────────────────────────

  double get xpMultiplier {
    if (currentStreak >= 30) return 2.0;
    if (currentStreak >= 7) return 1.5;
    if (currentStreak >= 3) return 1.2;
    return 1.0;
  }

  String get xpMultiplierLabel => 'x${xpMultiplier.toStringAsFixed(1)}';

  bool get isStreakAtRisk {
    if (studiedToday) return false;
    return DateTime.now().hour >= 12;
  }
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

  RankingEntry({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.weeklyXp,
    this.clanId,
    this.clanName,
    this.position = 0,
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
    );
  }
}