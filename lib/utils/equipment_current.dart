import 'dart:math' as math;

// Corrente nominal de equipamentos trifásicos.
//   Transformador: In = S / (√3 · V)        [S em kVA, V em kV → A]
//   Motor:         In = P / (√3 · V · FP · η) [P em kW, V em V → A]

const double cvToKw = 0.7355; // 1 CV ≈ 0,7355 kW

double transformerRatedCurrent({
  required double powerKva,
  required double voltageKv,
}) {
  return powerKva / (math.sqrt(3) * voltageKv);
}

double motorRatedCurrent({
  required double powerKw,
  required double voltageV,
  required double powerFactor,
  required double efficiency,
}) {
  return powerKw * 1000.0 /
      (math.sqrt(3) * voltageV * powerFactor * efficiency);
}
