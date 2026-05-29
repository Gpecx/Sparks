import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/power_factor.dart';

void main() {
  group('Correção de fator de potência', () {
    test('P=100kW, 0,8 → 0,95 ⇒ ~42,13 kvar', () {
      final r = powerFactorCorrection(
        activePowerKw: 100,
        pfCurrent: 0.8,
        pfTarget: 0.95,
      );
      expect(r.capacitorKvar, closeTo(42.13, 0.05));
    });

    test('potências aparentes coerentes', () {
      final r = powerFactorCorrection(
        activePowerKw: 100,
        pfCurrent: 0.8,
        pfTarget: 0.95,
      );
      expect(r.apparentBefore, closeTo(125.0, 0.01)); // 100/0,8
      expect(r.apparentAfter, closeTo(105.26, 0.05)); // 100/0,95
    });

    test('FP já no alvo ⇒ banco ~0', () {
      final r = powerFactorCorrection(
        activePowerKw: 100,
        pfCurrent: 0.92,
        pfTarget: 0.92,
      );
      expect(r.capacitorKvar, closeTo(0, 1e-6));
    });
  });
}
