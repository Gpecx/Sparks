import 'dart:math' as math;

// Coeficiente de balanço da proteção diferencial (87T).
// Compensa as diferentes correntes secundárias dos TCs de cada enrolamento,
// de forma que o relé veja correntes equilibradas em carga passante.

class WindingInput {
  final double powerMva;
  final double voltageKv;
  final double ctPrimary;
  final double ctSecondary;

  const WindingInput({
    required this.powerMva,
    required this.voltageKv,
    required this.ctPrimary,
    required this.ctSecondary,
  });
}

class WindingResult {
  final double nominalCurrent; // corrente nominal no primário do enrolamento (A)
  final double secondaryCurrent; // corrente no secundário do TC (A)
  final double balance; // coeficiente de balanço (referência = 1)

  const WindingResult({
    required this.nominalCurrent,
    required this.secondaryCurrent,
    required this.balance,
  });
}

// I_nom = S / (√3 · V), com S em MVA e V em kV → resultado em A.
double windingNominalCurrent({required double powerMva, required double voltageKv}) {
  return powerMva * 1000.0 / (math.sqrt(3) * voltageKv);
}

List<WindingResult> computeDifferentialBalance(
  List<WindingInput> windings,
  int referenceIndex,
) {
  final nominal = windings
      .map((w) =>
          windingNominalCurrent(powerMva: w.powerMva, voltageKv: w.voltageKv))
      .toList();
  final secondary = List<double>.generate(
    windings.length,
    (i) => nominal[i] * (windings[i].ctSecondary / windings[i].ctPrimary),
  );
  final reference = secondary[referenceIndex];
  return List<WindingResult>.generate(
    windings.length,
    (i) => WindingResult(
      nominalCurrent: nominal[i],
      secondaryCurrent: secondary[i],
      balance: reference / secondary[i],
    ),
  );
}
