import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Types of intelligent notifications the app can send.
enum NotificationType {
  streakAtRisk,
  friendOnline,
  dailyChallenge,
  newTournament,
  achievementUnlocked,
  matchChallenge,
  clanInvite,
  system
}

class SparkNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String emoji;
  final DateTime createdAt;
  final bool read;

  const SparkNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.emoji,
    required this.createdAt,
    this.read = false,
  });

  factory SparkNotification.fromMap(String id, Map<String, dynamic> data) {
    return SparkNotification(
      id: id,
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.system,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      emoji: data['emoji'] ?? '🔔',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'title': title,
      'body': body,
      'emoji': emoji,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
    };
  }
}

/// Notification service for real-time Firestore notifications.
class NotificationService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
  StreamSubscription<QuerySnapshot>? _subscription;

  // ---- User preferences (persisted in SharedPreferences) ----
  bool silentMode = false;          // pausa todas as notificações
  bool quietHoursEnabled = true;    // sem notificações em horário silencioso
  String frequency = 'Normal';      // 'Mínima' | 'Normal' | 'Alta'
  int quietStartHour = 22;
  int quietEndHour = 7;

  // Toggles por tipo de alerta
  bool streakAlerts = true;
  bool friendActivity = true;
  bool dailyChallengeAlert = true;
  bool tournamentAlerts = true;
  bool achievementAlerts = true;

  bool _prefsLoaded = false;
  bool get prefsLoaded => _prefsLoaded;

  static const _kSilent = 'notif_silent_mode';
  static const _kQuiet = 'notif_quiet_hours';
  static const _kFreq = 'notif_frequency';
  static const _kStreak = 'notif_type_streak';
  static const _kFriend = 'notif_type_friend';
  static const _kDaily = 'notif_type_daily';
  static const _kTournament = 'notif_type_tournament';
  static const _kAchievement = 'notif_type_achievement';

  NotificationService() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    silentMode = p.getBool(_kSilent) ?? silentMode;
    quietHoursEnabled = p.getBool(_kQuiet) ?? quietHoursEnabled;
    frequency = p.getString(_kFreq) ?? frequency;
    streakAlerts = p.getBool(_kStreak) ?? streakAlerts;
    friendActivity = p.getBool(_kFriend) ?? friendActivity;
    dailyChallengeAlert = p.getBool(_kDaily) ?? dailyChallengeAlert;
    tournamentAlerts = p.getBool(_kTournament) ?? tournamentAlerts;
    achievementAlerts = p.getBool(_kAchievement) ?? achievementAlerts;
    _prefsLoaded = true;
    notifyListeners();
  }

  Future<void> _saveBool(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  Future<void> setSilentMode(bool v) async {
    silentMode = v;
    notifyListeners();
    await _saveBool(_kSilent, v);
  }

  Future<void> setQuietHoursEnabled(bool v) async {
    quietHoursEnabled = v;
    notifyListeners();
    await _saveBool(_kQuiet, v);
  }

  Future<void> setFrequency(String v) async {
    frequency = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kFreq, v);
  }

  Future<void> setStreakAlerts(bool v) async {
    streakAlerts = v;
    notifyListeners();
    await _saveBool(_kStreak, v);
  }

  Future<void> setFriendActivity(bool v) async {
    friendActivity = v;
    notifyListeners();
    await _saveBool(_kFriend, v);
  }

  Future<void> setDailyChallengeAlert(bool v) async {
    dailyChallengeAlert = v;
    notifyListeners();
    await _saveBool(_kDaily, v);
  }

  Future<void> setTournamentAlerts(bool v) async {
    tournamentAlerts = v;
    notifyListeners();
    await _saveBool(_kTournament, v);
  }

  Future<void> setAchievementAlerts(bool v) async {
    achievementAlerts = v;
    notifyListeners();
    await _saveBool(_kAchievement, v);
  }

  List<SparkNotification> _notifications = [];

  /// Notificações já filtradas pelas preferências do usuário.
  List<SparkNotification> get notifications {
    if (silentMode) return const [];
    if (quietHoursEnabled && _isQuietHourNow()) return const [];
    return List.unmodifiable(_notifications.where(_isAllowed));
  }

  int get unreadCount => notifications.where((n) => !n.read).length;

  bool _isQuietHourNow() {
    final hour = DateTime.now().hour;
    // Intervalo que cruza a meia-noite (ex.: 22h–7h).
    if (quietStartHour > quietEndHour) {
      return hour >= quietStartHour || hour < quietEndHour;
    }
    return hour >= quietStartHour && hour < quietEndHour;
  }

  bool _isAllowed(SparkNotification n) {
    // 1) Toggle específico do tipo
    switch (n.type) {
      case NotificationType.streakAtRisk:
        if (!streakAlerts) return false;
        break;
      case NotificationType.friendOnline:
        if (!friendActivity) return false;
        break;
      case NotificationType.dailyChallenge:
        if (!dailyChallengeAlert) return false;
        break;
      case NotificationType.newTournament:
        if (!tournamentAlerts) return false;
        break;
      case NotificationType.achievementUnlocked:
        if (!achievementAlerts) return false;
        break;
      default:
        break;
    }
    // 2) Frequência de alertas (gate por prioridade)
    return _priority(n.type) >= _minPriority;
  }

  // Prioridade do tipo: 3 = essencial, 2 = importante, 1 = social/baixa.
  int _priority(NotificationType t) {
    switch (t) {
      case NotificationType.streakAtRisk:
      case NotificationType.matchChallenge:
      case NotificationType.clanInvite:
      case NotificationType.system:
        return 3;
      case NotificationType.achievementUnlocked:
      case NotificationType.newTournament:
      case NotificationType.dailyChallenge:
        return 2;
      case NotificationType.friendOnline:
        return 1;
    }
  }

  int get _minPriority {
    switch (frequency) {
      case 'Mínima':
        return 3; // só essenciais
      case 'Alta':
        return 1; // tudo
      default:
        return 2; // Normal: essenciais + importantes
    }
  }

  /// Start listening to notifications for a specific user.
  void startListening(String uid) {
    if (_subscription != null) return;
    
    _subscription = _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      _notifications = snapshot.docs
          .map((doc) => SparkNotification.fromMap(doc.id, doc.data()))
          .toList();
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error listening to notifications: $error');
    });
  }

  /// Stop listening to notifications and clear state.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _notifications.clear();
    notifyListeners();
  }

  /// Mark all notifications as read for the user.
  ///
  /// Não filtramos por `where('read', isEqualTo: false)`: docs criados sem o
  /// campo `read` (ex.: notificação de level-up) não casam com essa query e
  /// ficavam "presos" como não lidos para sempre. Varremos todos os docs e
  /// marcamos como lidos os que ainda não estão.
  Future<void> markAllRead(String uid) async {
    final all = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();

    final batch = _db.batch();
    var pending = 0;
    for (final doc in all.docs) {
      if (doc.data()['read'] == true) continue;
      batch.update(doc.reference, {'read': true});
      pending++;
    }
    if (pending == 0) return;
    await batch.commit();

    // Reflete imediatamente na UI mesmo antes do snapshot do stream chegar.
    _notifications = _notifications
        .map((n) => n.read
            ? n
            : SparkNotification(
                id: n.id,
                type: n.type,
                title: n.title,
                body: n.body,
                emoji: n.emoji,
                createdAt: n.createdAt,
                read: true,
              ))
        .toList();
    notifyListeners();
  }
  
  /// Delete a specific notification.
  Future<void> deleteNotification(String uid, String notifId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .delete();
  }
  
  /// Mark a specific notification as read.
  Future<void> markAsRead(String uid, String notifId) async {
     await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});
  }

  /// Pode disparar um alerta agora? (útil para push/FCM futuro)
  bool shouldShowNotification() {
    if (silentMode) return false;
    if (quietHoursEnabled && _isQuietHourNow()) return false;
    return true;
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
