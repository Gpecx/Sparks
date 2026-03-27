import 'dart:math';

/// Types of intelligent notifications the app can send.
enum NotificationType {
  streakAtRisk,
  friendOnline,
  dailyChallenge,
  newTournament,
  achievementUnlocked,
}

class SparkNotification {
  final NotificationType type;
  final String title;
  final String body;
  final String emoji;
  final DateTime createdAt;
  final bool read;

  const SparkNotification({
    required this.type,
    required this.title,
    required this.body,
    required this.emoji,
    required this.createdAt,
    this.read = false,
  });
}

/// Mock notification service for generating smart, non-spammy notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // User preferences
  bool silentMode = false;
  bool scheduleEnabled = true;
  String frequency = 'normal'; // 'minimal', 'normal', 'all'
  int quietStartHour = 22;
  int quietEndHour = 7;

  final List<SparkNotification> _notifications = [];
  List<SparkNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.read).length;

  /// Generate mock notifications based on user context.
  void generateMockNotifications() {
    _notifications.clear();
    final now = DateTime.now();
    _notifications.addAll([
      SparkNotification(
        type: NotificationType.streakAtRisk,
        title: 'Streak em risco! 🔥',
        body: 'Seu streak de 7 dias vence amanhã! Não perca.',
        emoji: '🔥',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      SparkNotification(
        type: NotificationType.friendOnline,
        title: 'Amigo online!',
        body: 'Maria está estudando NR-35 agora!',
        emoji: '👩‍💻',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      SparkNotification(
        type: NotificationType.dailyChallenge,
        title: 'Desafio diário pronto!',
        body: 'Seu desafio rápido está esperando ⏰',
        emoji: '🎯',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      SparkNotification(
        type: NotificationType.newTournament,
        title: 'Competição semanal!',
        body: 'Competição semanal começou! Você está em 12º',
        emoji: '🏆',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      SparkNotification(
        type: NotificationType.achievementUnlocked,
        title: 'Conquista desbloqueada!',
        body: 'Você desbloqueou a Badge "Teórico"',
        emoji: '💡',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  void markAllRead() {
    _notifications.clear();
  }

  bool shouldShowNotification() {
    if (silentMode) return false;
    final hour = DateTime.now().hour;
    if (scheduleEnabled && (hour >= quietStartHour || hour < quietEndHour)) return false;
    return true;
  }
}
