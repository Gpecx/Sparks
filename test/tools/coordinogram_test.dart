import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/idmt_curves.dart';
import 'package:spark_app/utils/coordinogram.dart';

void main() {
  final ni = idmtCurves.firstWhere((c) => c.id == 'iec_inversa');

  group('CoordRelay — tempo no ponto de falta', () {
    test('corrente abaixo do pickup não sensibiliza', () {
      const r = CoordRelay(label: 'R1', curve: _ni, pickupA: 100, td: 0.1);
      expect(r.timeAtCurrent(80), isNull);
      expect(r.timeAtCurrent(100), isNull); // exatamente no pickup
    });

    test('corrente acima do pickup produz tempo positivo', () {
      final r = CoordRelay(label: 'R1', curve: ni, pickupA: 100, td: 0.2);
      final t = r.timeAtCurrent(1000); // M = 10
      expect(t, isNotNull);
      expect(t!, greaterThan(0));
    });
  });

  group('checkCti', () {
    test('retaguarda mais lenta com margem suficiente → OK', () {
      final main = CoordRelay(label: 'jusante', curve: ni, pickupA: 100, td: 0.1);
      final backup = CoordRelay(label: 'montante', curve: ni, pickupA: 100, td: 0.5);
      final c = checkCti(
          main: main, backup: backup, faultCurrentA: 1000, requiredCti: 0.3);
      expect(c.mainTime, isNotNull);
      expect(c.backupTime, isNotNull);
      expect(c.margin!, greaterThan(0));
      // dial 0,5 vs 0,1 → margem grande
      expect(c.ok, isTrue);
    });

    test('dials iguais → margem zero → falha de coordenação', () {
      final main = CoordRelay(label: 'jusante', curve: ni, pickupA: 100, td: 0.2);
      final backup = CoordRelay(label: 'montante', curve: ni, pickupA: 100, td: 0.2);
      final c = checkCti(
          main: main, backup: backup, faultCurrentA: 1000, requiredCti: 0.3);
      expect(c.margin!, closeTo(0, 1e-9));
      expect(c.ok, isFalse);
    });
  });
}

// curva usada em contexto const
const _ni = IdmtCurve(
    id: 'iec_inversa', name: 'IEC - Normal Inversa', family: 'IEC Padrão', a: 0.14, p: 0.02);
