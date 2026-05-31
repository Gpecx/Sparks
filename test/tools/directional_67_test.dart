import 'dart:math' show sqrt2;
import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/directional_67.dart';

void main() {
  group('normalizeDeg', () {
    test('mantém faixa (−180, 180]', () {
      expect(normalizeDeg(0), closeTo(0, 1e-9));
      expect(normalizeDeg(180), closeTo(180, 1e-9));
      expect(normalizeDeg(-180), closeTo(180, 1e-9)); // −180 → 180
      expect(normalizeDeg(270), closeTo(-90, 1e-9));
      expect(normalizeDeg(-270), closeTo(90, 1e-9));
      expect(normalizeDeg(360), closeTo(0, 1e-9));
    });
  });

  group('67 — elemento direcional', () {
    test('corrente alinhada ao MTA → opera (forward), torque máximo', () {
      // pol em 0°, MTA +45°, I_op em 45° → θ−MTA = 0 → cos=1
      final r = evaluateDirectional(
        iOpMag: 5, iOpAng: 45, polMag: 100, polAng: 0, mta: 45, pickup: 1,
      );
      expect(r.forward, isTrue);
      expect(r.operates, isTrue);
      expect(r.torqueAngle, closeTo(0, 1e-9));
      expect(r.angularMargin, closeTo(90, 1e-9));
    });

    test('falta reversa (180° do MTA) → bloqueia', () {
      final r = evaluateDirectional(
        iOpMag: 5, iOpAng: 225, polMag: 100, polAng: 0, mta: 45, pickup: 1,
      );
      // θ = 225 → −135 ; θ−MTA = −180 → cos = −1
      expect(r.forward, isFalse);
      expect(r.operates, isFalse);
      expect(r.angularMargin, lessThan(0));
    });

    test('exatamente no limite (±90° do MTA) → fronteira não opera', () {
      // θ−MTA = 90 → cos = 0 → forward (cos>0) é falso
      final r = evaluateDirectional(
        iOpMag: 5, iOpAng: 135, polMag: 100, polAng: 0, mta: 45, pickup: 1,
      );
      expect(r.torqueAngle, closeTo(90, 1e-9));
      expect(r.forward, isFalse);
      expect(r.angularMargin, closeTo(0, 1e-9));
    });

    test('forward mas abaixo do pickup → não opera', () {
      final r = evaluateDirectional(
        iOpMag: 0.5, iOpAng: 45, polMag: 100, polAng: 0, mta: 45, pickup: 1,
      );
      expect(r.forward, isTrue);
      expect(r.abovePickup, isFalse);
      expect(r.operates, isFalse);
    });
  });

  group('67N — corrente residual 3I0', () {
    test('sistema equilibrado → 3I0 ≈ 0', () {
      final r = residualCurrent3I0(
        ia: 100, angIa: 0, ib: 100, angIb: -120, ic: 100, angIc: 120,
      );
      expect(r.mag, closeTo(0, 1e-6));
    });

    test('falta monofásica (só fase A) → 3I0 = Ia, mesmo ângulo', () {
      final r = residualCurrent3I0(
        ia: 100, angIa: 0, ib: 0, angIb: 0, ic: 0, angIc: 0,
      );
      expect(r.mag, closeTo(100, 1e-6));
      expect(r.ang, closeTo(0, 1e-6));
    });

    test('duas correntes em quadratura → módulo √2', () {
      final r = residualCurrent3I0(
        ia: 1, angIa: 0, ib: 1, angIb: 90, ic: 0, angIc: 0,
      );
      expect(r.mag, closeTo(sqrt2, 1e-9));
      expect(r.ang, closeTo(45, 1e-6));
    });
  });

  group('67N — polarização por 3V0 vs 3I0', () {
    test('67N por 3V0: falta direta com MTA −45°', () {
      // 3V0 em 180° (típico em falta-terra), 3I0 atrasada ~135° → dentro da zona
      final r = evaluateDirectional(
        iOpMag: 3, iOpAng: 135, polMag: 30, polAng: 180, mta: -45, pickup: 0.5,
      );
      // θ = 135−180 = −45 ; θ−MTA = −45−(−45)=0 → cos=1
      expect(r.torqueAngle, closeTo(0, 1e-9));
      expect(r.operates, isTrue);
    });
  });
}
