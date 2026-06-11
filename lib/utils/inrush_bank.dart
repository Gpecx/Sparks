import 'dart:math' as math;

// Inrush de energização de um banco de transformadores no mesmo barramento.
//
// Quando vários trafos são energizados juntos (ou um já energizado + um novo),
// as correntes de inrush se somam no disjuntor/relé de montante. O ponto que
// importa em campo é: a soma do 1º pico do inrush fica abaixo do ajuste
// instantâneo (50) do relé de montante? Senão há trip na energização.
//
// Modelo de triagem:
//   • In de cada trafo = S / (√3 · V)
//   • Pico de inrush do trafo i = k_i · In_i  (k típico 8–12×)
//   • A coincidência não é perfeita: trafos energizados juntos têm picos
//     ligeiramente defasados. Aplica-se um fator de coincidência (0–1).
//   • Inrush do banco = fator · Σ(k_i · In_i)
//
// NÃO é estudo transitório (EMTP). É estimativa para checar margem do 50.

class TransformerInrush {
  final double ratedKva;
  final double voltageKv; // tensão do lado energizado
  final double inrushFactor; // k (×In)

  const TransformerInrush({
    required this.ratedKva,
    required this.voltageKv,
    required this.inrushFactor,
  });

  double get ratedCurrent =>
      voltageKv > 0 ? ratedKva / (math.sqrt(3) * voltageKv) : double.nan;

  double get inrushPeak => ratedCurrent * inrushFactor;
}

class BankInrushResult {
  final double totalRatedCurrent; // Σ In
  final double sumOfPeaks; // Σ (k·In)
  final double coincidentInrush; // fator · Σ peaks
  final double coincidenceFactor;
  final bool exceedsPickup; // > ajuste 50, se informado
  final double? marginPercent; // (pickup - inrush)/pickup·100

  const BankInrushResult({
    required this.totalRatedCurrent,
    required this.sumOfPeaks,
    required this.coincidentInrush,
    required this.coincidenceFactor,
    required this.exceedsPickup,
    required this.marginPercent,
  });
}

BankInrushResult bankInrush({
  required List<TransformerInrush> transformers,
  required double coincidenceFactor, // 0..1 (1 = pior caso, picos somam)
  double? instantaneousPickupA, // ajuste 50 do relé de montante (opcional)
}) {
  double sumIn = 0;
  double sumPeaks = 0;
  for (final t in transformers) {
    final inr = t.inrushPeak;
    if (inr.isNaN) continue;
    sumIn += t.ratedCurrent;
    sumPeaks += inr;
  }
  final cf = coincidenceFactor.clamp(0.0, 1.0);
  final coincident = sumPeaks * cf;

  bool exceeds = false;
  double? margin;
  if (instantaneousPickupA != null && instantaneousPickupA > 0) {
    exceeds = coincident > instantaneousPickupA;
    margin = (instantaneousPickupA - coincident) / instantaneousPickupA * 100.0;
  }

  return BankInrushResult(
    totalRatedCurrent: sumIn,
    sumOfPeaks: sumPeaks,
    coincidentInrush: coincident,
    coincidenceFactor: cf,
    exceedsPickup: exceeds,
    marginPercent: margin,
  );
}
