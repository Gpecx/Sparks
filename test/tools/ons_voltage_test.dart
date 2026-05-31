import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/ons_voltage_base.dart';

void main() {
  group('Tensão pu — base ONS × TP', () {
    // Estudo ONS em base 230 kV, TP real 245/115 (primário nominal 245 kV)
    test('pu(ONS) 1,05 com base 230 e TP 245/115', () {
      final r = onsPuToSecondary(
        puOns: 1.05,
        vBaseOnsKv: 230,
        vNominalTpPrimaryKv: 245,
        vTpSecondaryV: 115,
      );
      // primária = 1,05 × 230 = 241,5 kV
      expect(r.primaryKv, closeTo(241.5, 1e-6));
      // pu na base do TP = 241,5 / 245 = 0,98571
      expect(r.puTpBase, closeTo(0.98571, 1e-4));
      // secundária correta = 241,5/245 × 115 = 113,357 V
      expect(r.secondaryVolts, closeTo(113.357, 0.01));
    });

    test('o erro de aplicar pu direto sobre o secundário', () {
      // pu×Vsec direto = 1,05 × 115 = 120,75 V (ERRADO)
      // correto = 113,357 V → diferença relevante
      final r = onsPuToSecondary(
        puOns: 1.05, vBaseOnsKv: 230, vNominalTpPrimaryKv: 245, vTpSecondaryV: 115,
      );
      final naive = 1.05 * 115;
      expect(naive, closeTo(120.75, 1e-6));
      expect((naive - r.secondaryVolts).abs(), greaterThan(7.0));
    });

    test('caminho inverso é consistente', () {
      final fwd = onsPuToSecondary(
        puOns: 1.05, vBaseOnsKv: 230, vNominalTpPrimaryKv: 245, vTpSecondaryV: 115,
      );
      final back = secondaryToOnsPu(
        secondaryV: fwd.secondaryVolts,
        vBaseOnsKv: 230,
        vNominalTpPrimaryKv: 245,
        vTpSecondaryV: 115,
      );
      expect(back.puOnsBase, closeTo(1.05, 1e-6));
      expect(back.primaryKv, closeTo(241.5, 1e-6));
    });

    test('erro de base ONS vs TP', () {
      // 230 vs 245 → -6,12%
      final e = baseMismatchErrorPercent(vBaseOnsKv: 230, vNominalTpPrimaryKv: 245);
      expect(e, closeTo(-6.122, 0.01));
    });

    test('quando base ONS = nominal do TP, secundária = pu×Vsec', () {
      final r = onsPuToSecondary(
        puOns: 1.02, vBaseOnsKv: 138, vNominalTpPrimaryKv: 138, vTpSecondaryV: 115,
      );
      expect(r.secondaryVolts, closeTo(1.02 * 115, 1e-6));
      expect(r.puTpBase, closeTo(1.02, 1e-9));
    });
  });
}
