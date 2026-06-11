// Escalonamento linear de sinal de instrumentação ↔ grandeza de engenharia.
// Ex.: 4–20 mA representando 0–100 % (ou 0–10 bar, etc.).
//   eng    = engMin + (sinal − sigMin)/(sigMax − sigMin) · (engMax − engMin)
//   sinal  = sigMin + (eng − engMin)/(engMax − engMin) · (sigMax − sigMin)

double signalToEng({
  required double signal,
  required double sigMin,
  required double sigMax,
  required double engMin,
  required double engMax,
}) {
  return engMin + (signal - sigMin) / (sigMax - sigMin) * (engMax - engMin);
}

double engToSignal({
  required double eng,
  required double sigMin,
  required double sigMax,
  required double engMin,
  required double engMax,
}) {
  return sigMin + (eng - engMin) / (engMax - engMin) * (sigMax - sigMin);
}
