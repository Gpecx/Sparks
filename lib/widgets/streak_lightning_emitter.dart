import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:spark_app/theme/app_theme.dart';

class StreakLightningEmitter extends StatefulWidget {
  final bool trigger;
  final int streakCount;

  const StreakLightningEmitter({super.key, required this.trigger, required this.streakCount});

  @override
  State<StreakLightningEmitter> createState() => _StreakLightningEmitterState();
}

class _StreakLightningEmitterState extends State<StreakLightningEmitter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();
  final List<_LightningParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(StreakLightningEmitter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _particles.clear();
      
      int count = 0;
      if (widget.streakCount >= 10) {
        count = 50; // Epic streak: 50 faíscas/raios
      } else if (widget.streakCount >= 5) {
        count = 15; // Normal streak: 15 faíscas/raios
      }
      
      for (int i = 0; i < count; i++) {
        _particles.add(_LightningParticle(
          startX: _random.nextDouble(), // 0.0 to 1.0 (relative to screen width)
          speedY: 0.4 + _random.nextDouble() * 0.8, // Speed going up
          driftX: (_random.nextDouble() - 0.5) * 0.8, // Horizontal drift
          size: 20.0 + _random.nextDouble() * 60.0, // Size of the bolt
          rotation: (_random.nextDouble() - 0.5) * math.pi, // Initial rotation
          rotationSpeed: (_random.nextDouble() - 0.5) * math.pi * 3,
          isSpark: _random.nextDouble() > 0.4, // 60% chance of being a spark, 40% bolt
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

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final t = Curves.easeOutQuad.transform(_controller.value);

          return Stack(
            clipBehavior: Clip.none,
            children: _particles.map((p) {
              // Current positions (Bottom to Top)
              double dx = (p.startX * width) + (p.driftX * width * t);
              double dy = height - (p.speedY * height * t) + 100; // Start slightly below screen
              
              // Fade out towards the end
              double opacity = 1.0;
              if (_controller.value > 0.8) {
                opacity = (1.0 - _controller.value) / 0.2;
              }

              return Positioned(
                left: dx - (p.size / 2),
                top: dy - (p.size / 2),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: p.rotation + (p.rotationSpeed * _controller.value),
                    child: p.isSpark 
                      ? Container(
                          width: p.size * 0.2, 
                          height: p.size * 0.2, 
                          decoration: BoxDecoration(
                            color: AppColors.primary, 
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withValues(alpha: 0.6), blurRadius: 10)
                            ]
                          )
                        )
                      : Icon(
                          Icons.bolt,
                          color: AppColors.primary,
                          size: p.size,
                          shadows: [Shadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 15)],
                        ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _LightningParticle {
  final double startX;
  final double speedY;
  final double driftX;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final bool isSpark;

  _LightningParticle({
    required this.startX,
    required this.speedY,
    required this.driftX,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isSpark,
  });
}
