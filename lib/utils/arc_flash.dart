import 'dart:math' as math;

// Energia incidente de arco elétrico — estimativa de campo.
//
// IMPORTANTE: ferramenta de triagem rápida, NÃO substitui um estudo de arc
// flash formal (IEEE 1584-2018) feito em software dedicado com a corrente de
// curto real, tempo de eliminação dos relés e dados completos do barramento.
//
// Dois modelos:
//  • Lee (1982) — modelo teórico clássico (arco no ar, conservador acima de
//    ~15 kV). Independe da configuração do eletrodo e da abertura.
//        E[cal/cm²] = 5,12e5 · V · Ibf · (t / D²)        [V em kV, Ibf em kA,
//        t em s, D em mm] — forma usual em cal/cm² com 793 como constante p/ in.
//  • IEEE 1584-2002 (empírico) — válido p/ 208 V–15 kV, Ibf 0,7–106 kA,
//    gap 13–152 mm. Usamos a formulação clássica de 2002 (lg) por ser fechada
//    e suficiente para triagem; o 1584-2018 refina com termos adicionais.
//
// Categorias de EPI (NFPA 70E, energia incidente em cal/cm²):
//   ≤1,2 → abaixo do limiar de queimadura 2º grau (mas há risco)
//   ≤4   → Cat 1   ≤8 → Cat 2   ≤25 → Cat 3   ≤40 → Cat 4   >40 → perigo extremo

class ArcFlashResult {
  final double incidentEnergy; // cal/cm²
  final double arcingCurrentKa; // kA (NaN no modelo Lee)
  final int ppeCategory; // 0..4 ; -1 = perigo extremo (>40)
  final String model; // 'IEEE 1584-2002' ou 'Lee'
  final bool outOfRange; // fora da validade do modelo empírico

  const ArcFlashResult({
    required this.incidentEnergy,
    required this.arcingCurrentKa,
    required this.ppeCategory,
    required this.model,
    required this.outOfRange,
  });
}

// Configuração do eletrodo (afeta o fator de distância x no modelo empírico).
enum ArcEnclosure { open, box }

// Classe de equipamento — fator de distância "x" do IEEE 1584-2002.
class EnclosureFactor {
  final String name;
  final double gapMm; // abertura típica entre condutores
  final double distanceExponent; // x
  const EnclosureFactor(this.name, this.gapMm, this.distanceExponent);
}

const enclosurePresets = <EnclosureFactor>[
  EnclosureFactor('Painel BT (≤1 kV)', 25, 1.473),
  EnclosureFactor('CCM / Quadro BT', 25, 1.641),
  EnclosureFactor('Cabo (open air) BT', 13, 2.0),
  EnclosureFactor('Switchgear MT (5 kV)', 102, 0.973),
  EnclosureFactor('Switchgear MT (15 kV)', 153, 0.973),
];

// Corrente de arco (IEEE 1584-2002) em kA, a partir da corrente de curto Ibf.
//   lg(Ia) = K + 0,662·lg(Ibf) + 0,0966·V + 0,000526·G
//            + 0,5588·V·lg(Ibf) − 0,00304·G·lg(Ibf)
//   (BT, V<1kV: K=−0,153 box / −0,097 open; MT: Ia≈Ibf de forma simplificada)
double arcingCurrentKa({
  required double iBfKa,
  required double voltageKv,
  required double gapMm,
  required ArcEnclosure enclosure,
}) {
  if (voltageKv >= 1.0) {
    // Acima de 1 kV o IEEE 1584 usa Ia ≈ Ibf (lg simplificado converge a ~1).
    return iBfKa;
  }
  final lgIbf = _log10(iBfKa);
  final k = enclosure == ArcEnclosure.box ? -0.153 : -0.097;
  final lgIa = k +
      0.662 * lgIbf +
      0.0966 * voltageKv +
      0.000526 * gapMm +
      0.5588 * voltageKv * lgIbf -
      0.00304 * gapMm * lgIbf;
  return math.pow(10, lgIa).toDouble();
}

