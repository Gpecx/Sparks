import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/inrush_estimate.dart';

void main() {
  group('Inrush real — corrente nominal', () {
    test('In = S/(√3·V)', () {
      final inA = ratedCurrentA(powerKva: 1000, voltageKv: 13.8);
      expect(inA, closeTo(41.84, 0.05));
    });
  });

  group('Inrush real — fator de pico', () {
    test('k cresce quando Z% é menor (trafo mais "duro")', () {
      final kBaixaZ = inrushPeakFactor(zccPercent: 5, residualFlux: 0);
      final kAltaZ = inrushPeakFactor(zccPercent: 10, residualFlux: 0);
      expect(kBaixaZ, greaterThan(kAltaZ));
      // Z=10%, sem fluxo, núcleo 1,0 → kBase = 1/0,1 = 10
      expect(kAltaZ, closeTo(10.0, 1e-9));
    });

    test('fluxo residual aumenta o pico', () {
      final sem = inrushPeakFactor(zccPercent: 10, residualFlux: 0);
      final com = inrushPeakFactor(zccPercent: 10, residualFlux: 0.6);
      expect(com, greaterThan(sem));
      // 10 · (1+0,6) = 16 → limitado a kMax=15
      expect(com, closeTo(15.0, 1e-9));
    });

    test('limita ao kMax físico', () {
      final k = inrushPeakFactor(zccPercent: 4, residualFlux: 0.8);
      expect(k, lessThanOrEqualTo(15.0));
    });

    test('fluxo residual é limitado a 0,8', () {
      final exagerado = inrushPeakFactor(zccPercent: 50, residualFlux: 5);
      final limite = inrushPeakFactor(zccPercent: 50, residualFlux: 0.8);
      expect(exagerado, closeTo(limite, 1e-9));
    });
  });

  group('Inrush real — 2º harmônico e bloqueio', () {
    test('%2H dentro da faixa física 12–35%', () {
      for (final k in [6.0, 10.0, 15.0]) {
        final h = estimatedSecondHarmonic(peakFactor: k);
        expect(h, inInclusiveRange(12.0, 35.0));
      }
    });
  });

  group('Inrush real — estimativa consolidada', () {
    test('trafo 1000 kVA, 13,8 kV, Z=10%, fluxo 0,6', () {
      final r = estimateInrush(
        powerKva: 1000, voltageKv: 13.8, zccPercent: 10, residualFlux: 0.6,
      );
      expect(r.ratedCurrent, closeTo(41.84, 0.05));
      // k limitado a 15 → pico ≈ 627,6 A
      expect(r.peakFactor, closeTo(15.0, 1e-9));
      expect(r.peakCurrent, closeTo(41.84 * 15, 1.0));
      // bloqueio por 2º harmônico deve estar OK (>15%)
      expect(r.harmonicBlockOk, isTrue);
    });

    test('Z inválido → NaN propaga sem crash', () {
      final r = estimateInrush(powerKva: 1000, voltageKv: 13.8, zccPercent: 0);
      expect(r.peakFactor.isNaN, isTrue);
    });
  });
}
