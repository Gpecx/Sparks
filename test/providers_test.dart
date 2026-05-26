import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';

// ─────────────────────────────────────────────────────────────────
//  TESTES UNITÁRIOS — Providers Riverpod
// ─────────────────────────────────────────────────────────────────

void main() {
  group('DevModeNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('estado inicial é false', () {
      expect(container.read(devModeProvider), false);
    });

    test('activate() muda estado para true em debug mode', () {
      // Em testes, kDebugMode é true
      container.read(devModeProvider.notifier).activate();
      expect(container.read(devModeProvider), true);
    });

    test('deactivate() volta para false', () {
      container.read(devModeProvider.notifier).activate();
      container.read(devModeProvider.notifier).deactivate();
      expect(container.read(devModeProvider), false);
    });

    test('toggle() alterna o estado', () {
      container.read(devModeProvider.notifier).toggle();
      expect(container.read(devModeProvider), true);

      container.read(devModeProvider.notifier).toggle();
      expect(container.read(devModeProvider), false);
    });

    test('múltiplas leituras retornam o mesmo estado', () {
      container.read(devModeProvider.notifier).activate();
      final a = container.read(devModeProvider);
      final b = container.read(devModeProvider);
      expect(a, b);
    });
  });

  // Os testes de widget do AsyncButton requerem o widget real;
  // veja test/main_shell_screen_test.dart para testes de widget integrados.
}

