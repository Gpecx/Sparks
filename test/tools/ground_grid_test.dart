import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/ground_grid.dart';

void main() {
  group('Malha de aterramento (IEEE 80)', () {
    test('ρs=2500, ts=0,5s, Cs=1, 50 kg', () {
      final r = groundGridTolerable(
        surfaceResistivity: 2500,
        faultDuration: 0.5,
        gridCurrent: 5000,
        gridResistance: 1,
      );
      // k = 0,116/√0,5 ≈ 0,16405
      expect(r.touchVoltage, closeTo(779.2, 1)); // (1000+3750)·k
      expect(r.stepVoltage, closeTo(2624.8, 2)); // (1000+15000)·k
      expect(r.gpr, closeTo(5000, 1e-6));
    });

    test('corpo de 70 kg eleva os limites toleráveis', () {
      final v50 = groundGridTolerable(surfaceResistivity: 2500, faultDuration: 0.5);
      final v70 = groundGridTolerable(
          surfaceResistivity: 2500, faultDuration: 0.5, body70kg: true);
      expect(v70.touchVoltage, greaterThan(v50.touchVoltage));
      expect(v70.stepVoltage, greaterThan(v50.stepVoltage));
    });
  });
}
