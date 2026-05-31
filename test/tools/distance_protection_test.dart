import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/distance_protection.dart';

void main() {
  group('Proteção de distância (21)', () {
    test('Z_linha=10Ω, Z_adj=8Ω, padrões 85% / 0,5 / 1,0', () {
      final z = distanceZones(lineImpedance: 10, adjacentImpedance: 8);
      expect(z.z1, closeTo(8.5, 1e-9)); // 0,85·10
      expect(z.z2, closeTo(14, 1e-9)); // 10 + 0,5·8
      expect(z.z3, closeTo(18, 1e-9)); // 10 + 1,0·8
      expect(z.z1Secondary, isNull);
    });

    test('conversão para secundário com RTC/RTP', () {
      final z = distanceZones(
        lineImpedance: 10,
        adjacentImpedance: 8,
        rtc: 240,
        rtp: 120,
      );
      // ratio = 240/120 = 2 → Z_sec = 2·Z_prim
      expect(z.z1Secondary, closeTo(17, 1e-9));
      expect(z.z2Secondary, closeTo(28, 1e-9));
      expect(z.z3Secondary, closeTo(36, 1e-9));
    });
  });

  group('21 — característica R-X / mho', () {
    test('faultImpedance converte módulo/ângulo em R e X', () {
      final z = faultImpedance(magnitude: 10, angleDeg: 60);
      expect(z.r, closeTo(5.0, 1e-3)); // 10·cos60
      expect(z.x, closeTo(8.6603, 1e-3)); // 10·sen60
      expect(z.magnitude, closeTo(10.0, 1e-3));
      expect(z.angleDeg, closeTo(60.0, 1e-2));
    });

    test('falta sobre a linha dentro do alcance → dentro do mho', () {
      final f = faultImpedance(magnitude: 5, angleDeg: 70);
      expect(insideMho(fault: f, reach: 8.5, lineAngleDeg: 70), isTrue);
    });

    test('falta além do alcance da zona → fora do mho', () {
      final f = faultImpedance(magnitude: 9, angleDeg: 70);
      expect(insideMho(fault: f, reach: 8.5, lineAngleDeg: 70), isFalse);
    });

    test('falta reversa (atrás do relé) → fora do mho', () {
      final f = faultImpedance(magnitude: 5, angleDeg: 250); // 70+180
      expect(insideMho(fault: f, reach: 8.5, lineAngleDeg: 70), isFalse);
    });

    test('zona mais rápida que enxerga a falta', () {
      final dentroZ1 = faultImpedance(magnitude: 5, angleDeg: 70);
      expect(
          fastestZoneSeeing(
              fault: dentroZ1, z1: 8.5, z2: 14, z3: 18, lineAngleDeg: 70),
          1);

      final soZ2 = faultImpedance(magnitude: 12, angleDeg: 70);
      expect(
          fastestZoneSeeing(
              fault: soZ2, z1: 8.5, z2: 14, z3: 18, lineAngleDeg: 70),
          2);

      final soZ3 = faultImpedance(magnitude: 16, angleDeg: 70);
      expect(
          fastestZoneSeeing(
              fault: soZ3, z1: 8.5, z2: 14, z3: 18, lineAngleDeg: 70),
          3);

      final foraDeTudo = faultImpedance(magnitude: 25, angleDeg: 70);
      expect(
          fastestZoneSeeing(
              fault: foraDeTudo, z1: 8.5, z2: 14, z3: 18, lineAngleDeg: 70),
          0);
    });
  });
}
