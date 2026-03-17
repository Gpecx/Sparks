import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:spark_app/theme/app_theme.dart';

// Logo animado no estilo EXS Solutions — ícone molecular/hub com glow verde
class AnimatedSparkLogo extends StatefulWidget {
  const AnimatedSparkLogo({super.key});

  @override
  State<AnimatedSparkLogo> createState() => _AnimatedSparkLogoState();
}

class _AnimatedSparkLogoState extends State<AnimatedSparkLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        final translateY = math.sin(t) * 6.0;
        final rotateX = math.sin(t) * 0.18;
        final rotateY = math.cos(t) * 0.18;
        final glowIntensity = (math.sin(t * 2) + 1) / 2;
        final blur = 20.0 + (glowIntensity * 20.0);
        final spread = 3.0 + (glowIntensity * 8.0);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..translate(0.0, translateY, 0.0)
            ..rotateX(rotateX)
            ..rotateY(rotateY),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              // Fundo azul escuro EXS com borda verde
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary
                      .withValues(alpha: 0.15 + (glowIntensity * 0.4)),
                  blurRadius: blur,
                  spreadRadius: spread,
                ),
              ],
            ),
            child: const Icon(
              Icons.hub_outlined,
              color: AppColors.primary,
              size: 48,
            ),
          ),
        );
      },
    );
  }
}
