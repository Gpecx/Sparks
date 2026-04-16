import 'package:spark_app/services/user_service.dart';

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  /// Verifica se o usuário deve receber badges baseado no streak atual.
  Future<void> checkStreakAchievements(String uid, int streak) async {
    final Map<int, String> streakBadges = {
      3: 'streak_3_days',
      7: 'streak_7_days',
      30: 'streak_30_days',
    };

    if (streakBadges.containsKey(streak)) {
      // unlockBadge é singleton e usa o uid do usuário logado internamente
      await UserService().unlockBadge(streakBadges[streak]!);
    }
  }

  /// Verifica se o usuário deve receber badges baseado na quantia total de lições feitas.
  Future<void> checkLessonAchievements(String uid, int totalLessonsCompleted) async {
    final Map<int, String> lessonBadges = {
      1: 'first_lesson',
      10: 'lesson_10',
      50: 'lesson_50',
      100: 'lesson_100',
    };

    if (lessonBadges.containsKey(totalLessonsCompleted)) {
      await UserService().unlockBadge(lessonBadges[totalLessonsCompleted]!);
    }
  }
}
