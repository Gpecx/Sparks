import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  /// Ativado pela RegisterScreen antes de criar o usuário.
  /// Impede o auto-login de destruir a tela de cadastro antes do popup.
  static bool skipAutoLogin = false;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _sparkController; // pulso suave do brilho verde
  late AnimationController _floatController; // flutuar (idle)
  late AnimationController _introController; // power-up na entrada
  late AnimationController _blinkController; // piscar os olhos
  late AnimationController _talkController; // boca falando
  late AnimationController _ringController; // anéis girando
  late AnimationController _particleController; // partículas subindo
  late AnimationController _tapController; // "pulinho" ao tocar
  late Animation<double> _floatCurve;
  late Animation<double> _introFade;
  late Animation<double> _introScale;

  // Parallax: posição do ponteiro normalizada (-1..1) em relação ao centro.
  final ValueNotifier<Offset> _pointer = ValueNotifier(Offset.zero);

  @override
  void initState() {
    super.initState();
    // Pulso lento do brilho verde ao redor do mascote (mantém ele "vivo")
    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    // Flutuar suave (sobe/desce)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _floatCurve =
        CurvedAnimation(parent: _floatController, curve: Curves.easeInOut);
    // Power-up de entrada (dispara uma vez)
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _introFade =
        CurvedAnimation(parent: _introController, curve: Curves.easeOut);
    _introScale =
        CurvedAnimation(parent: _introController, curve: Curves.easeOutBack);
    // Pisca a cada ~3,6s (os olhos fecham por um instante perto do fim)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    // Boca falando em rajadas curtas com pausas
    _talkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    // Anéis decorativos girando devagar
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    // Partículas de energia subindo
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    // "Pulinho" disparado ao tocar no mascote
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // ── Auto-Login ──────────────────────────────────────────
    // Se a sessão do Firebase persistiu, pula o Welcome direto pro Home.
    // skipAutoLogin é ativado pelo fluxo de registro para evitar race condition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!WelcomeScreen.skipAutoLogin &&
          FirebaseAuth.instance.currentUser != null) {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _sparkController.dispose();
    _floatController.dispose();
    _introController.dispose();
    _blinkController.dispose();
    _talkController.dispose();
    _ringController.dispose();
    _particleController.dispose();
    _tapController.dispose();
    _pointer.dispose();
    super.dispose();
  }

  /// Glow neon verde do corpo do Sparky: silhueta tingida de verde, borrada,
  /// posicionada atrás do corpo com o mesmo enquadramento. `sigma` controla o
  /// espalhamento (quanto maior, mais difuso) e `opacity` a intensidade.
  Widget _neonGlow(double sigma, double opacity) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 1.45,
          alignment: Alignment.topCenter,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                'assets/images/sparky.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.8),
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
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
                  // Logo do capacete Spark
                  Image.asset(
                    'assets/images/spark_icon.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                  ),
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
                        'by VoltsMind',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  return MouseRegion(
                    // parallax: o mascote acompanha levemente o ponteiro
                    onHover: (e) {
                      _pointer.value = Offset(
                        ((e.localPosition.dx / w) * 2 - 1).clamp(-1.0, 1.0),
                        ((e.localPosition.dy / h) * 2 - 1).clamp(-1.0, 1.0),
                      );
                    },
                    onExit: (_) => _pointer.value = Offset.zero,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _sparkController,
                        _floatController,
                        _introController,
                        _blinkController,
                        _talkController,
                        _ringController,
                        _particleController,
                        _tapController,
                        _pointer,
                      ]),
                      builder: (context, child) {
                        // pulso suave 0..1 para o brilho verde
                        final pulse = _sparkController.value;

                        // flutuar: 0 (baixo) .. 1 (cima)
                        final lift = _floatCurve.value;
                        final floatY = (lift - 0.5) * 14;

                        // piscar: olhos fechados num instante curto
                        final bc = _blinkController.value;
                        final blinking = bc > 0.93 && bc < 0.99;

                        // falar: rajadas curtas com pausas
                        final tk = _talkController.value;
                        final envelope =
                            0.5 + 0.5 * math.sin(tk * 2 * math.pi);
                        final gate =
                            ((envelope - 0.7) / 0.3).clamp(0.0, 1.0);
                        final fast =
                            0.5 + 0.5 * math.sin(tk * 2 * math.pi * 5);
                        final talk = (gate * fast).clamp(0.0, 1.0);
                        final mouthSX = 1.0 + 0.05 * talk;
                        final mouthSY = 1.0 + 0.20 * talk;

                        // anéis girando + parallax + pulinho ao tocar
                        final ringAngle = _ringController.value * 2 * math.pi;
                        final tilt = _pointer.value;
                        final tapBounce =
                            math.sin(math.pi * _tapController.value) * 0.12;

                        return Stack(
                          alignment: const Alignment(0, -0.08),
                          children: [
                            // (1) Spotlight: cone de luz verde vindo de cima
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _SpotlightPainter(0.10 + 0.06 * pulse),
                              ),
                            ),
                            // (5) Partículas de energia subindo
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _ParticlePainter(
                                    _particleController.value),
                              ),
                            ),
                            // Glow radial verde pulsante
                            Container(
                              width: 285,
                              height: 285,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primary.withValues(
                                        alpha: 0.18 + 0.10 * pulse),
                                    AppColors.background.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                            // (6) Anel externo girando
                            Transform.rotate(
                              angle: ringAngle,
                              child: CustomPaint(
                                size: const Size(236, 236),
                                painter: _RingPainter(
                                  color: AppColors.greenDark
                                      .withValues(alpha: 0.5),
                                  segments: 3,
                                  gap: 0.28,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            // (6) Anel interno girando ao contrário
                            Transform.rotate(
                              angle: -ringAngle * 1.7,
                              child: CustomPaint(
                                size: const Size(180, 180),
                                painter: _RingPainter(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.45),
                                  segments: 5,
                                  gap: 0.16,
                                  strokeWidth: 1.5,
                                ),
                              ),
                            ),
                            // (2) Sombra no chão (encolhe/clareia ao flutuar)
                            Transform.translate(
                              offset: const Offset(0, 116),
                              child: Container(
                                width: 150 - 26 * lift,
                                height: 24 - 5 * lift,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100),
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.black.withValues(
                                          alpha: 0.42 - 0.16 * lift),
                                      Colors.black.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Mascote: power-up + flutuar + parallax + toque
                            Opacity(
                              opacity: _introFade.value.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, floatY),
                                // (3) parallax: inclina seguindo o ponteiro
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.0012)
                                    ..rotateX(-tilt.dy * 0.12)
                                    ..rotateY(tilt.dx * 0.16),
                                  child: Transform.scale(
                                    // power-up de entrada + (7) pulinho
                                    scale: (0.7 + 0.3 * _introScale.value) +
                                        tapBounce,
                                    // (7) tocar no Sparky faz ele pular
                                    child: GestureDetector(
                                      onTap: () =>
                                          _tapController.forward(from: 0),
                                      child: Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: AppColors.card,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(
                                                      alpha: 0.30 +
                                                          0.25 * pulse),
                                              blurRadius: 28 + 18 * pulse,
                                              spreadRadius: 4 + 4 * pulse,
                                            ),
                                          ],
                                          border: Border.all(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.6),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              // 0) glow neon verde pulsante
                                              //    (atrás do corpo — combina
                                              //    com a temática do Spark)
                                              _neonGlow(
                                                  16, 0.42 + 0.20 * pulse),
                                              _neonGlow(
                                                  8, 0.50 + 0.24 * pulse),
                                              // 1) corpo do Sparky (estático)
                                              child!,
                                              // 1b) olhos fechados (piscar)
                                              if (blinking)
                                                Transform.scale(
                                                  scale: 1.45,
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: Image.asset(
                                                    'assets/images/sparky_blink.png',
                                                    fit: BoxFit.cover,
                                                    alignment:
                                                        const Alignment(0, -0.8),
                                                    filterQuality:
                                                        FilterQuality.high,
                                                  ),
                                                ),
                                              // 1c) boca falando (abre/fecha)
                                              Transform.scale(
                                                scaleX: mouthSX,
                                                scaleY: mouthSY,
                                                alignment:
                                                    const Alignment(0, 0.23),
                                                child: Transform.scale(
                                                  scale: 1.45,
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: Image.asset(
                                                    'assets/images/sparky_mouth.png',
                                                    fit: BoxFit.cover,
                                                    alignment:
                                                        const Alignment(0, -0.8),
                                                    filterQuality:
                                                        FilterQuality.high,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: Transform.scale(
                        scale: 1.45,
                        alignment: Alignment.topCenter,
                        child: Image.asset(
                          'assets/images/sparky.png',
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.8),
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Texto ───────────────────────────────────────────
            Expanded(
              flex: 4,
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
                      'Sua Jornada de\nEstudos e Ferramentas\nPráticas para o Setor Elétrico.',
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
                      'SPDA, Estudos, Termografia e Comissionamento —\nda NR-10 ao IEC 61850, em uma só plataforma',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
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
                        onPressed: () => context.push('/login'),
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
                        onPressed: () => context.push('/register'),
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
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Tem um código de cortesia? ',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                            ),
                            const TextSpan(
                              text: 'Ative na conta',
                              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
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

// (1) Cone de luz (spotlight) verde descendo do topo sobre o mascote.
class _SpotlightPainter extends CustomPainter {
  final double intensity;
  _SpotlightPainter(this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const topY = 0.0;
    final botY = size.height * 0.74;
    final path = Path()
      ..moveTo(cx - 16, topY)
      ..lineTo(cx + 16, topY)
      ..lineTo(cx + size.width * 0.34, botY)
      ..lineTo(cx - size.width * 0.34, botY)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: intensity),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, topY, size.width, botY - topY))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.intensity != intensity;
}

// (5) Partículas de energia verdes subindo ao redor do mascote.
class _ParticlePainter extends CustomPainter {
  final double t; // 0..1 do controller
  _ParticlePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const n = 14;
    final paint = Paint()..style = PaintingStyle.fill;
    final yBottom = size.height * 0.66;
    final yTop = size.height * 0.12;
    for (int i = 0; i < n; i++) {
      final r1 = _frac(i * 12.9898);
      final r2 = _frac(i * 78.233);
      final r3 = _frac(i * 43.123);
      final speed = 0.6 + r2 * 0.8;
      final phase = (t * speed + r1) % 1.0; // 0 base → 1 topo
      final spread = (r1 - 0.5) * size.width * 0.5;
      final sway = math.sin((phase * 2 + r3) * math.pi * 2) * 10;
      final x = cx + spread + sway;
      final y = yBottom + (yTop - yBottom) * phase;
      final fade = math.sin(phase * math.pi); // aparece/some no trajeto
      final radius = 1.2 + r3 * 1.8;
      paint.color = AppColors.primary
          .withValues(alpha: (0.5 * fade).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  double _frac(double v) {
    final s = math.sin(v) * 43758.5453;
    return s - s.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}

// (6) Anel segmentado (com gaps) — rotacionado pelo widget para "girar".
class _RingPainter extends CustomPainter {
  final Color color;
  final int segments;
  final double gap; // fração vazia de cada segmento (0..1)
  final double strokeWidth;
  _RingPainter({
    required this.color,
    required this.segments,
    required this.gap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final seg = (2 * math.pi) / segments;
    final draw = seg * (1 - gap);
    for (int i = 0; i < segments; i++) {
      final start = i * seg + seg * gap / 2;
      canvas.drawArc(rect, start, draw, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.color != color ||
      old.segments != segments ||
      old.gap != gap ||
      old.strokeWidth != strokeWidth;
}
