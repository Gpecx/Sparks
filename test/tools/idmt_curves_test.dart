import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/idmt_curves.dart';

IdmtCurve byId(String id) => idmtCurves.firstWhere((c) => c.id == id);

void main() {
  group('IDMT — fórmula generalizada', () {
    test('IEC Normal Inversa, Td=1, M=2 → ~10,03 s', () {
      final t = byId('iec_inversa').timeForMultiple(2, 1);
      expect(t, closeTo(10.03, 0.02));
    });

    test('IEC Normal Inversa, Td=1, M=10 → ~2,97 s', () {
      final t = byId('iec_inversa').timeForMultiple(10, 1);
      expect(t, closeTo(2.97, 0.02));
    });

    test('IEC Muito Inversa, Td=0,5, M=5 → ~1,6875 s', () {
      // t = 13,5·0,5 / (5 − 1) = 6,75/4
      final t = byId('iec_muito_inversa').timeForMultiple(5, 0.5);
      expect(t, closeTo(1.6875, 1e-4));
    });

    test('IEC Extremamente Inversa, Td=1, M=10 → ~0,808 s', () {
      // t = 80 / (10^2 − 1) = 80/99
      final t = byId('iec_extre_inversa').timeForMultiple(10, 1);
      expect(t, closeTo(80 / 99, 1e-4));
    });

    test('timeForCurrent equivale a timeForMultiple', () {
      final c = byId('iec_inversa');
      final a = c.timeForCurrent(iTest: 600, iPickup: 300, td: 1);
      final b = c.timeForMultiple(2, 1);
      expect(a, closeTo(b, 1e-9));
    });
  });

  group('IDMT — correções normativas aplicadas', () {
    test('IEEE MI corrigida para A=0,0515', () {
      expect(byId('ieee_mi').a, closeTo(0.0515, 1e-9));
    });
    test('BS142 STI corrigida para A=0,05', () {
      expect(byId('bs142_sti').a, closeTo(0.05, 1e-9));
    });
    test('Tab II VI corrigida para P=2', () {
      expect(byId('tab2_vi').p, closeTo(2, 1e-9));
    });
  });

  group('IDMT — catálogo', () {
    test('possui 57 curvas e ids únicos', () {
      expect(idmtCurves.length, 57);
      final ids = idmtCurves.map((c) => c.id).toSet();
      expect(ids.length, idmtCurves.length);
    });

    test('famílias agrupadas sem duplicar', () {
      expect(idmtFamilies, contains('IEC Padrão'));
      expect(idmtFamilies, contains('Siemens'));
      expect(idmtFamilies.toSet().length, idmtFamilies.length);
    });
  });

  group('formatTripTime', () {
    test('formata segundos em hh:mm:ss.cc', () {
      expect(formatTripTime(2.97), '00:00:02.97');
      expect(formatTripTime(75.5), '00:01:15.50');
      expect(formatTripTime(3661.25), '01:01:01.25');
    });
    test('valores inválidos retornam travessão', () {
      expect(formatTripTime(double.infinity), '—');
      expect(formatTripTime(double.nan), '—');
    });
  });
}
