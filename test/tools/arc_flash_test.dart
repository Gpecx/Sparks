import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/arc_flash.dart';

void main() {
  group('Arc Flash — categoria de EPI', () {
    test('limiares de categoria conforme cal/cm²', () {
      expect(ppeCategory(0.8), 0);
      expect(ppeCategory(1.2), 0); // exatamente no limiar
      expect(ppeCategory(2.0), 1);
      expect(ppeCategory(6.0), 2);
      expect(ppeCategory(12.0), 3);
      expect(ppeCategory(30.0), 4);
      expect(ppeCategory(50.0), -1); // perigo extremo
    });
  });

  group('Arc Flash — modelo de Lee', () {
    test('energia escala com 1/D²', () {
      final e1 = arcFlashLee(
          iBfKa: 20, voltageKv: 13.8, clearingTimeS: 0.2, workingDistanceMm: 455);
      final e2 = arcFlashLee(
          iBfKa: 20, voltageKv: 13.8, clearingTimeS: 0.2, workingDistanceMm: 910);
      // dobrar a distância → 1/4 da energia
      expect(e2, closeTo(e1 / 4, e1 * 0.001));
    });

    test('energia escala linearmente com o tempo', () {
      final e1 = arcFlashLee(
          iBfKa: 20, voltageKv: 13.8, clearingTimeS: 0.1, workingDistanceMm: 455);
      final e2 = arcFlashLee(
          iBfKa: 20, voltageKv: 13.8, clearingTimeS: 0.2, workingDistanceMm: 455);
      expect(e2, closeTo(e1 * 2, e1 * 0.001));
    });
  });

  group('Arc Flash — IEEE 1584-2002', () {
    test('caso BT típico em painel produz energia plausível', () {
      // 480 V, 25 kA, 0,1 s, 455 mm de distância de trabalho
      final r = arcFlashIeee1584(
        iBfKa: 25,
        voltageKv: 0.48,
        clearingTimeS: 0.1,
        workingDistanceMm: 455,
        gapMm: 25,
        distanceExponent: 1.641,
        enclosure: ArcEnclosure.box,
      );
      expect(r.model, 'IEEE 1584-2002');
      expect(r.outOfRange, isFalse);
      expect(r.incidentEnergy, greaterThan(0));
      expect(r.incidentEnergy, lessThan(100)); // sanidade
      expect(r.arcingCurrentKa, greaterThan(0));
      expect(r.arcingCurrentKa, lessThan(25)); // Ia < Ibf em BT
    });

    test('fora da faixa de validade cai no modelo Lee', () {
      // 34,5 kV está acima de 15 kV → fora do 1584 → Lee
      final r = arcFlashIeee1584(
        iBfKa: 20,
        voltageKv: 34.5,
        clearingTimeS: 0.2,
        workingDistanceMm: 910,
        gapMm: 152,
        distanceExponent: 0.973,
        enclosure: ArcEnclosure.box,
      );
      expect(r.outOfRange, isTrue);
      expect(r.model, contains('Lee'));
      expect(r.arcingCurrentKa.isNaN, isTrue);
      expect(r.incidentEnergy, greaterThan(0));
    });

    test('mais tempo de eliminação → mais energia e categoria maior ou igual',
        () {
      ArcFlashResult run(double t) => arcFlashIeee1584(
            iBfKa: 25,
            voltageKv: 0.48,
            clearingTimeS: t,
            workingDistanceMm: 455,
            gapMm: 25,
            distanceExponent: 1.641,
            enclosure: ArcEnclosure.box,
          );
      final fast = run(0.05);
      final slow = run(0.5);
      expect(slow.incidentEnergy, greaterThan(fast.incidentEnergy));
      expect(slow.ppeCategory >= fast.ppeCategory, isTrue);
    });
  });

  group('Arc Flash — distância segura', () {
    test('distância para 1,2 cal/cm² é positiva e consistente', () {
      final d = safeApproachDistanceMm(
          iBfKa: 20, voltageKv: 13.8, clearingTimeS: 0.2);
      expect(d, greaterThan(0));
      // a essa distância a energia Lee deve ser ≈ 1,2
      final e = arcFlashLee(
          iBfKa: 20, voltageKv: 13.8, clearingTimeS: 0.2, workingDistanceMm: d);
      expect(e, closeTo(1.2, 0.01));
    });
  });
}
