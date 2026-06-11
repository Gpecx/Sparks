import 'dart:math' as math;

// Queda de tensão em alimentador trifásico:
//   ΔV = √3 · I · L · (R·cosφ + X·senφ)
// com I em A, L em km, R e X em Ω/km → ΔV em V (entre fases).
// ΔV% = ΔV / V_LL_nominal · 100

class VoltageDropResult {
  final double dropVolts;
  final double dropPercent;

  const VoltageDropResult({required this.dropVolts, required this.dropPercent});
}

VoltageDropResult voltageDrop({
  required double currentA,
  required double lengthKm,
  required double rPerKm,
  required double xPerKm,
  required double powerFactor,
  required double vLLkv,
}) {
  final cos = powerFactor.clamp(-1.0, 1.0);
  final sin = math.sqrt(1 - cos * cos);
  final drop = math.sqrt(3) * currentA * lengthKm * (rPerKm * cos + xPerKm * sin);
  final percent = vLLkv > 0 ? drop / (vLLkv * 1000.0) * 100.0 : double.nan;
  return VoltageDropResult(dropVolts: drop, dropPercent: percent);
}
