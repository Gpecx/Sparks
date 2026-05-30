import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/power_triangle.dart';

void main() {
  group('Triângulo de potências', () {
    test('P=100kW, FP=0,8 → S=125, Q=75', () {
      final t = triangleFromActiveAndPf(100, 0.8);
      expect(t.apparentKva, closeTo(125, 1e-6));
      expect(t.reactiveKvar, closeTo(75, 1e-6));
      expect(t.powerFactor, closeTo(0.8, 1e-9));
    });

    test('P=100, Q=75 → S=125, FP=0,8', () {
      final t = triangleFromActiveAndReactive(100, 75);
      expect(t.apparentKva, closeTo(125, 1e-6));
      expect(t.powerFactor, closeTo(0.8, 1e-6));
    });

    test('S=125, FP=0,8 → P=100, Q=75', () {
      final t = triangleFromApparentAndPf(125, 0.8);
      expect(t.activeKw, closeTo(100, 1e-6));
      expect(t.reactiveKvar, closeTo(75, 1e-6));
    });
  });
}
