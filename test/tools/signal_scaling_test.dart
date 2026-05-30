import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/signal_scaling.dart';

void main() {
  group('Escalonamento 4-20 mA', () {
    test('12 mA em 4-20 / 0-100 → 50', () {
      final v = signalToEng(signal: 12, sigMin: 4, sigMax: 20, engMin: 0, engMax: 100);
      expect(v, closeTo(50, 1e-9));
    });

    test('4 mA → mín, 20 mA → máx', () {
      expect(signalToEng(signal: 4, sigMin: 4, sigMax: 20, engMin: 0, engMax: 100), closeTo(0, 1e-9));
      expect(signalToEng(signal: 20, sigMin: 4, sigMax: 20, engMin: 0, engMax: 100), closeTo(100, 1e-9));
    });

    test('inverso: 50 → 12 mA', () {
      final s = engToSignal(eng: 50, sigMin: 4, sigMax: 20, engMin: 0, engMax: 100);
      expect(s, closeTo(12, 1e-9));
    });

    test('faixa de engenharia com offset (0-10 V → 0-200 bar)', () {
      expect(signalToEng(signal: 5, sigMin: 0, sigMax: 10, engMin: 0, engMax: 200), closeTo(100, 1e-9));
    });
  });
}
