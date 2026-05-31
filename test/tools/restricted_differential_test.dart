import 'dart:math' show sqrt2;
import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/restricted_differential.dart';

void main() {
  group('87 — corrente diferencial (soma fasorial)', () {
    test('falta passante ideal: I1 e I2 opostos → Idiff ≈ 0', () {
      // entra +1∠0 num lado, sai 1∠180 no outro (convenção de entrada)
      final id = diffCurrent(i1: 1.0, ang1: 0, i2: 1.0, ang2: 180);
      expect(id, closeTo(0, 1e-9));
    });

    test('falta interna: ambos no mesmo sentido → Idiff = soma', () {
      final id = diffCurrent(i1: 1.0, ang1: 0, i2: 1.0, ang2: 0);
      expect(id, closeTo(2.0, 1e-9));
    });

    test('defasagem de 90° → módulo √2', () {
      final id = diffCurrent(i1: 1.0, ang1: 0, i2: 1.0, ang2: 90);
      expect(id, closeTo(sqrt2, 1e-9));
    });
  });

  group('87 — corrente de restrição por convenção', () {
    test('média, máximo e soma', () {
      expect(
          restraintCurrent(i1: 2, i2: 4, convention: RestraintConvention.average),
          closeTo(3.0, 1e-9));
      expect(
          restraintCurrent(i1: 2, i2: 4, convention: RestraintConvention.maximum),
          closeTo(4.0, 1e-9));
      expect(
          restraintCurrent(i1: 2, i2: 4, convention: RestraintConvention.sum),
          closeTo(6.0, 1e-9));
    });
  });

  group('87 — limiar de dupla inclinação', () {
    const pickup = 0.3, s1 = 0.25, s2 = 0.6, k1 = 2.0, k2 = 6.0;

    test('abaixo do joelho 1 → limiar = pickup', () {
      expect(
          dualSlopeThreshold(
              irest: 1.0, pickup: pickup, slope1: s1, slope2: s2, knee1: k1, knee2: k2),
          closeTo(0.3, 1e-9));
    });

    test('na região do slope 1', () {
      // irest=4 → 0,3 + 0,25·(4−2) = 0,8
      expect(
          dualSlopeThreshold(
              irest: 4.0, pickup: pickup, slope1: s1, slope2: s2, knee1: k1, knee2: k2),
          closeTo(0.8, 1e-9));
    });

    test('na região do slope 2', () {
      // irest=8 → 0,3 + 0,25·(6−2) + 0,6·(8−6) = 0,3 + 1,0 + 1,2 = 2,5
      expect(
          dualSlopeThreshold(
              irest: 8.0, pickup: pickup, slope1: s1, slope2: s2, knee1: k1, knee2: k2),
          closeTo(2.5, 1e-9));
    });

    test('limiar é contínuo e monotônico crescente', () {
      double th(double ir) => dualSlopeThreshold(
          irest: ir, pickup: pickup, slope1: s1, slope2: s2, knee1: k1, knee2: k2);
      expect(th(2.0), closeTo(0.3, 1e-9)); // joelho1 = pickup
      expect(th(6.0), greaterThan(th(2.0)));
      expect(th(10.0), greaterThan(th(6.0)));
    });
  });

  group('87 — avaliação do ponto de operação', () {
    const args = (
      pickup: 0.3,
      slope1: 0.25,
      slope2: 0.6,
      knee1: 2.0,
      knee2: 6.0,
    );

    test('falta passante de alta corrente → RESTRINGE (não opera)', () {
      // passante: I1=+5∠0, I2=5∠180 → Idiff~0, Irest alto
      final p = evaluateDifferential(
        i1: 5, ang1: 0, i2: 5, ang2: 180,
        convention: RestraintConvention.average,
        pickup: args.pickup, slope1: args.slope1, slope2: args.slope2,
        knee1: args.knee1, knee2: args.knee2,
      );
      expect(p.idiff, closeTo(0, 1e-9));
      expect(p.operates, isFalse);
      expect(p.margin, lessThan(0));
    });

    test('falta interna → OPERA', () {
      // interna: I1=+3∠0, I2=+3∠0 → Idiff=6, Irest=3
      final p = evaluateDifferential(
        i1: 3, ang1: 0, i2: 3, ang2: 0,
        convention: RestraintConvention.average,
        pickup: args.pickup, slope1: args.slope1, slope2: args.slope2,
        knee1: args.knee1, knee2: args.knee2,
      );
      // Irest=3 → limiar 0,3+0,25·1 = 0,55 ; Idiff=6 >> limiar
      expect(p.idiff, closeTo(6.0, 1e-9));
      expect(p.threshold, closeTo(0.55, 1e-9));
      expect(p.operates, isTrue);
      expect(p.margin, greaterThan(0));
    });
  });
}
