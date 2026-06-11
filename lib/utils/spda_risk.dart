import 'dart:math' as math;

// Análise de risco de SPDA — TRIAGEM simplificada baseada na NBR 5419-2.
//
// IMPORTANTE: ferramenta de triagem. NÃO substitui a análise de risco completa
// da NBR 5419-2 (que soma as componentes RA, RB, RC, RM, RU, RV, RW, RZ com
// dezenas de coeficientes P/L e compara com o risco tolerável). Aqui estimamos
// o número provável de eventos perigosos N e indicamos se há indício de
// necessidade de SPDA e um nível de proteção provável — para orientar quando
// vale fazer o estudo formal.
//
// Passos (5419-2, simplificado):
//   • Área de exposição equivalente da estrutura isolada (m²):
//       Ad = L·W + 2·(3H)·(L+W) + π·(3H)²
//     (L, W, H em metros)
//   • Número de eventos perigosos por ano na estrutura:
//       Nd = Ng · Ad · Cd · 1e-6
//     Ng = densidade de descargas (descargas/km²/ano); Cd = fator de localização.
//   • Frequência admissível de eventos Nc (decisão simplificada da norma):
//     ~1e-3 /ano (referência de triagem). NÃO confundir com o risco tolerável
//     R1=1e-5: o risco R = Nd·P·L é bem menor que Nd, então o critério de
//     necessidade de SPDA compara Nd com Nc, não Nd com 1e-5.
//   • Triagem: se Nd ≤ Nc → SPDA tende a ser dispensável; caso contrário,
//     estima-se a eficiência de SPDA necessária E = 1 − Nc/Nd e mapeia-se ao
//     nível (E ≥ 0,98 → I; ≥0,95 → II; ≥0,90 → III; ≥0,80 → IV).

// Fator de localização Cd (NBR 5419-2, Tabela A.1).
enum StructureLocation { surrounded, near, isolated, isolatedHill }

double cdFactor(StructureLocation loc) {
  switch (loc) {
    case StructureLocation.surrounded:
      return 0.25; // cercada por objetos mais altos
    case StructureLocation.near:
      return 0.5; // objetos da mesma altura ou menores por perto
    case StructureLocation.isolated:
      return 1.0; // isolada
    case StructureLocation.isolatedHill:
      return 2.0; // isolada no topo de morro
  }
}

class SpdaRiskResult {
  final double collectionAreaAd; // m²
  final double dangerousEvents; // Nd (eventos/ano)
  final double admissibleFrequency; // Nc (eventos/ano)
  final bool spdaLikelyNeeded; // Nd > Nc
  final double requiredEfficiency; // E (0..1), 0 se dispensável
  final String? suggestedLevel; // 'I'..'IV' ou null

  const SpdaRiskResult({
    required this.collectionAreaAd,
    required this.dangerousEvents,
    required this.admissibleFrequency,
    required this.spdaLikelyNeeded,
    required this.requiredEfficiency,
    required this.suggestedLevel,
  });
}

// Área de captação equivalente de uma estrutura retangular isolada (m²).
double collectionArea({
  required double length,
  required double width,
  required double height,
}) {
  final l = length, w = width, h = height;
  return l * w + 2 * (3 * h) * (l + w) + math.pi * math.pow(3 * h, 2);
}

// Nível de proteção sugerido a partir da eficiência requerida.
String? levelForEfficiency(double e) {
  if (e <= 0) return null;
  if (e >= 0.98) return 'I';
  if (e >= 0.95) return 'II';
  if (e >= 0.90) return 'III';
  if (e >= 0.80) return 'IV';
  // E < 0,80: um único nível não basta isoladamente — nível IV + medidas extras.
  return 'IV+';
}

SpdaRiskResult spdaRiskScreening({
  required double length,
  required double width,
  required double height,
  required double ngDensity, // descargas/km²/ano
  required StructureLocation location,
  double admissibleFrequency = 1e-3, // Nc de referência (triagem)
}) {
  final ad = collectionArea(length: length, width: width, height: height);
  final cd = cdFactor(location);
  final nd = ngDensity * ad * cd * 1e-6;

  final needed = nd > admissibleFrequency;
  final efficiency = needed ? (1 - admissibleFrequency / nd) : 0.0;
  return SpdaRiskResult(
    collectionAreaAd: ad,
    dangerousEvents: nd,
    admissibleFrequency: admissibleFrequency,
    spdaLikelyNeeded: needed,
    requiredEfficiency: efficiency,
    suggestedLevel: needed ? levelForEfficiency(efficiency) : null,
  );
}
