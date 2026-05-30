import 'dart:math' as math;

// Triângulo de potências: a partir de dois valores conhecidos, calcula os demais.
//   S = √(P² + Q²) · P = S·cosφ · Q = S·senφ · FP = P/S

class PowerTriangle {
  final double activeKw; // P
  final double reactiveKvar; // Q
  final double apparentKva; // S
  final double powerFactor; // FP

  const PowerTriangle({
    required this.activeKw,
    required this.reactiveKvar,
    required this.apparentKva,
    required this.powerFactor,
  });
}

PowerTriangle triangleFromActiveAndPf(double p, double pf) {
  final s = pf != 0 ? p / pf : double.infinity;
  final q = math.sqrt(math.max(0, s * s - p * p));
  return PowerTriangle(
      activeKw: p, reactiveKvar: q, apparentKva: s, powerFactor: pf);
}

PowerTriangle triangleFromActiveAndReactive(double p, double q) {
  final s = math.sqrt(p * p + q * q);
  return PowerTriangle(
      activeKw: p,
      reactiveKvar: q,
      apparentKva: s,
      powerFactor: s > 0 ? p / s : 0);
}

PowerTriangle triangleFromApparentAndPf(double s, double pf) {
  final p = s * pf;
  final q = math.sqrt(math.max(0, s * s - p * p));
  return PowerTriangle(
      activeKw: p, reactiveKvar: q, apparentKva: s, powerFactor: pf);
}
