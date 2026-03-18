import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';

class PcbBackground extends StatelessWidget {
  final Widget child;

  const PcbBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fundo estático PCB desenhado apenas uma vez
        RepaintBoundary(
          child: CustomPaint(
            painter: PcbBackgroundPainter(),
          ),
        ),
        // O conteúdo da sua página ficará por cima do fundo
        child,
      ],
    );
  }
}

class PcbBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);

    // ── Grade de pontos (vias decorativas) ──────────────────────
    final dotPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;

    const gridStep = 28.0;
    for (double y = 0; y < size.height; y += gridStep) {
      for (double x = 0; x < size.width; x += gridStep) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    // ── Trilhas fantasmas de fundo ───────────────────────────────
    final ghostPaint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.square;

    for (int i = 0; i < 18; i++) {
      final isHorizontal = rng.nextBool();
      final alpha        = rng.nextDouble() * 0.055 + 0.015;
      final strokeW      = rng.nextDouble() * 1.2 + 0.8;
      final color        = i % 5 == 0
          ? AppColors.primary.withValues(alpha: alpha)
          : AppColors.textMuted.withValues(alpha: alpha * 0.6);

      ghostPaint..color = color..strokeWidth = strokeW;

      if (isHorizontal) {
        final y  = rng.nextDouble() * size.height;
        final x1 = rng.nextDouble() * size.width * 0.4;
        final x2 = (x1 + rng.nextDouble() * size.width * 0.5 + 40).clamp(0.0, size.width);
        canvas.drawLine(Offset(x1, y), Offset(x2, y), ghostPaint);
        canvas.drawCircle(Offset(x2, y), 2.0, Paint()..color = color..style = PaintingStyle.fill);
      } else {
        final x  = rng.nextDouble() * size.width;
        final y1 = rng.nextDouble() * size.height * 0.4;
        final y2 = (y1 + rng.nextDouble() * size.height * 0.35 + 30).clamp(0.0, size.height);
        canvas.drawLine(Offset(x, y1), Offset(x, y2), ghostPaint);
        final ym      = (y1 + y2) / 2;
        final stubLen = rng.nextDouble() * 20 + 10;
        final goRight = rng.nextBool();
        canvas.drawLine(Offset(x, ym), Offset(x + (goRight ? stubLen : -stubLen), ym), ghostPaint);
      }
    }

    // ── Chips decorativos (contorno de componentes) ──────────────
    final chipPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8;
    final chipPositions = [
      Offset(size.width * 0.08, size.height * 0.12),
      Offset(size.width * 0.82, size.height * 0.28),
      Offset(size.width * 0.10, size.height * 0.55),
      Offset(size.width * 0.78, size.height * 0.68),
      Offset(size.width * 0.15, size.height * 0.82),
    ];

    for (final pos in chipPositions) {
      final w = 28.0 + rng.nextDouble() * 16;
      final h = 14.0 + rng.nextDouble() * 10;
      chipPaint.color = AppColors.primary.withValues(alpha: 0.055);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: w, height: h), const Radius.circular(2)),
        chipPaint,
      );
      final pinPaint  = Paint()..strokeWidth = 1.0..style = PaintingStyle.stroke..color = AppColors.primary.withValues(alpha: 0.04);
      final pinCount  = (w / 7).round().clamp(2, 99);
      for (int p = 0; p < pinCount; p++) {
        final px = pos.dx - w / 2 + 4 + p * (w - 8) / (pinCount - 1);
        canvas.drawLine(Offset(px, pos.dy - h / 2 - 4), Offset(px, pos.dy - h / 2), pinPaint);
        canvas.drawLine(Offset(px, pos.dy + h / 2), Offset(px, pos.dy + h / 2 + 4), pinPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PcbBackgroundPainter old) => false;
}