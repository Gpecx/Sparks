// Verificação simplificada de saturação de TC de proteção (classe P, ex.: 10P20).
//
//   Zn (carga nominal)     = Sn / In²
//   Vk (tensão de joelho)  ≈ ALF · In · (Rct + Zn)
//   I_sec de falta         = I_falta_primária / RTC
//   V_req (tensão exigida) = I_sec_falta · (Rct + Zb_conectada)
//   ALF efetivo            = ALF · (Rct + Zn) / (Rct + Zb_conectada)
//   Satura quando V_req > Vk  (equivalente a múltiplo de falta > ALF efetivo)

class CtSaturationResult {
  final double rtc;
  final double inSec; // corrente secundária nominal (A)
  final double secondaryFaultCurrent; // A
  final double ratedBurdenOhm; // Zn (Ω)
  final double kneeVoltage; // Vk (V)
  final double requiredVoltage; // V_req (V)
  final double effectiveAlf;
  final double faultMultiple; // I_sec_falta / In
  final double margin; // Vk / V_req (≥ 1 → não satura)
  final bool saturates;

  const CtSaturationResult({
    required this.rtc,
    required this.inSec,
    required this.secondaryFaultCurrent,
    required this.ratedBurdenOhm,
    required this.kneeVoltage,
    required this.requiredVoltage,
    required this.effectiveAlf,
    required this.faultMultiple,
    required this.margin,
    required this.saturates,
  });
}

CtSaturationResult ctSaturation({
  required double ctPrimary,
  required double ctSecondary,
  required double rctOhm,
  required double ratedBurdenVa,
  required double alf,
  required double connectedBurdenOhm,
  required double faultPrimaryCurrent,
}) {
  final rtc = ctPrimary / ctSecondary;
  final inSec = ctSecondary;
  final zn = ratedBurdenVa / (inSec * inSec);
  final vk = alf * inSec * (rctOhm + zn);
  final iSecFault = faultPrimaryCurrent / rtc;
  final vReq = iSecFault * (rctOhm + connectedBurdenOhm);
  final alfEff = (rctOhm + connectedBurdenOhm) > 0
      ? alf * (rctOhm + zn) / (rctOhm + connectedBurdenOhm)
      : double.infinity;
  final faultMultiple = iSecFault / inSec;
  final margin = vReq > 0 ? vk / vReq : double.infinity;

  return CtSaturationResult(
    rtc: rtc,
    inSec: inSec,
    secondaryFaultCurrent: iSecFault,
    ratedBurdenOhm: zn,
    kneeVoltage: vk,
    requiredVoltage: vReq,
    effectiveAlf: alfEff,
    faultMultiple: faultMultiple,
    margin: margin,
    saturates: vReq > vk,
  );
}
