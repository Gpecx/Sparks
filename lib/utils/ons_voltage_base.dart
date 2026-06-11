// Conversão de tensão entre a base do estudo do ONS e o secundário real do TP.
//
// O erro comum em campo: o estudo pré-operacional do ONS expressa tensões em pu
// sobre uma base de tensão "redonda" (ex.: 230 kV, 500 kV), que frequentemente
// NÃO é igual à tensão nominal real do TP da subestação (ex.: 245 kV, 525 kV).
// Aplicar o pu do estudo diretamente sobre a tensão do TP gera ajustes errados
// em funções como 25 (sincronismo), 59 (sobretensão), 27 (subtensão), etc.
//
//   V_primária = pu_ONS · V_base_ONS                         (kV, fase-fase)
//   pu_TP      = V_primária / V_nominal_TP_primário          (pu na base do TP)
//   V_secundária = V_primária · (V_sec_TP / V_prim_TP)       (V, no secundário)
// As tensões podem ser tratadas como fase-fase (consistente em todo o cálculo).

class OnsVoltageResult {
  final double primaryKv; // tensão primária correspondente (kV)
  final double puOnsBase; // pu na base do ONS (entrada)
  final double puTpBase; // pu na base nominal do TP
  final double secondaryVolts; // tensão no secundário do TP (V)

  const OnsVoltageResult({
    required this.primaryKv,
    required this.puOnsBase,
    required this.puTpBase,
    required this.secondaryVolts,
  });
}

// pu (base ONS) → tensão primária, pu na base do TP e tensão secundária.
OnsVoltageResult onsPuToSecondary({
  required double puOns,
  required double vBaseOnsKv,
  required double vNominalTpPrimaryKv,
  required double vTpSecondaryV,
}) {
  final primaryKv = puOns * vBaseOnsKv;
  final puTp = vNominalTpPrimaryKv != 0 ? primaryKv / vNominalTpPrimaryKv : double.nan;
  final secondary = vNominalTpPrimaryKv != 0
      ? primaryKv * (vTpSecondaryV / vNominalTpPrimaryKv)
      : double.nan;
  return OnsVoltageResult(
    primaryKv: primaryKv,
    puOnsBase: puOns,
    puTpBase: puTp,
    secondaryVolts: secondary,
  );
}

// Caminho inverso: tensão secundária medida → pu na base do ONS.
OnsVoltageResult secondaryToOnsPu({
  required double secondaryV,
  required double vBaseOnsKv,
  required double vNominalTpPrimaryKv,
  required double vTpSecondaryV,
}) {
  final primaryKv = vTpSecondaryV != 0
      ? secondaryV * (vNominalTpPrimaryKv / vTpSecondaryV)
      : double.nan;
  final puOns = vBaseOnsKv != 0 ? primaryKv / vBaseOnsKv : double.nan;
  final puTp = vNominalTpPrimaryKv != 0 ? primaryKv / vNominalTpPrimaryKv : double.nan;
  return OnsVoltageResult(
    primaryKv: primaryKv,
    puOnsBase: puOns,
    puTpBase: puTp,
    secondaryVolts: secondaryV,
  );
}

// Erro percentual cometido ao aplicar o pu do ONS direto sobre o secundário do
// TP (ignorando a diferença de base). Útil para mostrar o tamanho do engano.
double baseMismatchErrorPercent({
  required double vBaseOnsKv,
  required double vNominalTpPrimaryKv,
}) {
  if (vNominalTpPrimaryKv == 0) return double.nan;
  return (vBaseOnsKv / vNominalTpPrimaryKv - 1.0) * 100.0;
}
