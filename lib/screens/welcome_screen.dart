import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/l10n/app_localizations.dart';

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
  late AnimationController _nodController; // aceninho de cabeça ocasional
  late AnimationController _chargeController; // raio do peito "carregando"
  late AnimationController _bubbleController; // balão de fala (entra/sai)
  late Animation<double> _floatCurve;
  late Animation<double> _introFade;
  late Animation<double> _introScale;

  // Parallax: posição do ponteiro normalizada (-1..1) em relação ao centro.
  final ValueNotifier<Offset> _pointer = ValueNotifier(Offset.zero);
  // Olhar automático (quando não há mouse): faz os olhos darem uma espiada.
  final ValueNotifier<Offset> _autoLook = ValueNotifier(Offset.zero);

  // Faísca elétrica ao tocar: muda a cada toque pra cada raio sair diferente.
  int _tapSeed = 0;
  // Variação da piscada: às vezes pisca duas vezes.
  final math.Random _rng = math.Random();
  bool _doubleBlink = false;
  double _lastBlink = 0;
  // Timers de idle.
  Timer? _nodTimer;
  Timer? _glanceTimer;
  Timer? _bubbleTimer;

  // Balão de fala: mensagens rotativas de saudação/dica.
  int _msgIndex = 0;
  static const List<String> _messages = [
    'Bora aprender? ⚡',
    'Pronto pro duelo?',
    'Vamos energizar seus estudos!',
    'Tô carregado pra hoje! 🔋',
    'Partiu fechar uma sequência? 🔥',
    'Cada estudo é uma faísca! ✨',
    'Que tal um desafio rapidinho?',
    'Sua evolução não para! 📈',
    'Tamo junto nessa jornada! 💪',
  ];

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
    // Aceninho de cabeça ocasional (gesto curto e simpático)
    _nodController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Raio do peito "carregando" — pulso elétrico (breathing)
    _chargeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    // Balão de fala: anima entrada/saída
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // A cada ciclo de piscada, sorteia se a próxima será dupla (~35%).
    _blinkController.addListener(() {
      final v = _blinkController.value;
      if (v < _lastBlink) {
        _doubleBlink = _rng.nextDouble() < 0.35;
      }
      _lastBlink = v;
    });
    _scheduleNod();
    _scheduleGlance();
    _scheduleBubble();

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

  /// Dispara um aceninho daqui a 7–12s e se reagenda (loop de idle).
  void _scheduleNod() {
    _nodTimer = Timer(Duration(milliseconds: 7000 + _rng.nextInt(5000)), () {
      if (!mounted) return;
      _nodController.forward(from: 0);
      _scheduleNod();
    });
  }

  /// Espiadinha automática dos olhos quando não há mouse (mobile): olha pra
  /// um lado por ~1,2s e volta ao centro.
  void _scheduleGlance() {
    _glanceTimer = Timer(Duration(milliseconds: 3500 + _rng.nextInt(3500)), () {
      if (!mounted) return;
      if (_pointer.value == Offset.zero) {
        _autoLook.value = Offset(
          (_rng.nextDouble() * 2 - 1) * 0.9,
          (_rng.nextDouble() * 2 - 1) * 0.6,
        );
        Timer(const Duration(milliseconds: 1200), () {
          if (mounted) _autoLook.value = Offset.zero;
        });
      }
      _scheduleGlance();
    });
  }

  /// Mostra o balão de fala por ~3,5s, esconde por ~3s e troca a mensagem.
  void _scheduleBubble() {
    _bubbleTimer = Timer(Duration(milliseconds: 2200 + _rng.nextInt(1500)), () {
      if (!mounted) return;
      _bubbleController.forward();
      Timer(const Duration(milliseconds: 3500), () {
        if (!mounted) return;
        _bubbleController.reverse();
        Timer(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
        });
        _scheduleBubble();
      });
    });
  }

  @override
  void dispose() {
    _nodTimer?.cancel();
    _glanceTimer?.cancel();
    _bubbleTimer?.cancel();
    _sparkController.dispose();
    _floatController.dispose();
    _introController.dispose();
    _blinkController.dispose();
    _talkController.dispose();
    _ringController.dispose();
    _particleController.dispose();
    _tapController.dispose();
    _nodController.dispose();
    _chargeController.dispose();
    _bubbleController.dispose();
    _pointer.dispose();
    _autoLook.dispose();
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

  /// Balão de fala acima do Sparky, com mensagem rotativa. Entra/sai animado
  /// pelo _bubbleController e não captura toques (passam pro mascote).
  Widget _speechBubble() {
    return Align(
      alignment: const Alignment(0.0, -0.92),
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _bubbleController,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: _bubbleController,
              curve: Curves.easeOutBack,
            ),
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 230),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    _messages[_msgIndex],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CustomPaint(
                  size: const Size(18, 9),
                  painter: _BubbleTailPainter(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth;
            final maxH = c.maxHeight;
            final isWide = maxW >= 600; // tablets / iPads / desktop
            // Mascote escala p/ caber: limitado por largura e altura disponível.
            final double heroDim =
                math.min(maxW * 0.78, maxH * 0.40).clamp(150.0, 300.0).toDouble();
            return SingleChildScrollView(
              child: ConstrainedBox(
                // garante que ocupe pelo menos a tela toda (centraliza) e role
                // quando não couber, sem nunca cortar os botões.
                constraints: BoxConstraints(minHeight: maxH),
                child: Center(
                  child: ConstrainedBox(
                    // em telas largas não estica: limita a coluna central.
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: isWide ? 40 : 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 6),
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

            // ── Hero Illustration (escala p/ caber em qualquer tela) ──
            SizedBox(
              width: heroDim,
              height: heroDim,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  // canvas de design fixo — todo o mascote/anéis/partículas é
                  // desenhado aqui e o FittedBox escala para `heroDim`.
                  width: 300,
                  height: 300,
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
                        _nodController,
                        _chargeController,
                        _bubbleController,
                        _pointer,
                        _autoLook,
                      ]),
                      builder: (context, child) {
                        // pulso suave 0..1 para o brilho verde
                        final pulse = _sparkController.value;

                        // flutuar: 0 (baixo) .. 1 (cima)
                        final lift = _floatCurve.value;
                        final floatY = (lift - 0.5) * 14;

                        // piscar: olhos fechados num instante curto;
                        // de vez em quando uma piscada dupla (janela extra antes)
                        final bc = _blinkController.value;
                        final blinking = (bc > 0.93 && bc < 0.99) ||
                            (_doubleBlink && bc > 0.86 && bc < 0.90);

                        // falar: rajadas curtas com pausas
                        final tk = _talkController.value;
                        final envelope =
                            0.5 + 0.5 * math.sin(tk * 2 * math.pi);
                        final gate =
                            ((envelope - 0.7) / 0.3).clamp(0.0, 1.0);
                        final fast =
                            0.5 + 0.5 * math.sin(tk * 2 * math.pi * 5);
                        final talk = (gate * fast).clamp(0.0, 1.0);
                        // reação de surpresa ao tocar (boca "O" + olhos saltam)
                        final react =
                            math.sin(math.pi * _tapController.value);
                        final mouthSX = (1.0 + 0.05 * talk) - 0.10 * react;
                        final mouthSY = (1.0 + 0.20 * talk) + 0.55 * react;
                        // raio do peito carregando (no Welcome: pulso idle;
                        // pode ser ligado ao XP do usuário em 0..1)
                        final charge = _chargeController.value;
                        // olhos: seguem o mouse; sem mouse, dão espiadinhas
                        final look = _pointer.value != Offset.zero
                            ? _pointer.value
                            : _autoLook.value;

                        // anéis girando + parallax + pulinho ao tocar
                        final ringAngle = _ringController.value * 2 * math.pi;
                        final tilt = _pointer.value;
                        final tapBounce =
                            math.sin(math.pi * _tapController.value) * 0.12;
                        // olhos seguem levemente o ponteiro (ou a espiadinha)
                        final eyeOffset = Offset(
                          look.dx * 3.2,
                          look.dy * 2.4,
                        );
                        // olhos "saltam" na reação de surpresa
                        final eyesPop = 1.0 + 0.16 * react;
                        // aceninho: meia-senoide curta (cabeça baixa e volta)
                        final nod = math.sin(math.pi * _nodController.value);

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
                                    ..rotateX(-tilt.dy * 0.12 + nod * 0.18)
                                    ..rotateY(tilt.dx * 0.16),
                                  child: Transform.scale(
                                    // power-up de entrada + (7) pulinho
                                    scale: (0.7 + 0.3 * _introScale.value) +
                                        tapBounce,
                                    // (7) tocar no Sparky faz ele pular
                                    child: GestureDetector(
                                      onTap: () {
                                        _tapSeed++;
                                        _tapController.forward(from: 0);
                                      },
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
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
                                              // 1) corpo do Sparky (sem olhos)
                                              child!,
                                              // 1a) olhos — camada móvel que
                                              //     segue o ponteiro e salta
                                              //     na reação de surpresa
                                              Transform.translate(
                                                offset: eyeOffset,
                                                child: Transform.scale(
                                                  scale: eyesPop,
                                                  child: Transform.scale(
                                                    scale: 1.45,
                                                    alignment:
                                                        Alignment.topCenter,
                                                    child: Image.asset(
                                                      'assets/images/sparky_eyes.png',
                                                      fit: BoxFit.cover,
                                                      alignment: const Alignment(
                                                          0, -0.8),
                                                      filterQuality:
                                                          FilterQuality.high,
                                                    ),
                                                  ),
                                                ),
                                              ),
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
                                              // 1d) raio do peito "carregando":
                                              //     brilho dourado pulsante
                                              IgnorePointer(
                                                child: Opacity(
                                                  opacity: (0.35 + 0.5 * charge)
                                                      .clamp(0.0, 1.0),
                                                  child: Transform.scale(
                                                    scale: 1.45,
                                                    alignment:
                                                        Alignment.topCenter,
                                                    child: ImageFiltered(
                                                      imageFilter:
                                                          ui.ImageFilter.blur(
                                                        sigmaX: 2.5 + 3.5 * charge,
                                                        sigmaY: 2.5 + 3.5 * charge,
                                                      ),
                                                      child: ColorFiltered(
                                                        colorFilter:
                                                            const ColorFilter
                                                                .mode(
                                                          Color(0xFFFFF3A0),
                                                          BlendMode.srcIn,
                                                        ),
                                                        child: Image.asset(
                                                          'assets/images/sparky_bolt.png',
                                                          fit: BoxFit.cover,
                                                          alignment:
                                                              const Alignment(
                                                                  0, -0.8),
                                                          filterQuality:
                                                              FilterQuality.high,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                          // (8) faísca elétrica saindo do
                                          //     raio do peito ao tocar
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: CustomPaint(
                                                painter: _SparkBurstPainter(
                                                  _tapController.value,
                                                  _tapSeed,
                                                ),
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
                            // (4) balão de fala com saudações/dicas
                            _speechBubble(),
                          ],
                        );
                      },
                      child: Transform.scale(
                        scale: 1.45,
                        alignment: Alignment.topCenter,
                        child: Image.asset(
                          'assets/images/sparky_noeyes.png',
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
                ),
              ),

            // ── Texto ───────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  isWide ? 0 : 32, 24, isWide ? 0 : 32, 8),
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
                    const SizedBox(height: 28),
                    const Text(
                      'Sua Jornada de\nEstudos e Ferramentas\nPráticas para o Setor Elétrico.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.welcomeSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Botão principal EXS
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.push('/login'),
                        child: Text(
                          l10n.welcomeLoginButton,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        child: Text(
                          l10n.welcomeCreateAccountButton,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: l10n.haveCourtesyCode,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                            ),
                            TextSpan(
                              text: l10n.activateInAccount,
                              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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

// (8) Faísca elétrica ao tocar: poucos raios curtos com ramificações,
// núcleo claro + glow, num flash rápido (relâmpago pisca e some).
// `progress` 0..1 vem do _tapController; `seed` muda a cada toque.
class _SparkBurstPainter extends CustomPainter {
  final double progress;
  final int seed;
  _SparkBurstPainter(this.progress, this.seed);

  // direções (rad) irradiando do raio do peito: laterais, diagonais e baixo
  // (evita subir reto pra cima, em cima do rosto).
  static const _dirs = [-2.7, -0.45, 0.5, 2.6, 1.9, -2.1];

  @override
  void paint(Canvas canvas, Size size) {
    // só na primeira fração do toque → flash curto, sem poluir
    if (progress <= 0.0 || progress >= 0.55) return;
    final p = progress / 0.55; // 0..1 dentro da janela do flash
    // dois lampejos rápidos que decaem (cara de relâmpago)
    final flick = (p < 0.18 || (p > 0.34 && p < 0.5)) ? 1.0 : 0.4;
    final intensity = ((1.0 - p) * flick).clamp(0.0, 1.0);
    if (intensity < 0.03) return;

    // origem = raio amarelo no peito do mascote (no espaço de 200px do círculo)
    final center = Offset(size.width * 0.495, size.height * 0.91);
    final rng = math.Random(seed);
    final reach = 26 + 22 * p;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4.0
      ..color = AppColors.gold.withValues(alpha: 0.28 * intensity)
      ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 3.5);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.95 * intensity);

    for (int i = 0; i < _dirs.length; i++) {
      final ang = _dirs[i] + (rng.nextDouble() - 0.5) * 0.5;
      final len = reach * (0.8 + rng.nextDouble() * 0.4);
      final path = _boltPath(center, ang, len, rng);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, core);
    }
  }

  Path _boltPath(Offset o, double ang, double len, math.Random rng) {
    final dir = Offset(math.cos(ang), math.sin(ang));
    final perp = Offset(-dir.dy, dir.dx);
    final path = Path()..moveTo(o.dx, o.dy);
    const segs = 5;
    Offset? forkAt;
    double forkBaseT = 0;
    for (int s = 1; s <= segs; s++) {
      final t = s / segs;
      final jit = (rng.nextDouble() - 0.5) * len * 0.22;
      final pt = Offset(
        o.dx + dir.dx * len * t + perp.dx * jit,
        o.dy + dir.dy * len * t + perp.dy * jit,
      );
      path.lineTo(pt.dx, pt.dy);
      if (s == 2) {
        forkAt = pt;
        forkBaseT = t;
      }
    }
    // uma ramificação curta saindo de um nó intermediário
    if (forkAt != null) {
      final bang = ang + (rng.nextDouble() < 0.5 ? -1 : 1) * (0.5 + rng.nextDouble() * 0.5);
      final blen = len * (0.35 + rng.nextDouble() * 0.2) * (1 - forkBaseT + 0.4);
      final bdir = Offset(math.cos(bang), math.sin(bang));
      final bperp = Offset(-bdir.dy, bdir.dx);
      path.moveTo(forkAt.dx, forkAt.dy);
      const bs = 3;
      for (int s = 1; s <= bs; s++) {
        final t = s / bs;
        final jit = (rng.nextDouble() - 0.5) * blen * 0.3;
        path.lineTo(
          forkAt.dx + bdir.dx * blen * t + bperp.dx * jit,
          forkAt.dy + bdir.dy * blen * t + bperp.dy * jit,
        );
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _SparkBurstPainter old) =>
      old.progress != progress || old.seed != seed;
}

// Rabinho do balão de fala (triângulo apontando pro Sparky).
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tri = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(tri, Paint()..color = AppColors.card);
    final edges = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(
      edges,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter old) => false;
}
