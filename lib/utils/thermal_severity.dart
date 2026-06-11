import 'dart:math' as math;

// Severidade de anomalia térmica (inspeção termográfica).
// Escala referenciada à comparação entre componentes similares sob carga
// semelhante (base NETA MTS). ΔT em °C.

class ThermalClass {
  final int level; // 0 normal · 1 investigar · 2 reparo programado · 3 imediato
  final String label;
  final String action;

  const ThermalClass(this.level, this.label, this.action);
}

ThermalClass classifySimilarComponent(double deltaT) {
  if (deltaT < 1) {
    return const ThermalClass(0, 'Normal', 'Sem anomalia térmica relevante.');
  }
  if (deltaT <= 3) {
    return const ThermalClass(1, 'Investigar',
        'Possível deficiência — investigar e acompanhar.');
  }
  if (deltaT <= 15) {
    return const ThermalClass(2, 'Reparo programado',
        'Deficiência — reparar na próxima manutenção programada.');
  }
  return const ThermalClass(3, 'Reparo imediato',
      'Deficiência grave — reparar o quanto antes.');
}

// Projeta o ΔT medido para a corrente nominal (carga plena).
//   ΔT_corrigido = ΔT_medido · (I_nominal / I_medida)²
double correctDeltaTForLoad({
  required double deltaTMeasured,
  required double currentMeasured,
  required double currentNominal,
}) {
  if (currentMeasured <= 0) return double.nan;
  return deltaTMeasured *
      math.pow(currentNominal / currentMeasured, 2).toDouble();
}
