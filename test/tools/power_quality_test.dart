import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/power_quality.dart';

void main() {
  group('Carregamento de transformador', () {
    test('13,8 kV, 400 A, 10 MVA → ~95,6%', () {
      final r = transformerLoading(vLLkv: 13.8, currentA: 400, ratedKva: 10000);
      // S = √3·13,8·400 = 9561 kVA → 95,6%
      expect(r.apparentKva, closeTo(9561.0, 1.0));
      expect(r.loadingPercent, closeTo(95.6, 0.1));
    });

    test('carga plena ≈ 100%', () {
      final r = transformerLoading(vLLkv: 13.8, currentA: 418.4, ratedKva: 10000);
      expect(r.loadingPercent, closeTo(100, 0.5));
    });
  });

  group('Desequilíbrio de tensão', () {
    test('sistema equilibrado → FD ≈ 0', () {
      final fd = voltageUnbalanceProdist(
        va: 220, angA: 0, vb: 220, angB: -120, vc: 220, angC: 120,
      );
      expect(fd, closeTo(0, 1e-6));
    });

    test('PRODIST: desbalanço de módulo gera FD > 0', () {
      final fd = voltageUnbalanceProdist(
        va: 220, angA: 0, vb: 215, angB: -120, vc: 222, angC: 120,
      );
      expect(fd, greaterThan(0));
      expect(fd, lessThan(5)); // pequeno desbalanço
    });

    test('aproximada: equilibrado → ~0', () {
      final fd = voltageUnbalanceApprox(v1: 220, v2: 220, v3: 220);
      expect(fd, closeTo(0, 1e-6));
    });

    test('PRODIST e aproximada — mesma ordem de grandeza', () {
      // Os dois métodos diferem (a aproximada é mais conservadora): para
      // 230/220/225 com ângulos ideais, PRODIST≈1,28% e aproximada≈2,10%.
      // Ambos indicam desbalanço pequeno, mas não são idênticos — é esperado.
      final prod = voltageUnbalanceProdist(
        va: 230, angA: 0, vb: 220, angB: -120, vc: 225, angC: 120,
      );
      final aprox = voltageUnbalanceApprox(v1: 230, v2: 220, v3: 225);
      expect(prod, closeTo(1.28, 0.1));
      expect(aprox, closeTo(2.10, 0.1));
      expect(aprox, greaterThan(prod)); // aproximada mais conservadora aqui
    });

    test('desvio máximo (NEMA)', () {
      // média = 219, maior desvio = 222-219=3 → 3/219 = 1,37%
      final d = maxDeviationUnbalance(v1: 219, v2: 216, v3: 222);
      expect(d, closeTo(1.37, 0.05));
    });
  });
}
