import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:spark_app/theme/app_theme.dart';

class SparksBackground extends StatefulWidget {
  final Widget child;
  const SparksBackground({super.key, required this.child});

  @override
  State<SparksBackground> createState() => _SparksBackgroundState();
}

class _SparksBackgroundState extends State<SparksBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Animação longa e suave de 10 segundos para as faíscas flutuarem
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fundo com gradiente radial padrão do app
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [Color(0xFF091E35), Color(0xFF061629)],
            ),
          ),
        ),
        // Camada das faíscas animadas
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _MovingSparksPainter(_controller.value),
            ),
          ),
        ),
        // Conteúdo da página (Loja, Trilha, Perfil, etc) que vai por cima do fundo
        widget.child,
      ],
    );
  }
}

class _MovingSparksPainter extends CustomPainter {
  final double animationValue;
  _MovingSparksPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final sparkPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    // Movimento circular e vertical usando seno/cosseno para um efeito natural
    final t = animationValue * 2 * math.pi;
    
    final p1 = Offset(cx - 200 + math.sin(t) * 100, 200 + math.cos(t) * 40);
    final p2 = Offset(cx + 120 + math.cos(t) * 80, 450 + math.sin(t) * 40);
    final p3 = Offset(cx - 250 + math.cos(t) * 60, 700 + math.sin(t) * 40);
    final p4 = Offset(cx + 120 + math.cos(t) * 100, 900 + math.sin(t) * 40);
    final p5 = Offset(cx + 200 + math.cos(t) * 80, 100 + math.sin(t) * 40);

    canvas.drawCircle(p1, 20 + math.sin(t) * 5, sparkPaint);
    canvas.drawCircle(p2, 25 + math.cos(t) * 5, sparkPaint);
    canvas.drawCircle(p3, 22 + math.sin(t) * 5, sparkPaint);
    canvas.drawCircle(p4, 20 + math.sin(t) * 5, sparkPaint);
    canvas.drawCircle(p5, 20 + math.sin(t) * 5, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}