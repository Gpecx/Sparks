import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';

/// Placeholder de carregamento padrão do SPARK — uma caixa que pulsa
/// suavemente (opacidade 0.4 → 0.8), no lugar de um `CircularProgressIndicator`
/// cru. Usado para montar skeletons que imitam o formato do conteúdo real,
/// dando percepção de velocidade uniforme entre as telas.
///
/// Uso:
/// ```dart
/// const SparkSkeleton(width: double.infinity, height: 120);
/// const SparkSkeleton(height: 14, width: 80, radius: AppRadius.sm);
/// const SparkSkeleton(height: 40, circle: true); // avatar
/// ```
class SparkSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  final bool circle;
  final EdgeInsetsGeometry? margin;

  const SparkSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.lg,
    this.circle = false,
    this.margin,
  });

  @override
  State<SparkSkeleton> createState() => _SparkSkeletonState();
}

class _SparkSkeletonState extends State<SparkSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.8).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: AppColors.cardBorder.withValues(alpha: 0.5),
          borderRadius:
              widget.circle ? null : BorderRadius.circular(widget.radius),
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}
