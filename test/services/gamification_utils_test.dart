import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/core/utils/gamification_utils.dart';

// ─────────────────────────────────────────────────────────────────
//  TESTES: GamificationUtils
//
//  Valida toda a lógica matemática de gamificação sem dependência
//  de Firebase ou Flutter — 100% puro e determinístico.
// ─────────────────────────────────────────────────────────────────

void main() {
  group('GamificationUtils.calcLevel', () {
    test('XP 0 → nível 1', () {
      expect(GamificationUtils.calcLevel(0), equals(1));
    });

    test('XP 499 → nível 1', () {
      expect(GamificationUtils.calcLevel(499), equals(1));
    });

    test('XP 500 → nível 2', () {
      expect(GamificationUtils.calcLevel(500), equals(2));
    });

    test('XP 999 → nível 2', () {
      expect(GamificationUtils.calcLevel(999), equals(2));
    });

    test('XP 1000 → nível 3', () {
      expect(GamificationUtils.calcLevel(1000), equals(3));
    });

    test('XP 5000 → nível 11', () {
      expect(GamificationUtils.calcLevel(5000), equals(11));
    });

    test('XP 10000 → nível 21', () {
      expect(GamificationUtils.calcLevel(10000), equals(21));
    });
  });

  group('GamificationUtils.calcTension', () {
    test('XP 0 → BT', () {
      expect(GamificationUtils.calcTension(0), equals('BT'));
    });

    test('XP 4999 → BT', () {
      expect(GamificationUtils.calcTension(4999), equals('BT'));
    });

    test('XP 5000 → MT', () {
      expect(GamificationUtils.calcTension(5000), equals('MT'));
    });

    test('XP 14999 → MT', () {
      expect(GamificationUtils.calcTension(14999), equals('MT'));
    });

    test('XP 15000 → AT', () {
      expect(GamificationUtils.calcTension(15000), equals('AT'));
    });

    test('XP 29999 → AT', () {
      expect(GamificationUtils.calcTension(29999), equals('AT'));
    });

    test('XP 30000 → EAT', () {
      expect(GamificationUtils.calcTension(30000), equals('EAT'));
    });

    test('XP 100000 → EAT', () {
      expect(GamificationUtils.calcTension(100000), equals('EAT'));
    });
  });

  group('GamificationUtils.xpMultiplier', () {
    test('streak 0 → 1.0x', () {
      expect(GamificationUtils.xpMultiplier(0), equals(1.0));
    });

    test('streak 2 → 1.0x', () {
      expect(GamificationUtils.xpMultiplier(2), equals(1.0));
    });

    test('streak 3 → 1.2x', () {
      expect(GamificationUtils.xpMultiplier(3), equals(1.2));
    });

    test('streak 6 → 1.2x', () {
      expect(GamificationUtils.xpMultiplier(6), equals(1.2));
    });

    test('streak 7 → 1.5x', () {
      expect(GamificationUtils.xpMultiplier(7), equals(1.5));
    });

    test('streak 29 → 1.5x', () {
      expect(GamificationUtils.xpMultiplier(29), equals(1.5));
    });

    test('streak 30 → 2.0x', () {
      expect(GamificationUtils.xpMultiplier(30), equals(2.0));
    });

    test('streak 100 → 2.0x', () {
      expect(GamificationUtils.xpMultiplier(100), equals(2.0));
    });
  });

  group('GamificationUtils.xpMultiplierLabel', () {
    test('streak 0 → "x1.0"', () {
      expect(GamificationUtils.xpMultiplierLabel(0), equals('x1.0'));
    });

    test('streak 7 → "x1.5"', () {
      expect(GamificationUtils.xpMultiplierLabel(7), equals('x1.5'));
    });

    test('streak 30 → "x2.0"', () {
      expect(GamificationUtils.xpMultiplierLabel(30), equals('x2.0'));
    });
  });

  group('GamificationUtils.streakResurrectCost', () {
    test('streak 1 → 50 SP', () {
      expect(GamificationUtils.streakResurrectCost(1), equals(50));
    });

    test('streak 6 → 50 SP', () {
      expect(GamificationUtils.streakResurrectCost(6), equals(50));
    });

    test('streak 7 → 100 SP', () {
      expect(GamificationUtils.streakResurrectCost(7), equals(100));
    });

    test('streak 29 → 100 SP', () {
      expect(GamificationUtils.streakResurrectCost(29), equals(100));
    });

    test('streak 30 → 200 SP', () {
      expect(GamificationUtils.streakResurrectCost(30), equals(200));
    });

    test('streak 100 → 200 SP', () {
      expect(GamificationUtils.streakResurrectCost(100), equals(200));
    });
  });

  group('GamificationUtils.xpBadgesEarned', () {
    test('XP 0 → sem badges', () {
      expect(GamificationUtils.xpBadgesEarned(0), isEmpty);
    });

    test('XP 999 → sem badges', () {
      expect(GamificationUtils.xpBadgesEarned(999), isEmpty);
    });

    test('XP 1000 → [xp_1000]', () {
      expect(GamificationUtils.xpBadgesEarned(1000), equals(['xp_1000']));
    });

    test('XP 5000 → [xp_1000, xp_5000]', () {
      expect(
        GamificationUtils.xpBadgesEarned(5000),
        containsAll(['xp_1000', 'xp_5000']),
      );
    });

    test('XP 10000 → todas as 3 badges de XP', () {
      final badges = GamificationUtils.xpBadgesEarned(10000);
      expect(badges, containsAll(['xp_1000', 'xp_5000', 'xp_10000']));
      expect(badges.length, equals(3));
    });
  });

  group('GamificationUtils.streakBadgesEarned', () {
    test('streak 0 → sem badges', () {
      expect(GamificationUtils.streakBadgesEarned(0), isEmpty);
    });

    test('streak 6 → sem badges', () {
      expect(GamificationUtils.streakBadgesEarned(6), isEmpty);
    });

    test('streak 7 → [streak_7]', () {
      expect(GamificationUtils.streakBadgesEarned(7), equals(['streak_7']));
    });

    test('streak 30 → [streak_7, streak_30]', () {
      expect(
        GamificationUtils.streakBadgesEarned(30),
        containsAll(['streak_7', 'streak_30']),
      );
    });

    test('streak 100 → todas as 3 badges de streak', () {
      final badges = GamificationUtils.streakBadgesEarned(100);
      expect(
        badges,
        containsAll(['streak_7', 'streak_30', 'streak_100']),
      );
      expect(badges.length, equals(3));
    });
  });

  group('GamificationUtils.currentWeekKey', () {
    test('retorna formato YYYY-Www', () {
      final key = GamificationUtils.currentWeekKey();
      // Valida o padrão YYYY-Www (ex: "2026-W21")
      expect(key, matches(RegExp(r'^\d{4}-W\d{2}$')));
    });

    test('data específica → semana correta', () {
      // 5 de janeiro de 2026 (segunda-feira) é a semana 2
      final key = GamificationUtils.currentWeekKey(DateTime(2026, 1, 5));
      expect(key, equals('2026-W02'));
    });
  });
}
