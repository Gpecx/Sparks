import 'dart:math' as math;

// Cálculo simplificado de curto-circuito a partir das impedâncias de sequência
// (módulos, em Ω). Considera as impedâncias como escalares — aproximação válida
// quando as relações X/R das sequências são próximas.
//
//   E = V_LL / √3                       (tensão de fase)
//   3φ:           I = E / Z1
//   Bifásica:     I = √3 · E / (Z1 + Z2)
//   Monof.-terra: I = 3 · E / (Z1 + Z2 + Z0 + 3·Zf)

class ShortCircuitResult {
  final double threePhase; // A
  final double lineToLine; // A (bifásica)
  final double lineToGround; // A (monofásica-terra)

  const ShortCircuitResult({
    required this.threePhase,
    required this.lineToLine,
    required this.lineToGround,
  });
}

ShortCircuitResult shortCircuitCurrents({
  required double vLLkv,
  required double z1,
  required double z2,
  required double z0,
  double zf = 0,
}) {
  final ePhase = vLLkv * 1000.0 / math.sqrt(3);

  final i3 = z1 > 0 ? ePhase / z1 : double.nan;
  final iLL = (z1 + z2) > 0 ? math.sqrt(3) * ePhase / (z1 + z2) : double.nan;
  final denomLg = z1 + z2 + z0 + 3 * zf;
  final iLg = denomLg > 0 ? 3 * ePhase / denomLg : double.nan;

  return ShortCircuitResult(
    threePhase: i3,
    lineToLine: iLL,
    lineToGround: iLg,
  );
}
