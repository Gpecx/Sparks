import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/services/device_service.dart';
import 'package:spark_app/theme/app_theme.dart';

/// Exibe o popup de verificação OTP e retorna `true` se o código for validado.
/// Chame com:
/// ```dart
/// final ok = await showEmailVerificationDialog(context, email: email);
/// ```
Future<bool> showEmailVerificationDialog(
  BuildContext context, {
  required String email,
  required String uid,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EmailVerificationDialog(email: email, uid: uid),
  ).then((v) => v ?? false);
}

class _EmailVerificationDialog extends StatefulWidget {
  final String email;
  final String uid;

  const _EmailVerificationDialog({required this.email, required this.uid});

  @override
  State<_EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  // Cooldown do botão "Reenviar"
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _startCooldown();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      await fn.httpsCallable('sendEmailVerificationCode').call({'email': widget.email});
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Novo código enviado! Verifique seu e-mail.'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _extractMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Digite os 6 dígitos do código.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final deviceService = DeviceService();
      final deviceId = await deviceService.getDeviceId();
      final deviceName = await deviceService.getDeviceName();

      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('verifyEmailCode').call({
        'code': code,
        'deviceId': deviceId,
        'deviceName': deviceName,
      });

      final data = result.data as Map<dynamic, dynamic>;
      final verified = data['verified'] == true;
      final error = data['error'] as String?;

      if (verified) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _codeController.clear();
        _shakeController.forward(from: 0);
        setState(() => _errorMessage = error ?? 'Código incorreto. Tente novamente.');
      }
    } catch (e) {
      _shakeController.forward(from: 0);
      setState(() => _errorMessage = _extractMessage(e));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  String _extractMessage(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? 'Erro ao verificar o código.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _cooldownTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final offset = _shakeController.isAnimating
              ? 8 * (0.5 - (_shakeAnimation.value - 0.5).abs())
              : 0.0;
          return Transform.translate(
            offset: Offset(offset * 3, 0),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 20),

              // Título
              const Text(
                'Verificação de Identidade',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Subtítulo
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
                  children: [
                    const TextSpan(text: 'Enviamos um código de 6 dígitos para\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Campo OTP
              TextField(
                controller: _codeController,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 28,
                    letterSpacing: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onChanged: (v) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                  if (v.length == 6) _verifyCode();
                },
              ),

              // Mensagem de erro
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // Botão VERIFICAR
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'VERIFICAR',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Reenviar
              _isResending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : TextButton(
                      onPressed: _resendCooldown > 0 ? null : _resendCode,
                      child: Text(
                        _resendCooldown > 0
                            ? 'Reenviar código em ${_resendCooldown}s'
                            : 'Reenviar código',
                        style: TextStyle(
                          color: _resendCooldown > 0
                              ? Colors.white.withValues(alpha: 0.3)
                              : AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
