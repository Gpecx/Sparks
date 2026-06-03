import 'dart:math' show sqrt2;
import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/directional_67.dart';
import 'package:spark_app/utils/idmt_curves.dart';

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

  group('evaluate67 — Definite Time', () {
    test('forward + acima do pickup → opera com tempo fixo', () {
      final r = evaluate67(
        characteristic: CharacteristicType.definiteTime,
        definiteTimeMs: 250.0,
        direction: DirectionMode.forward,
        mta: 45,
        pickup: 1,
        iOpMag: 5,
        iOpAng: 45,
        polMag: 100,
        polAng: 0,
      );
      expect(r.operates, isTrue);
      expect(r.operatingTimeMs, equals(250.0));
      expect(r.inForwardSector, isTrue);
      expect(r.inSelectedSector, isTrue);
    });

    test('reverse: corrente em 180° do MTA → opera (ajuste = reverse)', () {
      // pol=0°, mta=45°, iOp=225° → θ=−135 ; θ−(MTA+180)=−135−225 norm=0
      final r = evaluate67(
        characteristic: CharacteristicType.definiteTime,
        definiteTimeMs: 100.0,
        direction: DirectionMode.reverse,
        mta: 45,
        pickup: 1,
        iOpMag: 5,
        iOpAng: 225,
        polMag: 100,
        polAng: 0,
      );
      expect(r.operates, isTrue);
      expect(r.inForwardSector, isFalse);
      expect(r.inSelectedSector, isTrue); // dentro do setor reverso
      expect(r.operatingTimeMs, equals(100.0));
    });

    test('abertura de 90° (mais restritiva) → bloqueia em ±60°', () {
      // mta=45, sectorOpening=90 → half=45 → |θ−MTA| deve ser <= 45
      // pol=0°, iOp em 105° → θ=105, θ−MTA=60 > 45 → fora do setor
      final r = evaluate67(
        characteristic: CharacteristicType.definiteTime,
        definiteTimeMs: 100.0,
        direction: DirectionMode.forward,
        mta: 45,
        sectorOpening: 90,
        pickup: 1,
        iOpMag: 5,
        iOpAng: 105,
        polMag: 100,
        polAng: 0,
      );
      expect(r.operates, isFalse);
      expect(r.inForwardSector, isFalse);
    });

    test('não direcional → opera por pickup independentemente do ângulo', () {
      // mta=45, iOp em 225° (reversa pura) → operaria se não direcional
      final r = evaluate67(
        characteristic: CharacteristicType.definiteTime,
        definiteTimeMs: 80.0,
        direction: DirectionMode.nonDirectional,
        mta: 45,
        pickup: 1,
        iOpMag: 5,
        iOpAng: 225,
        polMag: 100,
        polAng: 0,
      );
      expect(r.operates, isTrue);
      expect(r.inSelectedSector, isTrue);
    });

    test('forward mas abaixo do pickup → não opera, sem tempo', () {
      final r = evaluate67(
        characteristic: CharacteristicType.definiteTime,
        definiteTimeMs: 100.0,
        direction: DirectionMode.forward,
        mta: 45,
        pickup: 1,
        iOpMag: 0.5,
        iOpAng: 45,
        polMag: 100,
        polAng: 0,
      );
      expect(r.abovePickup, isFalse);
      expect(r.operates, isFalse);
      expect(r.operatingTimeMs, isNull);
    });
  });

  group('evaluate67 — IDMT (Definite Time vs Curva inversa)', () {
    test('IDMT IEC NI em M=2 com Td=0.1 → tempo finito > 0', () {
      // IEC NI: t = 0.14·Td / (M^0.02 − 1) ; M=2, Td=0.1 → t = 0.014/(1.0139-1) ≈ 1.007 s
      final iecNi = idmtCurves.firstWhere((c) => c.id == 'iec_inversa');
      final r = evaluate67(
        characteristic: CharacteristicType.idmt,
        idmtCurve: iecNi,
        td: 0.1,
        direction: DirectionMode.forward,
        mta: 45,
        pickup: 1, // I=2 → M=2
        iOpMag: 2,
        iOpAng: 45,
        polMag: 100,
        polAng: 0,
      );
      expect(r.operates, isTrue);
      expect(r.operatingTimeMs, isNotNull);
      // ~1007 ms (faixa ampla devido ao expoente sensível em P=0.02)
      expect(r.operatingTimeMs!, greaterThan(800));
      expect(r.operatingTimeMs!, lessThan(1200));
    });

    test('IDMT com M ≤ 1 (I=pickup) → sem trip (tempo nulo)', () {
      final iecVi = idmtCurves.firstWhere((c) => c.id == 'iec_muito_inversa');
      final r = evaluate67(
        characteristic: CharacteristicType.idmt,
        idmtCurve: iecVi,
        td: 0.1,
        direction: DirectionMode.forward,
        mta: 45,
        pickup: 5,
        iOpMag: 5, // M = 1 → tempo infinito
        iOpAng: 45,
        polMag: 100,
        polAng: 0,
      );
      // Mesmo "operates" sendo true (pickup limite é 5 e iOp=5 não passa pelo >),
      // espera-se que o tempo IDMT não seja computado pois M = 1.
      expect(r.abovePickup, isFalse);
      expect(r.operates, isFalse);
      expect(r.operatingTimeMs, isNull);
    });

    test('IDMT corrente alta (M=10) → tempo bem menor que M=2', () {
      final iecVi = idmtCurves.firstWhere((c) => c.id == 'iec_muito_inversa');
      final r2 = evaluate67(
        characteristic: CharacteristicType.idmt,
        idmtCurve: iecVi,
        td: 0.1,
        direction: DirectionMode.forward,
        mta: 45,
        pickup: 1,
        iOpMag: 2,
        iOpAng: 45,
        polMag: 100,
        polAng: 0,
      );
      final r10 = evaluate67(
        characteristic: CharacteristicType.idmt,
        idmtCurve: iecVi,
        td: 0.1,
        direction: DirectionMode.forward,
        mta: 45,
        pickup: 1,
        iOpMag: 10,
        iOpAng: 45,
        polMag: 100,
        polAng: 0,
      );
      expect(r10.operatingTimeMs!, lessThan(r2.operatingTimeMs!));
    });
  });

  group('quadraturePolarization', () {
    test('sistema balanceado ABC: V_PA fica 90° atrás de V_A com módulo √3·V', () {
      // VA=100∠0, VB=100∠-120, VC=100∠120
      // V_PA = V_B − V_C → módulo 100√3 ≈ 173.205, ângulo −90°
      final r = quadraturePolarization(
        phase: ProtectedPhase.a,
        va: 100, angVa: 0,
        vb: 100, angVb: -120,
        vc: 100, angVc: 120,
      );
      expect(r.mag, closeTo(173.205, 1e-2));
      expect(r.ang, closeTo(-90.0, 1e-2));
    });

    test('balanceado: V_PB fica 90° atrás de V_B (ângulo +150° absoluto)', () {
      // V_B em −120 ; quadratura 90° atrás → −210° ≡ +150°
      final r = quadraturePolarization(
        phase: ProtectedPhase.b,
        va: 100, angVa: 0,
        vb: 100, angVb: -120,
        vc: 100, angVc: 120,
      );
      expect(r.mag, closeTo(173.205, 1e-2));
      expect(r.ang, closeTo(150.0, 1e-2));
    });

    test('balanceado: V_PC fica 90° atrás de V_C (ângulo +30°)', () {
      // V_C em +120 ; quadratura 90° atrás → +30°
      final r = quadraturePolarization(
        phase: ProtectedPhase.c,
        va: 100, angVa: 0,
        vb: 100, angVb: -120,
        vc: 100, angVc: 120,
      );
      expect(r.mag, closeTo(173.205, 1e-2));
      expect(r.ang, closeTo(30.0, 1e-2));
    });

    test('falta fase A (V_A colapsa para 0): polarização V_PA permanece estável', () {
      // V_A=0 (curto franco A-N), V_B e V_C inalterados → V_PA = V_B − V_C continua 173∠−90
      final r = quadraturePolarization(
        phase: ProtectedPhase.a,
        va: 0, angVa: 0,
        vb: 100, angVb: -120,
        vc: 100, angVc: 120,
      );
      expect(r.mag, closeTo(173.205, 1e-2));
      expect(r.ang, closeTo(-90.0, 1e-2));
    });
  });

  group('recommendedMta', () {
    test('67 fase, falta F-F → +60°', () {
      expect(
        recommendedMta(faultType: FaultType.phaseToPhase, isNeutral: false),
        equals(60.0),
      );
    });

    test('67 fase, falta F-N → +30°', () {
      expect(
        recommendedMta(faultType: FaultType.phaseToNeutral, isNeutral: false),
        equals(30.0),
      );
    });

    test('67N (neutro), falta F-N → −45°', () {
      expect(
        recommendedMta(faultType: FaultType.phaseToNeutral, isNeutral: true),
        equals(-45.0),
      );
    });

    test('67N (neutro), falta F-F (com componente residual) → −60°', () {
      expect(
        recommendedMta(faultType: FaultType.phaseToPhase, isNeutral: true),
        equals(-60.0),
      );
    });
  });
}
