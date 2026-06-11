import 'dart:math' as math;

// Correção de fator de potência:
//   Q_c = P · (tanφ₁ − tanφ₂)
// com P em kW → Q_c em kvar (banco de capacitores necessário).

class PowerFactorResult {
  final double capacitorKvar;
  final double apparentBefore; // kVA
  final double apparentAfter; // kVA
  final double reactiveBefore; // kvar
  final double reactiveAfter; // kvar

  const PowerFactorResult({
    required this.capacitorKvar,
    required this.apparentBefore,
    required this.apparentAfter,
    required this.reactiveBefore,
    required this.reactiveAfter,
  });
}

PowerFactorResult powerFactorCorrection({
  required double activePowerKw,
  required double pfCurrent,
  required double pfTarget,
}) {
  final pf1 = pfCurrent.clamp(0.0001, 1.0);
  final pf2 = pfTarget.clamp(0.0001, 1.0);
  final phi1 = math.acos(pf1);
  final phi2 = math.acos(pf2);
  final tan1 = math.tan(phi1);
  final tan2 = math.tan(phi2);
  return PowerFactorResult(
    capacitorKvar: activePowerKw * (tan1 - tan2),
    apparentBefore: activePowerKw / pf1,
    apparentAfter: activePowerKw / pf2,
    reactiveBefore: activePowerKw * tan1,
    reactiveAfter: activePowerKw * tan2,
  );
}
