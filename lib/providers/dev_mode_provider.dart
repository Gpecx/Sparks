import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier que controla o Modo Desenvolvedor/ADM do SPARK.
///
/// ⚠️ SEGURANÇA: toda ação de ativação é bloqueada em produção via [kDebugMode].
/// Em release build, o estado nunca pode ser alterado para `true`.
class DevModeNotifier extends Notifier<bool> {
  @override
  bool build() => false; // Estado inicial: Modo Dev DESATIVADO

  /// Ativa o modo desenvolvedor. NOP em produção.
  void activate() {
    if (!kDebugMode) return;
    state = true;
  }

  /// Desativa o modo desenvolvedor (funciona em qualquer modo).
  void deactivate() => state = false;

  /// Alterna o modo. NOP em produção.
  void toggle() {
    if (!kDebugMode) return;
    state = !state;
  }
}

/// Provider global do Modo Desenvolvedor.
///
/// Consuma com `ref.watch(devModeProvider)` para ler o estado (bool).
/// Use `ref.read(devModeProvider.notifier).toggle()` para alterar.
final devModeProvider = NotifierProvider<DevModeNotifier, bool>(
  DevModeNotifier.new,
);
