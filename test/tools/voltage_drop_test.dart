import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/voltage_drop.dart';

void main() {
  group('Queda de tensão', () {
    test('I=100A, L=10km, R=X=0,1, FP=0,8, V=13,8kV', () {
      // ΔV = √3·100·10·(0,1·0,8 + 0,1·0,6) = 1732,05·0,14 ≈ 242,5 V
      final r = voltageDrop(
        currentA: 100,
        lengthKm: 10,
        rPerKm: 0.1,
        xPerKm: 0.1,
        powerFactor: 0.8,
        vLLkv: 13.8,
      );
      expect(r.dropVolts, closeTo(242.49, 0.5));
      expect(r.dropPercent, closeTo(1.757, 0.01));
    });

    test('comprimento zero → queda zero', () {
      final r = voltageDrop(
        currentA: 100,
        lengthKm: 0,
        rPerKm: 0.1,
        xPerKm: 0.1,
        powerFactor: 0.9,
        vLLkv: 13.8,
      );
      expect(r.dropVolts, closeTo(0, 1e-9));
    });
  });
}
