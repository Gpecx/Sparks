import 'dart:async';
import 'package:flutter/material.dart';

/// Serviço global para o sistema de "Sobrecarga" (Evento Temporário).
/// Funciona como Singleton reativo via ValueNotifier/Stream.
/// Não altera o AppTheme — funciona como um Decorator de estado.
class OverloadService extends ChangeNotifier {
  static final OverloadService _instance = OverloadService._internal();
  factory OverloadService() => _instance;
  OverloadService._internal();

  // ── Estado do Evento ──
  bool _isActive = false;
  DateTime? _endTime;
  Timer? _tickTimer;

  // ── Multiplicador ──
  static const double overloadMultiplier = 2.0;

  // ── Getters ──
  bool get isActive => _isActive;
  double get currentMultiplier => _isActive ? overloadMultiplier : 1.0;
  DateTime? get endTime => _endTime;

  /// Retorna o tempo restante formatado
  String get remainingTimeFormatted {
    if (_endTime == null || !_isActive) return '';
    final diff = _endTime!.difference(DateTime.now());
    if (diff.isNegative) return '00:00';
    final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = diff.inHours;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '$minutes:$seconds';
  }

  /// Ativa o evento de Sobrecarga por [duration].
  void activateOverload({Duration duration = const Duration(minutes: 30)}) {
    _isActive = true;
    _endTime = DateTime.now().add(duration);
    _startTick();
    notifyListeners();
  }

  /// Desativa manualmente.
  void deactivate() {
    _isActive = false;
    _endTime = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    notifyListeners();
  }

  /// Aplica o multiplicador em um valor de XP.
  int applyMultiplier(int baseXp) {
    return (baseXp * currentMultiplier).round();
  }

  void _startTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_endTime == null || DateTime.now().isAfter(_endTime!)) {
        deactivate();
        return;
      }
      notifyListeners(); // Atualiza contagem regressiva na UI
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}
