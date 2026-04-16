import 'package:flutter/material.dart';
import 'package:spark_app/services/user_service.dart';

/// StreakService — agora delega ao UserService (Firebase) para
/// dados persistidos. Mantido para compatibilidade com código existente.
class StreakService extends ChangeNotifier {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  final UserService _userService = UserService();

  // ✅ Lê do Firebase via UserService
  int get currentStreak => _userService.currentStreak;
  int get longestStreak => _userService.longestStreak;
  bool get studiedToday => _userService.studiedToday;

  double get xpMultiplier => _userService.xpMultiplier;
  String get xpMultiplierLabel => _userService.xpMultiplierLabel;
  bool get isAtRisk => _userService.isStreakAtRisk;

  /// Verifica se o streak qualifica para algum badge.
  String? get streakBadge {
    if (currentStreak >= 100) return '🔥 Lendário (100 dias)';
    if (currentStreak >= 30) return '🔥 Mestre (30 dias)';
    if (currentStreak >= 7) return '🔥 Dedicado (7 dias)';
    return null;
  }

  // ✅ Registra no Firebase e notifica ouvintes locais
  Future<void> registerStudy() async {
    await _userService.registerStudyActivity();
    notifyListeners();
  }

  /// Ressurreição de streak com Spark Points.
  Future<bool> resurrectStreak(int previousStreak) async {
    final success = await _userService.resurrectStreak(previousStreak);
    if (success) notifyListeners();
    return success;
  }

  /// Custo de ressurreição baseado no nível do usuário.
  int get resurrectCost {
    final level = _userService.level;
    if (level >= 30) return 200;
    if (level >= 7) return 100;
    return 50;
  }
}
