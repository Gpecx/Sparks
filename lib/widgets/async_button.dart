import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ASYNC BUTTON — Botão reutilizável com estado loading/erro/sucesso
//  Reduz acoplamento: qualquer tela usa este widget em vez de duplicar lógica.
// ─────────────────────────────────────────────────────────────────

/// Estado interno do botão assíncrono.
enum _AsyncButtonState { idle, loading, success, error }

/// Botão que gerencia seu próprio estado de loading e exibe feedback visual.
///
/// Uso:
/// ```dart
/// AsyncButton(
///   label: 'Salvar',
///   onPressed: () async { await service.save(); },
/// )
/// ```
class AsyncButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;
  final IconData? icon;
  final Color? color;
  final double? width;
  final String? semanticLabel;
  final bool outlined;

  const AsyncButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.width,
    this.semanticLabel,
    this.outlined = false,
  });

  @override
  State<AsyncButton> createState() => _AsyncButtonState2();
}

class _AsyncButtonState2 extends State<AsyncButton>
    with SingleTickerProviderStateMixin {
  _AsyncButtonState _state = _AsyncButtonState.idle;
  String? _errorMsg;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _handlePress() async {
    if (_state == _AsyncButtonState.loading) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _state = _AsyncButtonState.loading;
      _errorMsg = null;
    });
    try {
      await widget.onPressed();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _state = _AsyncButtonState.success);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _state = _AsyncButtonState.idle);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _state = _AsyncButtonState.error;
        _errorMsg = e.toString();
      });
      _shakeController.forward(from: 0);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _state = _AsyncButtonState.idle);
    }
  }

  Color get _effectiveColor => widget.color ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final isLoading = _state == _AsyncButtonState.loading;
    final isError = _state == _AsyncButtonState.error;
    final isSuccess = _state == _AsyncButtonState.success;

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.outlined ? _effectiveColor : Colors.white,
          ),
        ),
      );
    } else if (isError) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFFF6B6B)),
          const SizedBox(width: 6),
          const Text('Erro', style: TextStyle(color: Color(0xFFFF6B6B))),
        ],
      );
    } else if (isSuccess) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 16,
              color: widget.outlined ? _effectiveColor : Colors.white),
          const SizedBox(width: 6),
          Text('Sucesso!',
              style: TextStyle(
                  color: widget.outlined ? _effectiveColor : Colors.white)),
        ],
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(widget.label),
        ],
      );
    }

    final bgColor = isError
        ? const Color(0xFF3D1515)
        : isSuccess
            ? const Color(0xFF153D15)
            : _effectiveColor;

    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      enabled: !isLoading,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, innerChild) {
          return Transform.translate(
            offset: Offset(
              isError ? (_shakeController.value < 0.5 ? _shakeAnimation.value : -_shakeAnimation.value) : 0,
              0,
            ),
            child: innerChild,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.width,
              child: widget.outlined
                  ? OutlinedButton(
                      onPressed: isLoading ? null : _handlePress,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isError
                              ? const Color(0xFFFF6B6B)
                              : isSuccess
                                  ? const Color(0xFF4CAF50)
                                  : _effectiveColor,
                        ),
                        foregroundColor: isError
                            ? const Color(0xFFFF6B6B)
                            : isSuccess
                                ? const Color(0xFF4CAF50)
                                : _effectiveColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: child,
                    )
                  : ElevatedButton(
                      onPressed: isLoading ? null : _handlePress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bgColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: child,
                    ),
            ),
            // Mensagem de erro inline
            if (isError && _errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _errorMsg!.length > 60
                      ? '${_errorMsg!.substring(0, 60)}…'
                      : _errorMsg!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