// Energia incidente normalizada e final (IEEE 1584-2002), cal/cm².
//   lg(En) = K1 + K2 + 1,081·lg(Ia) + 0,0011·G   (En p/ t=0,2s, D=610mm)
//   E = 4,184·Cf·En·(t/0,2)·(610^x / D^x)
ArcFlashResult arcFlashIeee1584({
  required double iBfKa,
  required double voltageKv,
  required double clearingTimeS,
  required double workingDistanceMm,
  required double gapMm,
  required double distanceExponent,
  required ArcEnclosure enclosure,
}) {
  final inRange = voltageKv >= 0.208 &&
      voltageKv <= 15.0 &&
      iBfKa >= 0.7 &&
      iBfKa <= 106.0 &&
      gapMm >= 13 &&
      gapMm <= 152;

  if (!inRange) {
    // Fora da validade → cai no modelo Lee (mais conservador).
    final e = arcFlashLee(
      iBfKa: iBfKa,
      voltageKv: voltageKv,
      clearingTimeS: clearingTimeS,
      workingDistanceMm: workingDistanceMm,
    );
    return ArcFlashResult(
      incidentEnergy: e,
      arcingCurrentKa: double.nan,
      ppeCategory: ppeCategory(e),
      model: 'Lee (fora da faixa 1584)',
      outOfRange: true,
    );
  }

  final ia = arcingCurrentKa(
    iBfKa: iBfKa,
    voltageKv: voltageKv,
    gapMm: gapMm,
    enclosure: enclosure,
  );
  final lgIa = _log10(ia);
  final k1 = enclosure == ArcEnclosure.box ? -0.555 : -0.792;
  final k2 = 0.0; // sistemas aterrados; -0,113 p/ não-aterrados
  final lgEn = k1 + k2 + 1.081 * lgIa + 0.0011 * gapMm;
  final en = math.pow(10, lgEn).toDouble(); // J/cm² normalizada

  final cf = voltageKv <= 1.0 ? 1.5 : 1.0; // fator de cálculo
  final eJ = 4.184 *
      cf *
      en *
      (clearingTimeS / 0.2) *
      math.pow(610, distanceExponent) /
      math.pow(workingDistanceMm, distanceExponent);
  final eCal = eJ / 4.184; // J/cm² → cal/cm²

  return ArcFlashResult(
    incidentEnergy: eCal,
    arcingCurrentKa: ia,
    ppeCategory: ppeCategory(eCal),
    model: 'IEEE 1584-2002',
    outOfRange: false,
  );
}

// Modelo de Lee (cal/cm²) — arco no ar, teórico.
//   E = 793 · V · Ibf · t / D²   [V em kV, Ibf em kA, t em s, D em mm]
double arcFlashLee({
  required double iBfKa,
  required double voltageKv,
  required double clearingTimeS,
  required double workingDistanceMm,
}) {
  if (workingDistanceMm <= 0) return double.nan;
  return 793.0 *
      voltageKv *
      iBfKa *
      clearingTimeS /
      (workingDistanceMm * workingDistanceMm);
}

// Distância de aproximação segura (limite de 1,2 cal/cm²), em mm.
// Resolve E(D)=1,2 para o modelo Lee (escala 1/D²).
double safeApproachDistanceMm({
  required double iBfKa,
  required double voltageKv,
  required double clearingTimeS,
}) {
  final num = 793.0 * voltageKv * iBfKa * clearingTimeS;
  if (num <= 0) return double.nan;
  return math.sqrt(num / 1.2);
}

// Categoria de EPI conforme a energia incidente (cal/cm²).
int ppeCategory(double cal) {
  if (cal.isNaN || cal.isInfinite) return 0;
  if (cal > 40) return -1; // perigo extremo
  if (cal > 25) return 4;
  if (cal > 8) return 3;
  if (cal > 4) return 2;
  if (cal > 1.2) return 1;
  return 0;
}

String ppeLabel(int category) {
  switch (category) {
    case -1:
      return 'PERIGO EXTREMO (>40 cal/cm²) — trabalho energizado proibido';
    case 4:
      return 'Categoria 4 (40 cal/cm²)';
    case 3:
      return 'Categoria 3 (25 cal/cm²)';
    case 2:
      return 'Categoria 2 (8 cal/cm²)';
    case 1:
      return 'Categoria 1 (4 cal/cm²)';
    default:
      return 'Abaixo de 1,2 cal/cm² — risco baixo de queimadura 2º grau';
  }
}

double _log10(double x) => math.log(x) / math.ln10;
