import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/coordination.dart';
import 'package:spark_app/utils/idmt_curves.dart';

void main() {
  group('Coordenação / seletividade', () {
    test('CTI real ≥ mínimo ⇒ coordenado', () {
      final r = coordinationCheck(timeMain: 0.2, timeBackup: 0.55, requiredCti: 0.3);
      expect(r.interval, closeTo(0.35, 1e-9));
      expect(r.coordinated, isTrue);
    });

    test('CTI insuficiente ⇒ não coordenado', () {
      final r = coordinationCheck(timeMain: 0.4, timeBackup: 0.55, requiredCti: 0.3);
      expect(r.interval, closeTo(0.15, 1e-9));
      expect(r.coordinated, isFalse);
    });

    test('integração com curvas IDMT (mesma curva, dial maior atrasa)', () {
      final curve = idmtCurves.firstWhere((c) => c.id == 'iec_inversa');
      final tMain = curve.timeForMultiple(1000 / 100, 0.1); // M=10, Td=0,1
      final tBackup = curve.timeForMultiple(1000 / 100, 0.3); // M=10, Td=0,3
      expect(tBackup, greaterThan(tMain));
      final r = coordinationCheck(
          timeMain: tMain, timeBackup: tBackup, requiredCti: 0.1);
      expect(r.coordinated, r.interval >= 0.1);
    });
  });
}
