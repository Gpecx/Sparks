// Utilidades de comissionamento / ensaio de relés.

// Tolerância de ensaio: compara valor medido com o esperado.
//   erro% = (medido − esperado) / esperado · 100
//   aprovado quando |erro%| ≤ tolerância%

class ToleranceResult {
  final double errorPercent;
  final bool pass;

  const ToleranceResult({required this.errorPercent, required this.pass});
}

ToleranceResult toleranceCheck({
  required double measured,
  required double expected,
  required double tolerancePercent,
}) {
  if (expected == 0) {
    return const ToleranceResult(errorPercent: double.nan, pass: false);
  }
  final err = (measured - expected) / expected * 100.0;
  return ToleranceResult(errorPercent: err, pass: err.abs() <= tolerancePercent);
}

// Injeção secundária: valor a aplicar na mala de teste para simular um valor
// primário, usando a relação do TC/TP.
//   I_sec = I_falta_primária / RTC      V_sec = V_primária / RTP
double secondaryInjectionCurrent({
  required double faultPrimary,
  required double rtc,
}) {
  return rtc != 0 ? faultPrimary / rtc : double.nan;
}

double secondaryInjectionVoltage({
  required double primaryVoltage,
  required double rtp,
}) {
  return rtp != 0 ? primaryVoltage / rtp : double.nan;
}
