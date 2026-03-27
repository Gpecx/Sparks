import 'package:flutter/material.dart';

/// Manages daily streak tracking and XP multipliers.
class StreakService extends ChangeNotifier {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  // Mock state
  int _currentStreak = 7;
  int _longestStreak = 14;
  bool _studiedToday = true;
  DateTime _lastStudyDate = DateTime.now();

  // Getters
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  bool get studiedToday => _studiedToday;
  DateTime get lastStudyDate => _lastStudyDate;

  /// XP multiplier based on streak length.
  double get xpMultiplier {
    if (_currentStreak >= 30) return 2.0;
    if (_currentStreak >= 7) return 1.5;
    if (_currentStreak >= 3) return 1.2;
    return 1.0;
  }

  String get xpMultiplierLabel => 'x${xpMultiplier.toStringAsFixed(1)}';

  /// Whether streak is at risk (not studied today and it's past noon).
  bool get isAtRisk {
    if (_studiedToday) return false;
    return DateTime.now().hour >= 12;
  }

  /// Check if streak qualifies for a badge.
  String? get streakBadge {
    if (_currentStreak >= 100) return '🔥 Lendário (100 dias)';
    if (_currentStreak >= 30) return '🔥 Mestre (30 dias)';
    if (_currentStreak >= 7) return '🔥 Dedicado (7 dias)';
    return null;
  }

  /// Register today's study activity.
  void registerStudy() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    
    if (_lastStudyDate.day == now.day && _lastStudyDate.month == now.month) {
      // Already studied today
      return;
    }
    
    if (_lastStudyDate.day == yesterday.day &&
        _lastStudyDate.month == yesterday.month &&
        _lastStudyDate.year == yesterday.year) {
      // Consecutive day
      _currentStreak++;
    } else if (_lastStudyDate.day != now.day) {
      // Streak broken
      _currentStreak = 1;
    }
    
    _studiedToday = true;
    _lastStudyDate = now;
    if (_currentStreak > _longestStreak) _longestStreak = _currentStreak;
    notifyListeners();
  }

  /// Use spark points to "resurrect" a lost streak.
  /// Returns true if streak was restored.
  bool resurrectStreak(int previousStreak) {
    _currentStreak = previousStreak;
    _studiedToday = true;
    _lastStudyDate = DateTime.now();
    notifyListeners();
    return true;
  }

  /// Cost to resurrect based on streak length.
  int get resurrectCost {
    if (_currentStreak >= 30) return 200;
    if (_currentStreak >= 7) return 100;
    return 50;
  }
}
