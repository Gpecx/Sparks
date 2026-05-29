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
}
