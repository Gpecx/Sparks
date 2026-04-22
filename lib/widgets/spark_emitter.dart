import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:spark_app/theme/app_theme.dart';

class SparkEmitter extends StatefulWidget {
  final bool trigger; // Quando mudar para true, a animação roda!
  
  const SparkEmitter({super.key, required this.trigger});

  @override
  State<SparkEmitter> createState() => _SparkEmitterState();
}

class _SparkEmitterState extends State<SparkEmitter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void didUpdateWidget(SparkEmitter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o trigger mudou para true, nós geramos novas partículas e disparamos a animação
    if (widget.trigger && !oldWidget.trigger) {
      _particles.clear();
      for (int i = 0; i < 30; i++) {
        _particles.add(_Particle(
          angle: _random.nextDouble() * 2 * math.pi,
          speed: 2.0 + _random.nextDouble() * 5.0,
          size: 2.0 + _random.nextDouble() * 4.0,
        ));
      }
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating && _controller.isDismissed) return const SizedBox.shrink();
    
    return IgnorePointer( // Para não atrapalhar os cliques do usuário
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ParticlePainter(_particles, _controller.value),
            child: Container(),
          );
        }
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  _Particle({required this.angle, required this.speed, required this.size});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = AppColors.primary.withOpacity(1.0 - progress);

    for (var p in particles) {
      // Calcula o quão longe a partícula foi (baseado no progresso do tempo e velocidade dela)
      final distance = progress * 100 * p.speed;
      final x = center.dx + math.cos(p.angle) * distance;
      final y = center.dy + math.sin(p.angle) * distance;
      
      canvas.drawCircle(Offset(x, y), p.size * (1.0 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}