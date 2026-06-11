import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/thermal_severity.dart';

void main() {
  group('Severidade térmica', () {
    test('classificação por faixas de ΔT', () {
      expect(classifySimilarComponent(0.5).level, 0); // normal
      expect(classifySimilarComponent(2).level, 1); // investigar
      expect(classifySimilarComponent(8).level, 2); // reparo programado
      expect(classifySimilarComponent(25).level, 3); // imediato
    });

    test('correção por carga: I_med = metade da nominal → ΔT ×4', () {
      final c = correctDeltaTForLoad(
          deltaTMeasured: 8, currentMeasured: 50, currentNominal: 100);
      expect(c, closeTo(32, 1e-9)); // 8·(100/50)² = 8·4
    });

    test('I_med = I_nom → ΔT inalterado', () {
      final c = correctDeltaTForLoad(
          deltaTMeasured: 10, currentMeasured: 100, currentNominal: 100);
      expect(c, closeTo(10, 1e-9));
    });
  });
}
