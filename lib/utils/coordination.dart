// Coordenação/seletividade entre dois relés de sobrecorrente (51).
// O intervalo de coordenação (CTI) é a diferença de tempo entre o relé de
// retaguarda (montante) e o relé principal (jusante) para a mesma falta.
// Coordenado quando o CTI real ≥ CTI mínimo desejado (tipicamente 0,3–0,4 s).

class CoordinationResult {
  final double timeMain; // tempo do relé principal/jusante (s)
  final double timeBackup; // tempo do relé de retaguarda/montante (s)
  final double interval; // CTI real = backup − main (s)
  final bool coordinated;

  const CoordinationResult({
    required this.timeMain,
    required this.timeBackup,
    required this.interval,
    required this.coordinated,
  });
}

CoordinationResult coordinationCheck({
  required double timeMain,
  required double timeBackup,
  required double requiredCti,
}) {
  final interval = timeBackup - timeMain;
  return CoordinationResult(
    timeMain: timeMain,
    timeBackup: timeBackup,
    interval: interval,
    coordinated: interval >= requiredCti,
  );
}
