import 'dart:math' as math;

// Estimativa do pico de inrush de UM transformador a partir dos seus dados,
// em vez de chutar o fator k (×In). Complementa o "Inrush de banco", que soma
// picos já conhecidos.
//
// Modelo de triagem (energização a vazio):
//   • Corrente nominal: In = S / (√3 · V)
//   • A corrente de inrush no pior caso (energização no zero da tensão, com
//     fluxo residual) é limitada pela impedância de curto do trafo e pela
//     saturação do núcleo. Uma estimativa de campo usada é:
//       Î_pico ≈ (√2 · V_pu) / (Z_cc_pu + X_sat_pu) · In_pico_base
//     Simplificando para o múltiplo de In (k = Î/In·√2 base de pico):
//       k_pico ≈ (1 + fluxo_residual) / (Z% / 100)   limitado por saturação
//
// Aqui usamos uma forma compacta e transparente:
//   k = kBase · (1 + br) , com kBase ≈ 1/(Zcc_pu)·fator_nucleo, saturado em kMax
// onde br = fluxo residual (0..0,8 pu) e kMax limita a valores físicos (8–15×).
//
// NÃO é cálculo transitório (EMTP). É estimativa para dimensionar margem do 50
// e escolher bloqueio por 2º harmônico.

class InrushEstimate {
  final double ratedCurrent; // In (A)
  final double peakFactor; // k = Î_pico / In
  final double peakCurrent; // Î_pico (A)
  final double secondHarmonicRatio; // %2ªH típico estimado
  final bool harmonicBlockOk; // %2H acima do bloqueio típico (15%)

  const InrushEstimate({
    required this.ratedCurrent,
    required this.peakFactor,
    required this.peakCurrent,
    required this.secondHarmonicRatio,
    required this.harmonicBlockOk,
  });
}

double ratedCurrentA({required double powerKva, required double voltageKv}) {
  if (voltageKv <= 0) return double.nan;
  return powerKva / (math.sqrt(3) * voltageKv);
}

// Estima o fator de pico do inrush.
//   zccPercent : impedância de curto-circuito do trafo (%)
//   residualFlux : fluxo residual no núcleo (0..0,8 pu)
//   coreFactor : fator do núcleo (saturação) — típico 0,9..1,1
//   kMax : limite físico do pico (padrão 15×)
double inrushPeakFactor({
  required double zccPercent,
  double residualFlux = 0.6,
  double coreFactor = 1.0,
  double kMax = 15.0,
}) {
  if (zccPercent <= 0) return double.nan;
  final zpu = zccPercent / 100.0;
  // pico base limitado pela impedância de curto; ajustado por núcleo e fluxo.
  final kBase = coreFactor / zpu;
  final k = kBase * (1 + residualFlux.clamp(0.0, 0.8));
  return k > kMax ? kMax : k;
}

// 2º harmônico estimado (decresce com a severidade do inrush). Valores típicos
// de campo: 15–30% da fundamental no inrush; cai quando há saturação profunda.
double estimatedSecondHarmonic({required double peakFactor}) {
  // quanto maior o k, mais distorcida — porém o %2H costuma ficar 15–30%.
  // modelo simples: ~30% para k baixo, caindo a ~15% para k alto.
  final h = 30.0 - (peakFactor - 6.0) * 1.2;
  return h.clamp(12.0, 35.0);
}

InrushEstimate estimateInrush({
  required double powerKva,
  required double voltageKv,
  required double zccPercent,
  double residualFlux = 0.6,
  double coreFactor = 1.0,
  double harmonicBlockThreshold = 15.0,
}) {
  final inA = ratedCurrentA(powerKva: powerKva, voltageKv: voltageKv);
  final k = inrushPeakFactor(
    zccPercent: zccPercent,
    residualFlux: residualFlux,
    coreFactor: coreFactor,
  );
  final peak = inA * k;
  final h2 = estimatedSecondHarmonic(peakFactor: k);
  return InrushEstimate(
    ratedCurrent: inA,
    peakFactor: k,
    peakCurrent: peak,
    secondHarmonicRatio: h2,
    harmonicBlockOk: h2 >= harmonicBlockThreshold,
  );
}
