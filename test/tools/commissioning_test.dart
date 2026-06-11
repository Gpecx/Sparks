import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/commissioning.dart';

void main() {
  group('Comissionamento', () {
    test('tolerância: 0,512 vs 0,500 (±5%) → +2,4% APROVADO', () {
      final r = toleranceCheck(measured: 0.512, expected: 0.500, tolerancePercent: 5);
      expect(r.errorPercent, closeTo(2.4, 1e-6));
      expect(r.pass, isTrue);
    });

    test('tolerância: erro acima do limite → REPROVADO', () {
      final r = toleranceCheck(measured: 0.560, expected: 0.500, tolerancePercent: 5);
      expect(r.errorPercent, closeTo(12.0, 1e-6));
      expect(r.pass, isFalse);
    });

    test('injeção secundária de corrente: 6000 A / RTC 120 → 50 A', () {
      expect(secondaryInjectionCurrent(faultPrimary: 6000, rtc: 120), closeTo(50, 1e-9));
    });

    test('injeção secundária de tensão: 13800 V / RTP 120 → 115 V', () {
      expect(secondaryInjectionVoltage(primaryVoltage: 13800, rtp: 120), closeTo(115, 1e-9));
    });
  });
}
