import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:spark_app/theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Logo EXS Solutions ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícone molecular estilo EXS
                  _ExsMoleculeIcon(size: 38),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'SPARK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'by EXS Solutions',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Hero Illustration ───────────────────────────────
            Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow radial fundo
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.12),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                  // Anel externo
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.greenDark.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  // Anel interno
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Ícone central molecular
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.hub_outlined,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                  // Ícones orbitais animados
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          _OrbitIcon(Icons.bolt, _controller, 100, 70, 0.0),
                          _OrbitIcon(Icons.electrical_services, _controller, 110, 75, math.pi / 2),
                          _OrbitIcon(Icons.bar_chart, _controller, 105, 65, math.pi),
                          _OrbitIcon(Icons.shield_outlined, _controller, 95, 80, 3 * math.pi / 2),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Texto ───────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // Linha decorativa verde estilo EXS
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'O Futuro do\nSetor Elétrico\nComeça Aqui',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Domine normas técnicas com\ntecnologia validada em campo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const Spacer(),
                    // Botão principal EXS
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: const Text(
                          'FAZER LOGIN',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Criar conta — estilo tag EXS (outline verde)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, '/register'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'CRIAR NOVA CONTA',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ícone molecular estilo EXS Solutions
class _ExsMoleculeIcon extends StatelessWidget {
  final double size;
  const _ExsMoleculeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MoleculePainter()),
    );
  }
}

class _MoleculePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintGreen = Paint()
      ..color = const Color(0xFF00C402)
      ..style = PaintingStyle.fill;
    final paintDark = Paint()
      ..color = const Color(0xFF1D5F31)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.12;

    // Nós externos
    final positions = [
      Offset(cx, cy - size.height * 0.35),
      Offset(cx + size.width * 0.3, cy - size.height * 0.15),
      Offset(cx + size.width * 0.3, cy + size.height * 0.15),
      Offset(cx, cy + size.height * 0.35),
      Offset(cx - size.width * 0.3, cy + size.height * 0.15),
      Offset(cx - size.width * 0.3, cy - size.height * 0.15),
    ];

    final linePaint = Paint()
      ..color = const Color(0xFF00C402).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Linhas conectoras
    for (final pos in positions) {
      canvas.drawLine(Offset(cx, cy), pos, linePaint);
    }
    for (int i = 0; i < positions.length; i++) {
      canvas.drawLine(positions[i], positions[(i + 1) % positions.length], linePaint);
    }

    // Nós externos
    for (int i = 0; i < positions.length; i++) {
      canvas.drawCircle(positions[i], r * 0.7, i.isEven ? paintGreen : paintDark);
    }

    // Nó central
    canvas.drawCircle(Offset(cx, cy), r * 1.2, paintDark);
    canvas.drawCircle(Offset(cx, cy), r * 0.8, paintGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Ícone orbital animado
class _OrbitIcon extends StatelessWidget {
  final IconData icon;
  final AnimationController controller;
  final double rx, ry, offset;

  const _OrbitIcon(this.icon, this.controller, this.rx, this.ry, this.offset);

  @override
  Widget build(BuildContext context) {
    final angle = controller.value * 2 * math.pi + offset;
    return Transform.translate(
      offset: Offset(math.cos(angle) * rx, math.sin(angle) * ry),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Icon(icon, color: AppColors.primary, size: 16),
      ),
    );
  }
}
