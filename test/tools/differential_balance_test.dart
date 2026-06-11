import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/differential_balance.dart';

void main() {
  group('Balanço diferencial (87T)', () {
    test('reproduz os valores da ferramenta SRPD: 1,000 / 1,039', () {
      final res = computeDifferentialBalance(const [
        WindingInput(powerMva: 40, voltageKv: 115.5, ctPrimary: 200, ctSecondary: 1),
        WindingInput(powerMva: 40, voltageKv: 30, ctPrimary: 800, ctSecondary: 1),
      ], 0);

      // Correntes nominais
      expect(res[0].nominalCurrent, closeTo(199.948, 0.05));
      expect(res[1].nominalCurrent, closeTo(769.800, 0.1));

      // Coeficientes de balanço
      expect(res[0].balance, closeTo(1.000, 1e-3));
      expect(res[1].balance, closeTo(1.039, 1e-3));
    });

    test('enrolamento de referência sempre tem balanço 1,000', () {
      final res = computeDifferentialBalance(const [
        WindingInput(powerMva: 25, voltageKv: 69, ctPrimary: 400, ctSecondary: 5),
        WindingInput(powerMva: 25, voltageKv: 13.8, ctPrimary: 1200, ctSecondary: 5),
      ], 1);
      expect(res[1].balance, closeTo(1.0, 1e-9));
    });
  });
}
