import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/per_unit.dart';

void main() {
  group('Valor por Unidade (PU)', () {
    test('Z base: S=100 MVA, V=138 kV → 190.44 Ω', () {
      final zBase = impedanceBase(sBaseMva: 100, vBaseKv: 138);
      expect(zBase, closeTo(190.44, 0.01));
    });

    test('Z real → pu: 50 Ω com base acima → 0.2625', () {
      final zPu = zPuFromReal(zRealOhm: 50, sBaseMva: 100, vBaseKv: 138);
      expect(zPu, closeTo(0.2625, 1e-3));
    });

    test('Z pu → real é inverso de Z real → pu', () {
      final zReal = zRealFromPu(zPu: 0.2625, sBaseMva: 100, vBaseKv: 138);
      expect(zReal, closeTo(50.0, 1e-2));
    });

    test('I base trifásico: S=100 MVA, V=138 kV → ~418.4 A', () {
      final iBase = currentBase(sBaseMva: 100, vBaseKv: 138);
      expect(iBase, closeTo(418.37, 0.1));
    });

    test('mudança de base: só S dobra → Z pu dobra', () {
      final zNew = changeImpedanceBase(
        zPuOld: 0.2,
        sBaseOldMva: 100,
        vBaseOldKv: 138,
        sBaseNewMva: 200,
        vBaseNewKv: 138,
      );
      expect(zNew, closeTo(0.4, 1e-6));
    });
  });
}
