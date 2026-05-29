import 'package:spark_app/utils/complex_number.dart';

class SequenceComponents {
  final Complex zero;
  final Complex positive;
  final Complex negative;

  const SequenceComponents({
    required this.zero,
    required this.positive,
    required this.negative,
  });
}

class PhaseComponents {
  final Complex a;
  final Complex b;
  final Complex c;

  const PhaseComponents({required this.a, required this.b, required this.c});
}

// Decomposição: fasores de fase (ABC) → componentes de sequência (0, 1, 2)
SequenceComponents decompose(PhaseComponents phase) {
  final v0 = (phase.a + phase.b + phase.c).divideBy(3);
  final v1 =
      (phase.a + operatorA * phase.b + operatorA2 * phase.c).divideBy(3);
  final v2 =
      (phase.a + operatorA2 * phase.b + operatorA * phase.c).divideBy(3);
  return SequenceComponents(zero: v0, positive: v1, negative: v2);
}

// Síntese: componentes de sequência (0, 1, 2) → fasores de fase (ABC)
PhaseComponents synthesize(SequenceComponents seq) {
  final va = seq.zero + seq.positive + seq.negative;
  final vb = seq.zero + operatorA2 * seq.positive + operatorA * seq.negative;
  final vc = seq.zero + operatorA * seq.positive + operatorA2 * seq.negative;
  return PhaseComponents(a: va, b: vb, c: vc);
}
