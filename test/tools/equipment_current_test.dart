import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/equipment_current.dart';

void main() {
  group('Corrente nominal de equipamentos', () {
    test('Trafo 1000 kVA, 13,8 kV → ~41,84 A', () {
      final i = transformerRatedCurrent(powerKva: 1000, voltageKv: 13.8);
      expect(i, closeTo(41.84, 0.05));
    });

    test('Trafo 1000 kVA, 0,38 kV → ~1519,3 A', () {
      final i = transformerRatedCurrent(powerKva: 1000, voltageKv: 0.38);
      expect(i, closeTo(1519.3, 0.5));
    });

    test('Motor 75 kW, 380 V, FP 0,85, η 0,93 → ~144,2 A', () {
      final i = motorRatedCurrent(powerKw: 75, voltageV: 380, powerFactor: 0.85, efficiency: 0.93);
      expect(i, closeTo(144.2, 0.5));
    });

    test('conversão CV→kW', () {
      expect(100 * cvToKw, closeTo(73.55, 1e-9));
    });
  });
}
