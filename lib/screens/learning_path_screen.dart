import 'dart:math' as math;
import 'dart:ui'; // Adicionado para o efeito de vidro fosco (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/quiz_screen.dart';
import 'package:spark_app/controllers/energy_controller.dart';
import 'package:spark_app/widgets/sparks_background.dart';


class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({super.key});
  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final EnergyController _energyCtrl = EnergyController();

  // ── GlobalKey para acionar o glitch ──────────────────────────
  final _glitchKey = GlobalKey<_SparkGlitchWrapperState>();

  int _completedLessons = 0;

  // 22 nós: 1 introdução + 10 lições + 1 avaliação + 10 lições + 1 avaliação
  final List<Map<String, dynamic>> _nodes = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _energyCtrl.addListener(_onEnergyChanged);

    _nodes.add({'type': 'lesson', 'title': 'Introdução', 'subtitle': 'Introdução ao Módulo'});

    for (int i = 1; i <= 10; i++) {
      _nodes.add({'type': 'lesson', 'title': 'Lição $i', 'subtitle': 'Módulo Base'});
    }

    _nodes.add({'type': 'eval', 'title': 'AVALIAÇÃO 1', 'subtitle': 'Certificado Básico'});

    for (int i = 1; i <= 10; i++) {
      _nodes.add({'type': 'lesson', 'title': 'Lição ${i + 10}', 'subtitle': 'Módulo Avançado'});
    }

    _nodes.add({'type': 'eval', 'title': 'AVALIAÇÃO 2', 'subtitle': 'Certificado Final'});
  }

  void _onEnergyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _energyCtrl.removeListener(_onEnergyChanged);
    super.dispose();
  }

  bool _isNodeUnlocked(int index) => index <= _completedLessons;

  bool get _canAccessEvaluation1 => _completedLessons >= 11;
  bool get _canAccessEvaluation2 => _completedLessons >= 22;

  double get _progressValue => (_completedLessons > 22 ? 22 : _completedLessons) / 22;

  void _handleNodeTap(int index) async {
    if (!_isNodeUnlocked(index)) {
      _glitchKey.currentState?.triggerGlitch();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Módulo bloqueado! Conclua as etapas anteriores primeiro.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final node = _nodes[index];

    // Lógica da Avaliação
    if (node['type'] == 'eval') {
      if ((index == 11 && _canAccessEvaluation1) || (index == 22 && _canAccessEvaluation2)) {
        final passed = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuizScreen()),
        );
        if (passed == true && index == _completedLessons) {
          setState(() { _completedLessons++; });
        }
      } else {
        _glitchKey.currentState?.triggerGlitch();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete 100% das lições anteriores para a avaliação!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    // Lição normal (Quiz)
    else {
      final passed = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QuizScreen()),
      );
      if (passed == true && index == _completedLessons) {
        setState(() { _completedLessons++; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SparksBackground(
      child: _SparkGlitchWrapper(
        key: _glitchKey,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'SEGURANÇA BÁSICA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/store'),
                        child: _buildBadge(Icons.bolt, '250', AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/store'),
                        child: ListenableBuilder(
                          listenable: _energyCtrl,
                          builder: (_, _) => _buildBatteryBadge(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Card de Progresso (Efeito Raio-X / Glassmorphism) ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card.withValues(alpha: 0.45), 
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.menu_book, color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Módulo Atual', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Em Progresso · $_completedLessons de ${_nodes.length} etapas',
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(_progressValue * 100).round()}%',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progressValue,
                                backgroundColor: AppColors.inputBackground.withValues(alpha: 0.5),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Trilha de Nós ───────────────────────────────
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      final totalHeight = _nodeY(_nodes.length - 1, screenWidth) +
                          TrailLayout.kNodeSize / 2 +
                          TrailLayout.kTextHeight +
                          80.0;

                      return ScrollConfiguration(
                        behavior: _NoScrollbarBehavior(),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: screenWidth,
                            height: totalHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: _PCBBackgroundPainter(
                                        totalHeight: totalHeight,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(end: _completedLessons.toDouble()),
                                    duration: const Duration(milliseconds: 1500),
                                    curve: Curves.easeInOutCubic,
                                    builder: (context, animatedCompleted, child) {
                                      return AnimatedBuilder(
                                        animation: _controller,
                                        builder: (_, __) => CustomPaint(
                                          painter: _PCBPathPainter(
                                            nodePositions: List.generate(
                                              _nodes.length,
                                              (i) => Offset(
                                                _nodeX(i, screenWidth),
                                                _nodeY(i, screenWidth),
                                              ),
                                            ),
                                            completedCount: animatedCompleted, 
                                            animValue: _controller.value,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                ...List.generate(_nodes.length, (index) {
                                  final node = _nodes[index];
                                  final isCompleted = _completedLessons > index;
                                  final isCurrent   = _completedLessons == index;
                                  final isUnlocked  = _isNodeUnlocked(index);
                                  final isEval      = node['type'] == 'eval';

                                  final cx = _nodeX(index, screenWidth);
                                  final cy = _nodeY(index, screenWidth);

                                  const nodeWidgetW = 120.0;

                                  return Positioned(
                                    left: cx - nodeWidgetW / 2,
                                    top:  cy - TrailLayout.kNodeSize / 2,
                                    width: nodeWidgetW,
                                    child: isEval
                                        ? _buildEvalNode(
                                            label: node['title'],
                                            subtitle: node['subtitle'],
                                            isUnlocked: isUnlocked,
                                            isCompleted: isCompleted,
                                            onTap: () => _handleNodeTap(index),
                                          )
                                        : _buildLessonNode(
                                            label: node['title'],
                                            subtitle: node['subtitle'],
                                            isCompleted: isCompleted,
                                            isCurrent: isCurrent,
                                            isUnlocked: isUnlocked,
                                            onTap: () => _handleNodeTap(index),
                                          ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _nodeX(int index, double screenWidth) {
    final cx = screenWidth / 2;
    final mod = index % 4;
    switch (mod) {
      case 0: return cx;
      case 1: return cx + TrailLayout.kAmplitude;
      case 2: return cx;
      case 3: return cx - TrailLayout.kAmplitude;
      default: return cx;
    }
  }

  double _nodeY(int index, double screenWidth) {
    return TrailLayout.kTopPadding +
        index * TrailLayout.kSlotHeight +
        TrailLayout.kNodeSize / 2;
  }

  Widget _buildLessonNode({
    required String label,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    required bool isUnlocked,
    required VoidCallback onTap,
  }) {
    Color nodeColor;
    Color borderColor;
    Color iconColor;
    List<BoxShadow>? glow;
    IconData icon;

    if (isCompleted) {
      nodeColor = AppColors.primary;
      borderColor = AppColors.primary;
      iconColor = Colors.white;
      icon = Icons.check;
      glow = [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 4)];
    } else if (isCurrent) {
      nodeColor = AppColors.card;
      borderColor = AppColors.primary;
      iconColor = Colors.white;
      icon = Icons.play_arrow;
      glow = [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 18, spreadRadius: 4)];
    } else {
      nodeColor = AppColors.card;
      borderColor = AppColors.textMuted.withValues(alpha: 0.2);
      iconColor = AppColors.textMuted;
      icon = Icons.lock;
      glow = null;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: glow,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              if (isCurrent)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.star, color: Colors.white, size: 13),
                  ),
                ),
              if (!isUnlocked && !isCompleted)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
                    child: const Icon(Icons.lock, color: AppColors.textMuted, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isCurrent
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: isUnlocked ? 1 : 0.35),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvalNode({
    required String label,
    required String subtitle,
    required bool isUnlocked,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    final color = isCompleted
        ? AppColors.primary
        : isUnlocked
            ? AppColors.gold
            : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : isUnlocked
                      ? AppColors.gold.withValues(alpha: 0.2)
                      : AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted
                    ? AppColors.primary
                    : isUnlocked
                        ? AppColors.gold
                        : AppColors.textMuted.withValues(alpha: 0.2),
                width: 2.5,
              ),
              boxShadow: (isUnlocked || isCompleted)
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 18, spreadRadius: 4)]
                  : null,
            ),
            child: Icon(
              isCompleted
                  ? Icons.check
                  : isUnlocked
                      ? Icons.emoji_events
                      : Icons.lock,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isCompleted
                  ? AppColors.primary
                  : isUnlocked
                      ? AppColors.gold
                      : Colors.white.withValues(alpha: 0.35),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            isCompleted
                ? 'Concluída ✓'
                : isUnlocked
                    ? 'Disponível!'
                    : 'Complete 100% antes!',
            style: TextStyle(
              color: (isCompleted || isUnlocked)
                  ? color.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBatteryBadge() {
    final hasEnergy = _energyCtrl.hasEnergy;
    final color = hasEnergy ? AppColors.gold : Colors.redAccent;
    IconData batteryIcon;
    final ratio = _energyCtrl.energy / EnergyController.maxEnergy;

    if (_energyCtrl.isPremiumUser) {
      batteryIcon = Icons.battery_charging_full;
    } else if (ratio >= 0.7) {
      batteryIcon = Icons.battery_full;
    } else if (ratio >= 0.4) {
      batteryIcon = Icons.battery_4_bar;
    } else if (ratio >= 0.2) {
      batteryIcon = Icons.battery_2_bar;
    } else {
      batteryIcon = Icons.battery_alert;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(batteryIcon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            _energyCtrl.energyDisplay,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          if (_energyCtrl.isRecharging) ...[
            const SizedBox(width: 6),
            Text(
              _energyCtrl.regenTimeRemaining,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class TrailLayout {
  static const double kNodeSize   = 40.0;
  static const double kTextHeight = 38.0;
  static const double kGapBetween = 100.0;
  static const double kSlotHeight = kNodeSize + kTextHeight + kGapBetween;
  static const double kTopPadding = 56.0;
  static const double kAmplitude  = 100.0;
}

class _NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _PCBBackgroundPainter extends CustomPainter {
  final double totalHeight;
  const _PCBBackgroundPainter({required this.totalHeight});

  void _drawBackground(Canvas canvas, Size size) {
    final rng = math.Random(42);

    final dotPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;

    const gridStep = 28.0;
    for (double y = 0; y < size.height; y += gridStep) {
      for (double x = 0; x < size.width; x += gridStep) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

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
  void paint(Canvas canvas, Size size) => _drawBackground(canvas, size);

  @override
  bool shouldRepaint(covariant _PCBBackgroundPainter old) => false;
}

class _PCBPathPainter extends CustomPainter {
  final List<Offset> nodePositions;
  final double completedCount;
  final double animValue;

  const _PCBPathPainter({
    required this.nodePositions,
    required this.completedCount,
    required this.animValue,
  });

  static const double _bevelRadius  = 12.0;
  static const double _pulseLen     = 80.0;
  static const double _trackWidth   = 4.0;
  static const double _glowBlur     = 14.0;
  static const double _pulseBlur    = 8.0;

  Path _buildPCBPath(Offset a, Offset b) {
    final path = Path();
    final sx = a.dx; final sy = a.dy;
    final ex = b.dx; final ey = b.dy;

    if ((ex - sx).abs() < 0.5) {
      path.moveTo(sx, sy);
      path.lineTo(ex, ey);
      return path;
    }

    final dx      = ex - sx;
    final diagLen = dx.abs();
    const stub = 18.0;
    final stubEndY = sy + stub;
    final wy = stubEndY + diagLen;
    final r  = _bevelRadius;

    final pre1X = sx;
    final pre1Y = stubEndY - r;
    final preBevelRatio = (r / diagLen).clamp(0.0, 0.45);
    final pre2X = sx + dx * (1.0 - preBevelRatio);
    final pre2Y = stubEndY + diagLen * (1.0 - preBevelRatio);
    final post2Y = wy + r;

    path.moveTo(sx, sy);
    path.lineTo(pre1X, pre1Y);
    path.quadraticBezierTo(sx, stubEndY, sx + dx * preBevelRatio, stubEndY + diagLen * preBevelRatio);
    path.lineTo(pre2X, pre2Y);
    path.quadraticBezierTo(ex, wy, ex, post2Y);
    path.lineTo(ex, ey);
    return path;
  }

  Path _buildShadowPath(Offset a, Offset b) {
    const off = 6.0;
    final dx = (b.dx - a.dx);
    final side = dx >= 0 ? off : -off;
    return _buildPCBPath(Offset(a.dx + side, a.dy), Offset(b.dx + side, b.dy));
  }

  void _drawVia(Canvas canvas, Offset center, bool completed) {
    final outerR = 5.5;
    final innerR = 2.5;
    final ringColor = completed ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.25);

    if (completed) {
      canvas.drawCircle(
        center,
        outerR + 3,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawCircle(center, outerR, Paint()..color = ringColor..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(center, innerR, Paint()..color = ringColor.withValues(alpha: completed ? 0.7 : 0.15));
  }

  double _pathLength(Path path) {
    double total = 0;
    for (final m in path.computeMetrics()) total += m.length;
    return total;
  }

  Path _extractPulse(Path path, double start, double end) {
    final result = Path();
    for (final m in path.computeMetrics()) {
      final len = m.length;
      final s = start.clamp(0.0, len);
      final e = end.clamp(0.0, len);
      if (e > s) result.addPath(m.extractPath(s, e), Offset.zero);
    }
    return result;
  }

  void _drawGlowingPath(Canvas canvas, Path path) {
    canvas.drawPath(path, Paint()..color = AppColors.primary.withValues(alpha: 0.22)..strokeWidth = _trackWidth + 12.0..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowBlur));
    canvas.drawPath(path, Paint()..color = AppColors.primary..strokeWidth = _trackWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.3)..strokeWidth = 1.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (nodePositions.length < 2) return;

    for (int i = 0; i < nodePositions.length - 1; i++) {
      final a = nodePositions[i];
      final b = nodePositions[i + 1];
      final fullPath = _buildPCBPath(a, b);
      final totalLen = _pathLength(fullPath);

      canvas.drawPath(fullPath, Paint()..color = AppColors.textMuted.withValues(alpha: 0.14)..strokeWidth = _trackWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
      canvas.drawPath(_buildShadowPath(a, b), Paint()..color = AppColors.textMuted.withValues(alpha: 0.06)..strokeWidth = 1.5..style = PaintingStyle.stroke);

      if (i < completedCount.floor()) {
        _drawGlowingPath(canvas, fullPath);
        _drawVia(canvas, a, true);
        
        final phase = (i * 0.18) % 1.0;
        final shifted = (animValue + phase) % 1.0;
        final headPos = shifted * (totalLen + _pulseLen) - _pulseLen;
        final pStart = headPos.clamp(0.0, totalLen);
        final pEnd = (headPos + _pulseLen).clamp(0.0, totalLen);
        if (pEnd > pStart) {
          final pulsePath = _extractPulse(fullPath, pStart, pEnd);
          canvas.drawPath(pulsePath, Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = _trackWidth + 6.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, _pulseBlur));
          canvas.drawPath(pulsePath, Paint()..color = Colors.white.withValues(alpha: 0.98)..strokeWidth = 2.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
        }
      } else if (i == completedCount.floor() && completedCount > i) {
        final progressFraction = completedCount - i;
        final animatedPath = _extractPulse(fullPath, 0.0, totalLen * progressFraction);
        _drawGlowingPath(canvas, animatedPath);
        _drawVia(canvas, a, true);
      } else {
        _drawVia(canvas, a, false);
      }
    }
    
    if (nodePositions.isNotEmpty) {
      _drawVia(canvas, nodePositions.last, completedCount >= nodePositions.length - 1);
    }
  }

  @override
  bool shouldRepaint(covariant _PCBPathPainter old) => true; 
}

class _SparkGlitchWrapper extends StatefulWidget {
  final Widget child;
  const _SparkGlitchWrapper({super.key, required this.child});

  @override
  State<_SparkGlitchWrapper> createState() => _SparkGlitchWrapperState();
}

class _SparkGlitchWrapperState extends State<_SparkGlitchWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> triggerGlitch() async {
    if (_ctrl.isAnimating) _ctrl.reset();
    await HapticFeedback.heavyImpact();
    _ctrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t        = _anim.value;
        final envelope = math.sin(t * math.pi);
        final shift    = 6.0 * envelope;
        final shake    = 5.0 * envelope * math.sin(t * math.pi * 14);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (t > 0)
              Transform.translate(
                offset: Offset(shift, shift * 0.5),
                child: Opacity(
                  opacity: (envelope * 0.7).clamp(0.0, 1.0),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      1, 0, 0, 0, 0,
                      0, 0, 0, 0, 0,
                      0, 0, 0, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: RepaintBoundary(child: child),
                  ),
                ),
              ),
            if (t > 0)
              Transform.translate(
                offset: Offset(-shift, -shift * 0.5),
                child: Opacity(
                  opacity: (envelope * 0.7).clamp(0.0, 1.0),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0, 0, 0, 0, 0,
                      0, 0, 0, 0, 0,
                      0, 0, 1, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: RepaintBoundary(child: child),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(shake, 0),
              child: RepaintBoundary(child: child),
            ),
            if (t > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _VhsNoisePainter(progress: t),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _VhsNoisePainter extends CustomPainter {
  final double progress;
  const _VhsNoisePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final envelope = math.sin(progress * math.pi);
    final rng = math.Random((progress * 1000).toInt());
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 12; i++) {
      final y         = rng.nextDouble() * size.height;
      final lineWidth = rng.nextDouble() * size.width * 0.7 + size.width * 0.1;
      final startX    = rng.nextDouble() * (size.width - lineWidth);
      final alpha     = rng.nextDouble() * 0.55 * envelope;
      final thickness = rng.nextDouble() * 2.0 + 0.5;
      final isGreen   = rng.nextBool();

      paint
        ..color = (isGreen ? AppColors.primary : Colors.white).withValues(alpha: alpha)
        ..strokeWidth = thickness;

      canvas.drawLine(Offset(startX, y), Offset(startX + lineWidth, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VhsNoisePainter old) => old.progress != progress;
}