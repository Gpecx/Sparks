import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;

  // User preferences
  bool silentMode = false;
  bool scheduleEnabled = true;
  String frequency = 'normal'; // 'minimal', 'normal', 'all'
  int quietStartHour = 22;
  int quietEndHour = 7;

  List<SparkNotification> _notifications = [];
  List<SparkNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.read).length;

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
  Future<void> markAllRead(String uid) async {
    final batch = _db.batch();
    final unreadDocs = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
        
    for (final doc in unreadDocs.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
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

  bool shouldShowNotification() {
    if (silentMode) return false;
    final hour = DateTime.now().hour;
    if (scheduleEnabled && (hour >= quietStartHour || hour < quietEndHour)) return false;
    return true;
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
