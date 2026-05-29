import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/ct_saturation.dart';

void main() {
  group('Saturação de TC', () {
    test('TC 600/5, ALF=20, Sn=15VA, Rct=0,5Ω, Zb=2Ω, Ifalta=6000A → satura', () {
      final r = ctSaturation(
        ctPrimary: 600,
        ctSecondary: 5,
        rctOhm: 0.5,
        ratedBurdenVa: 15,
        alf: 20,
        connectedBurdenOhm: 2,
        faultPrimaryCurrent: 6000,
      );
      expect(r.rtc, closeTo(120, 1e-9));
      expect(r.ratedBurdenOhm, closeTo(0.6, 1e-9)); // 15/25
      expect(r.kneeVoltage, closeTo(110, 0.01)); // 20·5·1,1
      expect(r.secondaryFaultCurrent, closeTo(50, 1e-9)); // 6000/120
      expect(r.requiredVoltage, closeTo(125, 0.01)); // 50·2,5
      expect(r.effectiveAlf, closeTo(8.8, 0.01)); // 20·1,1/2,5
      expect(r.faultMultiple, closeTo(10, 1e-9));
      expect(r.saturates, isTrue);
    });

    test('carga leve não satura', () {
      final r = ctSaturation(
        ctPrimary: 600,
        ctSecondary: 5,
        rctOhm: 0.5,
        ratedBurdenVa: 15,
        alf: 20,
        connectedBurdenOhm: 0.3,
        faultPrimaryCurrent: 6000,
      );
      expect(r.saturates, isFalse);
      expect(r.margin, greaterThanOrEqualTo(1.0));
    });
  });
}
