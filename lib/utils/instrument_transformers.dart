// Relação de transformação de TC (RTC) e TP (RTP).
// RTC = I_primário_nominal / I_secundário_nominal  (ex.: 600/5 → 120)
// RTP = V_primário_nominal / V_secundário_nominal

double transformRatio(double primaryNominal, double secondaryNominal) {
  return primaryNominal / secondaryNominal;
}

// Valor refletido ao secundário a partir de um valor no primário.
double secondaryFromPrimary(double primaryValue, double ratio) {
  return primaryValue / ratio;
}

// Valor refletido ao primário a partir de um valor no secundário.
double primaryFromSecondary(double secondaryValue, double ratio) {
  return secondaryValue * ratio;
}
