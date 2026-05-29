import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/complex_number.dart';
import 'package:spark_app/utils/symmetrical_components.dart';

void main() {
  group('Componentes Simétricas — decomposição', () {
    test('sistema equilibrado: V1=1∠0, V2=0, V0=0', () {
      final phase = PhaseComponents(
        a: Complex.polarDegrees(1, 0),
        b: Complex.polarDegrees(1, -120),
        c: Complex.polarDegrees(1, 120),
      );
      final seq = decompose(phase);

      expect(seq.positive.magnitude, closeTo(1.0, 1e-6));
      expect(seq.positive.angleDegrees, closeTo(0.0, 1e-6));
      expect(seq.negative.magnitude, closeTo(0.0, 1e-6));
      expect(seq.zero.magnitude, closeTo(0.0, 1e-6));
    });

    test('desbalanço: V1≈0.833∠0, V2≈0.167∠-60, V0≈0.167∠60', () {
      final phase = PhaseComponents(
        a: Complex.polarDegrees(1, 0),
        b: Complex.polarDegrees(0.5, -120),
        c: Complex.polarDegrees(1, 120),
      );
      final seq = decompose(phase);

      expect(seq.positive.magnitude, closeTo(0.8333, 1e-3));
      expect(seq.positive.angleDegrees, closeTo(0.0, 1e-2));

      expect(seq.negative.magnitude, closeTo(0.1667, 1e-3));
      expect(seq.negative.angleDegrees, closeTo(-60.0, 1e-2));

      expect(seq.zero.magnitude, closeTo(0.1667, 1e-3));
      expect(seq.zero.angleDegrees, closeTo(60.0, 1e-2));
    });
  });

  group('Componentes Simétricas — síntese (inversa da decomposição)', () {
    test('decompor e sintetizar reconstrói os fasores originais', () {
      final phase = PhaseComponents(
        a: Complex.polarDegrees(1, 0),
        b: Complex.polarDegrees(0.5, -120),
        c: Complex.polarDegrees(1, 120),
      );
      final seq = decompose(phase);
      final back = synthesize(seq);

      expect(back.a.re, closeTo(phase.a.re, 1e-6));
      expect(back.a.im, closeTo(phase.a.im, 1e-6));
      expect(back.b.re, closeTo(phase.b.re, 1e-6));
      expect(back.b.im, closeTo(phase.b.im, 1e-6));
      expect(back.c.re, closeTo(phase.c.re, 1e-6));
      expect(back.c.im, closeTo(phase.c.im, 1e-6));
    });
  });
}
