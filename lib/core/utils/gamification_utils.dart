// ─────────────────────────────────────────────────────────────────
//  GAMIFICATION UTILS — Cálculos matemáticos puros de gamificação
//
//  Contém apenas lógica stateless sem dependências de Firebase/Flutter.
//  Objetivo: facilitar testes unitários e desacoplar a regra de negócio
//  do UserService.
//
//  Uso:
//    final level  = GamificationUtils.calcLevel(xp);
//    final tension = GamificationUtils.calcTension(xp);
//    final cost    = GamificationUtils.streakResurrectCost(streak);
// ─────────────────────────────────────────────────────────────────

abstract class GamificationUtils {
  // ─── Nível ──────────────────────────────────────────────────────

  /// Calcula o nível a partir do XP total.
  /// Regra: 1 nível a cada 500 XP (mínimo 1).
  static int calcLevel(int totalXp) => (totalXp ~/ 500) + 1;

  // ─── Tension Level ───────────────────────────────────────────────

  /// Retorna o tensionLevel baseado no XP total acumulado.
  ///
  /// BT  = abaixo de 5.000 XP
  /// MT  = 5.000 – 14.999 XP
  /// AT  = 15.000 – 29.999 XP
  /// EAT = 30.000+ XP
  static String calcTension(int totalXp) {
    if (totalXp < 5000) return 'BT';
    if (totalXp < 15000) return 'MT';
    if (totalXp < 30000) return 'AT';
    return 'EAT';
  }

  // ─── Multiplicador de XP (streak bonus) ──────────────────────────

  /// Retorna o multiplicador de XP baseado no streak atual.
  ///
  /// streak >= 30 → 2.0x
  /// streak >= 7  → 1.5x
  /// streak >= 3  → 1.2x
  /// streak < 3   → 1.0x (sem bônus)
  static double xpMultiplier(int currentStreak) {
    if (currentStreak >= 30) return 2.0;
    if (currentStreak >= 7) return 1.5;
    if (currentStreak >= 3) return 1.2;
    return 1.0;
  }

  /// Versão formatada para exibição na UI (ex: "x1.5").
  static String xpMultiplierLabel(int currentStreak) =>
      'x${xpMultiplier(currentStreak).toStringAsFixed(1)}';

  // ─── Streak resurrection ─────────────────────────────────────────

  /// Custo em Spark Points para ressuscitar um streak perdido.
  ///
  /// streak >= 30 → 200 SP
  /// streak >= 7  → 100 SP
  /// streak < 7   →  50 SP
  static int streakResurrectCost(int previousStreak) {
    if (previousStreak >= 30) return 200;
    if (previousStreak >= 7) return 100;
    return 50;
  }

  // ─── XP Badges thresholds ────────────────────────────────────────

  /// Retorna os IDs de badge desbloqueados com base no XP total.
  /// Útil tanto no cliente quanto nas Cloud Functions.
  static List<String> xpBadgesEarned(int totalXp) {
    final badges = <String>[];
    if (totalXp >= 1000) badges.add('xp_1000');
    if (totalXp >= 5000) badges.add('xp_5000');
    if (totalXp >= 10000) badges.add('xp_10000');
    return badges;
  }

  /// Retorna os IDs de badge desbloqueados com base no streak.
  static List<String> streakBadgesEarned(int streak) {
    final badges = <String>[];
    if (streak >= 7) badges.add('streak_7');
    if (streak >= 30) badges.add('streak_30');
    if (streak >= 100) badges.add('streak_100');
    return badges;
  }

  // ─── Semana ──────────────────────────────────────────────────────

  /// Retorna a chave da semana atual no formato "YYYY-Www".
  static String currentWeekKey([DateTime? date]) {
    final now = date ?? DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final weekNum = ((dayOfYear - now.weekday + 10) / 7).floor();
    return '${now.year}-W${weekNum.toString().padLeft(2, '0')}';
  }
}
