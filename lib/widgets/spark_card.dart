import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';

/// Card padrão do SPARK.
///
/// Centraliza a decoração que se repetia em dezenas de telas
/// (`AppColors.card` + borda `cardBorder` + raio + padding), garantindo
/// que todos os cards tenham fundo, borda e cantos idênticos.
///
/// Uso:
/// ```dart
/// SparkCard(child: Text('Conteúdo'));
/// SparkCard(highlighted: true, onTap: () {...}, child: ...); // borda verde
/// ```
class SparkCard extends StatelessWidget {
  const SparkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.onTap,
    this.highlighted = false,
    this.borderColor,
    this.radius = AppRadius.md,
    this.width,
    this.color,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Largura fixa opcional (ex.: `double.infinity` para ocupar a linha toda).
  final double? width;

  /// Cor de fundo customizada — para estados tingidos (ativo/selecionado/
  /// desbloqueado). Por padrão usa `AppColors.card`.
  final Color? color;

  /// Sombra opcional — para cards elevados ou com brilho de destaque
  /// (ex.: glow dourado em itens concluídos).
  final List<BoxShadow>? boxShadow;

  /// Borda verde da marca, para o card "ativo"/em destaque.
  final bool highlighted;

  /// Cor de borda customizada (sobrepõe [highlighted]).
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ??
        (highlighted
            ? AppColors.primary.withValues(alpha: 0.4)
            : AppColors.cardBorder.withValues(alpha: 0.4));

    final decoration = BoxDecoration(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: effectiveBorder),
      boxShadow: boxShadow,
    );

    final content = Container(
      width: width,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) {
      return Container(margin: margin, child: content);
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      ),
    );
  }
}
