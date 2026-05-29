import 'dart:math' as math;

// Tensões de toque e passo toleráveis (IEEE Std 80) e elevação de potencial (GPR).
//   k = (0,116 [50 kg] ou 0,157 [70 kg]) / √ts
//   E_toque  = (1000 + 1,5 · Cs · ρs) · k
//   E_passo  = (1000 + 6   · Cs · ρs) · k
//   GPR      = I_malha · R_malha
// Cs = fator de redução da camada superficial (1,0 sem camada). ρs em Ω·m, ts em s.

class GroundGridResult {
  final double touchVoltage; // V
  final double stepVoltage; // V
  final double gpr; // V

  const GroundGridResult({
    required this.touchVoltage,
    required this.stepVoltage,
    required this.gpr,
  });
}

GroundGridResult groundGridTolerable({
  required double surfaceResistivity, // ρs (Ω·m)
  required double faultDuration, // ts (s)
  double cs = 1.0,
  bool body70kg = false,
  double gridCurrent = 0, // Ig (A)
  double gridResistance = 0, // Rg (Ω)
}) {
  final k = (body70kg ? 0.157 : 0.116) / math.sqrt(faultDuration);
  final touch = (1000 + 1.5 * cs * surfaceResistivity) * k;
  final step = (1000 + 6 * cs * surfaceResistivity) * k;
  final gpr = gridCurrent * gridResistance;
  return GroundGridResult(touchVoltage: touch, stepVoltage: step, gpr: gpr);
}
