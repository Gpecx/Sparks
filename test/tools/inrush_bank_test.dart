import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/inrush_bank.dart';

void main() {
  group('Inrush de banco de transformadores', () {
    test('In e pico de um trafo isolado', () {
      const t = TransformerInrush(ratedKva: 1000, voltageKv: 13.8, inrushFactor: 10);
      // In = 1000 / (√3·13,8) = 41,84 A
      expect(t.ratedCurrent, closeTo(41.84, 0.05));
      expect(t.inrushPeak, closeTo(418.4, 0.5));
    });

    test('picos somam no pior caso (coincidência = 1)', () {
      final r = bankInrush(
        transformers: const [
          TransformerInrush(ratedKva: 1000, voltageKv: 13.8, inrushFactor: 10),
          TransformerInrush(ratedKva: 500, voltageKv: 13.8, inrushFactor: 12),
        ],
        coincidenceFactor: 1.0,
      );
      // pico1 = 418,4 ; pico2 = 0,5·418,4... recalcula: In2=20,92, pico2=251,0
      expect(r.sumOfPeaks, closeTo(418.4 + 251.0, 1.0));
      expect(r.coincidentInrush, closeTo(r.sumOfPeaks, 1e-6));
    });

    test('fator de coincidência reduz o inrush total', () {
      final full = bankInrush(
        transformers: const [
          TransformerInrush(ratedKva: 1000, voltageKv: 13.8, inrushFactor: 10),
          TransformerInrush(ratedKva: 1000, voltageKv: 13.8, inrushFactor: 10),
        ],
        coincidenceFactor: 1.0,
      );
      final partial = bankInrush(
        transformers: const [
          TransformerInrush(ratedKva: 1000, voltageKv: 13.8, inrushFactor: 10),
          TransformerInrush(ratedKva: 1000, voltageKv: 13.8, inrushFactor: 10),
        ],
        coincidenceFactor: 0.7,
      );
      expect(partial.coincidentInrush, closeTo(full.coincidentInrush * 0.7, 0.01));
    });

    test('detecta quando o inrush ultrapassa o ajuste 50', () {
      final r = bankInrush(
        transformers: const [
          TransformerInrush(ratedKva: 2000, voltageKv: 13.8, inrushFactor: 12),
          TransformerInrush(ratedKva: 2000, voltageKv: 13.8, inrushFactor: 12),
        ],
        coincidenceFactor: 1.0,
        instantaneousPickupA: 1500,
      );
      // In = 83,67 ; pico = 1004 cada ; soma = 2008 A > 1500
      expect(r.coincidentInrush, greaterThan(1500));
      expect(r.exceedsPickup, isTrue);
      expect(r.marginPercent, lessThan(0));
    });

    test('margem positiva quando inrush abaixo do ajuste', () {
      final r = bankInrush(
        transformers: const [
          TransformerInrush(ratedKva: 500, voltageKv: 13.8, inrushFactor: 8),
        ],
        coincidenceFactor: 1.0,
        instantaneousPickupA: 1000,
      );
      expect(r.exceedsPickup, isFalse);
      expect(r.marginPercent, greaterThan(0));
    });

    test('fator de coincidência é limitado a [0,1]', () {
      final r = bankInrush(
        transformers: const [
          TransformerInrush(ratedKva: 500, voltageKv: 13.8, inrushFactor: 8),
        ],
        coincidenceFactor: 1.5,
      );
      expect(r.coincidenceFactor, 1.0);
    });
  });
}
