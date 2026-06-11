import 'package:flutter_test/flutter_test.dart';
import 'package:spark_app/utils/instrument_transformers.dart';

void main() {
  group('RTC / RTP', () {
    test('relação 600/5 → 120', () {
      expect(transformRatio(600, 5), closeTo(120, 1e-9));
    });

    test('secundário a partir do primário', () {
      final r = transformRatio(600, 5);
      expect(secondaryFromPrimary(600, r), closeTo(5, 1e-9));
      expect(secondaryFromPrimary(480, r), closeTo(4, 1e-9));
    });

    test('primário a partir do secundário', () {
      final r = transformRatio(600, 5);
      expect(primaryFromSecondary(5, r), closeTo(600, 1e-9));
      expect(primaryFromSecondary(4, r), closeTo(480, 1e-9));
    });

    test('RTP 13800/115 → 120', () {
      expect(transformRatio(13800, 115), closeTo(120, 1e-9));
    });
  });
}
