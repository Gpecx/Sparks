import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/short_circuit.dart';

void main() {
  group('Curto-circuito (escalar)', () {
    test('Z1=Z2=Z0=1Ω, V=13,8kV', () {
      final ePhase = 13800 / math.sqrt(3); // ≈ 7967,4 V
      final r = shortCircuitCurrents(vLLkv: 13.8, z1: 1, z2: 1, z0: 1);

      expect(r.threePhase, closeTo(ePhase, 0.1));
      expect(r.lineToLine, closeTo(math.sqrt(3) * ePhase / 2, 0.1));
      expect(r.lineToGround, closeTo(ePhase, 0.1)); // 3E/3 = E
    });

    test('3φ = E/Z1', () {
      final r = shortCircuitCurrents(vLLkv: 138, z1: 10, z2: 10, z0: 15);
      final ePhase = 138000 / math.sqrt(3);
      expect(r.threePhase, closeTo(ePhase / 10, 0.5));
    });

    test('impedância de falta reduz a corrente FT', () {
      final semZf = shortCircuitCurrents(vLLkv: 138, z1: 10, z2: 10, z0: 15);
      final comZf = shortCircuitCurrents(vLLkv: 138, z1: 10, z2: 10, z0: 15, zf: 5);
      expect(comZf.lineToGround, lessThan(semZf.lineToGround));
    });
  });
}
