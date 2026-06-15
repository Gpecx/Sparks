import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';

/// Feedback padronizado do SPARK (sucesso / erro / info).
///
/// Substitui os `ScaffoldMessenger.showSnackBar(SnackBar(...))` soltos pelas
/// telas, garantindo cor, ícone, formato flutuante e raio iguais em todo o app.
///
/// Uso:
/// ```dart
/// SparkSnack.success(context, 'Clã criado com sucesso!');
/// SparkSnack.error(context, e); // aceita String ou qualquer objeto/Exception
/// SparkSnack.info(context, 'Resultados copiados');
/// ```
class SparkSnack {
  const SparkSnack._();

  /// Ação concluída com sucesso (verde da marca).
  static void success(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      color: AppColors.primary,
    );
  }

  /// Algo deu errado (vermelho). Aceita `String`, `Exception` ou qualquer
  /// objeto — o prefixo `Exception: ` é removido automaticamente.
  static void error(BuildContext context, Object message) {
    HapticFeedback.mediumImpact();
    _show(
      context,
      message: message.toString().replaceAll('Exception: ', ''),
      icon: Icons.error_outline,
      color: AppColors.error,
    );
  }

  /// Recompensa / conquista (dourado) — streaks, bônus de XP, marcos.
  /// Usa haptic forte para reforçar a sensação de celebração.
  static void reward(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    _show(
      context,
      message: message,
      icon: Icons.bolt,
      color: AppColors.gold,
      accent: AppColors.background,
    );
  }

  /// Mensagem neutra/informativa (superfície escura).
  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline,
      color: AppColors.surface,
      accent: AppColors.textSecondary,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color color,
    Color? accent,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final iconColor = accent ?? Colors.white;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          elevation: 4,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
