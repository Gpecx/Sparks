import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/spda_risk.dart';

void main() {
  group('SPDA — área de captação', () {
    test('estrutura 20×10×5 m', () {
      // Ad = 20·10 + 2·15·(30) + π·225 = 200 + 900 + 706,86 = 1806,86
      final ad = collectionArea(length: 20, width: 10, height: 5);
      expect(ad, closeTo(1806.86, 0.5));
    });

    test('cresce com a altura (3H domina)', () {
      final baixa = collectionArea(length: 10, width: 10, height: 3);
      final alta = collectionArea(length: 10, width: 10, height: 30);
      expect(alta, greaterThan(baixa * 10));
    });
  });

  group('SPDA — fator de localização Cd', () {
    test('valores da tabela A.1', () {
      expect(cdFactor(StructureLocation.surrounded), 0.25);
      expect(cdFactor(StructureLocation.near), 0.5);
      expect(cdFactor(StructureLocation.isolated), 1.0);
      expect(cdFactor(StructureLocation.isolatedHill), 2.0);
    });
  });

  group('SPDA — nível por eficiência', () {
    test('mapeamento de E para nível', () {
      expect(levelForEfficiency(0.99), 'I');
      expect(levelForEfficiency(0.96), 'II');
      expect(levelForEfficiency(0.92), 'III');
      expect(levelForEfficiency(0.85), 'IV');
      expect(levelForEfficiency(0.5), 'IV+');
      expect(levelForEfficiency(0), isNull);
    });
  });

  group('SPDA — triagem de risco', () {
    test('estrutura pequena e isolada com Ng baixo → SPDA dispensável', () {
      final r = spdaRiskScreening(
        length: 10, width: 8, height: 4,
        ngDensity: 1, // muito baixo
        location: StructureLocation.surrounded,
      );
      expect(r.spdaLikelyNeeded, isFalse);
      expect(r.suggestedLevel, isNull);
      expect(r.requiredEfficiency, 0);
    });

    test('estrutura grande/alta com Ng alto → SPDA necessário, nível definido', () {
      final r = spdaRiskScreening(
        length: 60, width: 40, height: 30,
        ngDensity: 8, // típico de regiões com muita incidência
        location: StructureLocation.isolated,
      );
      expect(r.spdaLikelyNeeded, isTrue);
      expect(r.requiredEfficiency, greaterThan(0));
      expect(r.suggestedLevel, isNotNull);
      // Nd deve superar a frequência admissível Nc
      expect(r.dangerousEvents, greaterThan(r.admissibleFrequency));
    });

    test('Nd cresce com Cd (localização mais exposta)', () {
      SpdaRiskResult run(StructureLocation loc) => spdaRiskScreening(
            length: 30, width: 20, height: 15, ngDensity: 5, location: loc,
          );
      final cercada = run(StructureLocation.surrounded);
      final morro = run(StructureLocation.isolatedHill);
      // morro (Cd=2) tem 8× o Nd da cercada (Cd=0,25)
      expect(morro.dangerousEvents,
          closeTo(cercada.dangerousEvents * 8, cercada.dangerousEvents * 0.01));
    });
  });
}
