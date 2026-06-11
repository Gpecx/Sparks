import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/spda_calc.dart';

void main() {
  group('SPDA 5419-3 — níveis', () {
    test('raio da esfera rolante por nível', () {
      expect(spdaLevelByName('I').rollingSphereRadius, 20);
      expect(spdaLevelByName('II').rollingSphereRadius, 30);
      expect(spdaLevelByName('III').rollingSphereRadius, 45);
      expect(spdaLevelByName('IV').rollingSphereRadius, 60);
    });

    test('corrente de impulso por nível', () {
      expect(spdaLevelByName('I').impulseCurrentKa, 200);
      expect(spdaLevelByName('II').impulseCurrentKa, 150);
      expect(spdaLevelByName('III').impulseCurrentKa, 100);
      expect(spdaLevelByName('IV').impulseCurrentKa, 100);
    });
  });

  group('SPDA 5419-3 — número de descidas', () {
    test('perímetro / espaçamento, mínimo 2', () {
      // nível I: espaçamento 10 m. perímetro 100 → 10 descidas
      expect(downConductors(perimeter: 100, level: spdaLevelByName('I')), 10);
      // perímetro pequeno → mínimo 2
      expect(downConductors(perimeter: 5, level: spdaLevelByName('I')), 2);
      // nível IV: espaçamento 20 m. perímetro 100 → 5
      expect(downConductors(perimeter: 100, level: spdaLevelByName('IV')), 5);
    });

    test('arredonda para cima', () {
      // 105 / 10 = 10,5 → 11
      expect(downConductors(perimeter: 105, level: spdaLevelByName('I')), 11);
    });
  });

  group('SPDA 5419-3 — distância de segurança s', () {
    test('s = ki·(kc/km)·L', () {
      // nível I (ki=0,08), kc=0,5, km=1 (ar), L=10 → 0,08·0,5·10 = 0,4 m
      final s = safetyDistance(level: 'I', kc: 0.5, km: 1.0, length: 10);
      expect(s, closeTo(0.4, 1e-9));
    });

    test('ki menor para níveis mais baixos', () {
      final s1 = safetyDistance(level: 'I', kc: 1, km: 1, length: 1);
      final s4 = safetyDistance(level: 'IV', kc: 1, km: 1, length: 1);
      expect(s1, greaterThan(s4));
      expect(s1, closeTo(0.08, 1e-9));
      expect(s4, closeTo(0.04, 1e-9));
    });

    test('isolamento sólido (km=0,5) dobra a distância', () {
      final ar = safetyDistance(level: 'II', kc: 1, km: 1, length: 5);
      final solido = safetyDistance(level: 'II', kc: 1, km: 0.5, length: 5);
      expect(solido, closeTo(ar * 2, 1e-9));
    });
  });

  group('SPDA 5419-3 — ângulo de proteção', () {
    test('decresce com a altura', () {
      final baixo = protectionAngleDeg(level: 'I', height: 2);
      final alto = protectionAngleDeg(level: 'I', height: 20);
      expect(baixo, greaterThan(alto));
    });

    test('nunca negativo', () {
      final a = protectionAngleDeg(level: 'I', height: 100);
      expect(a, greaterThanOrEqualTo(0));
    });

    test('raio de proteção = h·tan(α)', () {
      final r = protectionRadiusAtGround(height: 10, angleDeg: 45);
      expect(r, closeTo(10, 1e-6)); // tan45 = 1
    });
  });

  group('SPDA 5419-3 — resultado consolidado', () {
    test('spdaGeneral monta todos os campos', () {
      final r = spdaGeneral(level: 'II', perimeter: 80, height: 12);
      expect(r.rollingSphereRadius, 30);
      expect(r.impulseCurrentKa, 150);
      expect(r.downConductorCount, 8); // 80/10
      expect(r.protectionAngle, greaterThan(0));
      expect(r.protectionRadius, greaterThan(0));
    });
  });
}
