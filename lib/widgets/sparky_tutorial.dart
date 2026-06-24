import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  SPARKY TUTORIAL — tour guiado com holofote (coachmark).
//
//  O Sparky aparece num overlay e aponta para os itens REAIS da tela
//  (trilhas, ferramentas, etc.) com um "fio" luminoso + seta, abrindo
//  um buraco de destaque (spotlight) sobre o alvo.
//
//  Mostrado UMA vez no 1º acesso (flag em SharedPreferences) e pode ser
//  reaberto a qualquer momento (ex.: nas Configurações):
//
//    SparkyTutorial.showIfFirstTime(context, targets: {...});
//    SparkyTutorial.show(context, targets: {...});
//
//  `targets` mapeia o id do passo → GlobalKey do widget a destacar.
//  Passos sem alvo (ou cujo alvo não exista) aparecem centralizados.
// ─────────────────────────────────────────────────────────────────

class _Step {
  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final String? targetId; // null = passo centralizado, sem holofote
  const _Step({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    this.targetId,
  });
}

const List<_Step> _steps = [
  _Step(
    icon: Icons.bolt,
    accent: AppColors.primary,
    title: 'Oi! Eu sou o Sparky ⚡',
    message:
        'Vou te mostrar onde fica cada coisa aqui no Spark. É rapidinho — '
        'toque na tela para avançar!',
  ),
  _Step(
    icon: Icons.home,
    accent: AppColors.primary,
    title: 'Início',
    message:
        'Esta é a sua central: progresso, desafio diário e atalhos. Sempre '
        'que se perder, é só voltar aqui!',
    targetId: 'home',
  ),
  _Step(
    icon: Icons.menu_book,
    accent: AppColors.blue,
    title: 'Trilhas de Estudo',
    message:
        'Aqui na aba Estudos ficam as trilhas com lições e minigames. Cada '
        'acerto te dá XP e te aproxima do próximo nível!',
    targetId: 'studies',
  ),
  _Step(
    icon: Icons.category,
    accent: AppColors.gold,
    title: 'Categorias',
    message:
        'Toque neste botão central para explorar todas as categorias e '
        'módulos de conteúdo disponíveis.',
    targetId: 'categories',
  ),
  _Step(
    icon: Icons.calculate,
    accent: AppColors.orange,
    title: 'Ferramentas',
    message:
        'Calculadoras e ferramentas práticas do dia a dia do eletricista '
        'ficam bem aqui. Super úteis na obra!',
    targetId: 'tools',
  ),
  _Step(
    icon: Icons.more_horiz,
    accent: AppColors.blue,
    title: 'Mais opções',
    message:
        'Neste menu você encontra o Ranking, o Torneio semanal, a Loja e o '
        'seu Perfil. Vale a pena conferir!',
    targetId: 'menu',
  ),
  _Step(
    icon: Icons.celebration,
    accent: AppColors.primary,
    title: 'Pronto pra brilhar! ✨',
    message:
        'É isso! Vou ficar aqui no cantinho torcendo por você. Toque em mim '
        'quando quiser comemorar uma conquista. Vamos nessa!',
  ),
];

const String _prefsKey = 'spark_tutorial_seen_v2';

/// Sinal global para pedir o "rever tutorial" a partir de outra tela
/// (ex.: Configurações). O [MainShellScreen] escuta este notifier e, ao
/// recebê-lo, vai para a aba Início e abre o tour com holofote nos alvos.
/// Quem solicita deve PRIMEIRO navegar para o Início e só então incrementar
/// (assim o overlay aparece sobre a barra de navegação, não sobre a tela atual).
final ValueNotifier<int> sparkyTourReplayRequest = ValueNotifier<int>(0);

class SparkyTutorial extends StatefulWidget {
  final Map<String, GlobalKey> targets;
  const SparkyTutorial({super.key, this.targets = const {}});

  /// Exibe o tour apenas se for o primeiro acesso (flag persistida).
  static Future<void> showIfFirstTime(
    BuildContext context, {
    Map<String, GlobalKey> targets = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey) ?? false) return;
    if (!context.mounted) return;
    await show(context, targets: targets);
  }

  /// Exibe o tour incondicionalmente (ex.: botão "Rever tutorial").
  static Future<void> show(
    BuildContext context, {
    Map<String, GlobalKey> targets = const {},
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Tutorial do Sparky',
      barrierColor: Colors.transparent, // o scrim é desenhado por nós (com furo)
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, a1, a2) => SparkyTutorial(targets: targets),
      transitionBuilder: (ctx, anim, a2, child) =>
          Opacity(opacity: anim.value, child: child),
    );
  }

  @override
  State<SparkyTutorial> createState() => _SparkyTutorialState();
}

class _SparkyTutorialState extends State<SparkyTutorial>
    with TickerProviderStateMixin {
  late final AnimationController _idle; // flutuar + piscar
  late final AnimationController _pulse; // anel + fio (loop)
  late final AnimationController _bounce; // pulinho a cada passo
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 620))
      ..forward();
  }

  @override
  void dispose() {
    _idle.dispose();
    _pulse.dispose();
    _bounce.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _steps.length - 1;

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() => _index++);
    _bounce.forward(from: 0);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    if (mounted) Navigator.of(context).pop();
  }

  /// Posição global do widget alvo (ou null se não existir nesta tela).
  Rect? _targetRect(String? id) {
    if (id == null) return null;
    final ctx = widget.targets[id]?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];
    final media = MediaQuery.of(context);
    final size = media.size;
    final rect = _targetRect(step.targetId);

    // Sparky fica na parte de cima/centro; o "fio" sai dele até o alvo.
    const sparkyR = 52.0;
    final baseCenterY = size.height * 0.40; // âncora estável (balão não treme)
    // mesmo deslocamento vertical aplicado ao mascote (flutuar + pulinho)
    final bob = math.sin(_idle.value * math.pi * 2) * 4 +
        math.sin(math.pi * _bounce.value) * -12;
    final sparkyCenter = Offset(size.width / 2, baseCenterY + bob);
    final lineFrom = sparkyCenter + const Offset(0, sparkyR + 6);
    final lineTo = rect == null
        ? null
        : Offset(rect.center.dx, rect.top - 12);

    final topInset = media.padding.top;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: AnimatedBuilder(
          animation: Listenable.merge([_idle, _pulse, _bounce]),
          builder: (context, _) {
            final pulse = _pulse.value;
            return Stack(
              children: [
                // ── Scrim escuro com furo + fio luminoso + seta ──
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CoachPainter(
                      hole: rect,
                      from: lineTo == null ? null : lineFrom,
                      to: lineTo,
                      accent: step.accent,
                      pulse: pulse,
                    ),
                  ),
                ),

                // ── Sparky (flutua + pulinho a cada passo) ──
                Positioned(
                  left: sparkyCenter.dx - sparkyR,
                  top: sparkyCenter.dy - sparkyR,
                  width: sparkyR * 2,
                  height: sparkyR * 2,
                  child: _Mascot(accent: step.accent, idle: _idle.value),
                ),

                // ── Balão de fala (acima do Sparky) ──
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: size.height - (baseCenterY - sparkyR - 12),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: _Bubble(
                        key: ValueKey(_index),
                        step: step,
                        isLast: _isLast,
                        pulse: pulse,
                      ),
                    ),
                  ),
                ),

                // ── Topo: indicadores + pular ──
                Positioned(
                  top: topInset + 8,
                  left: 20,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(_steps.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            width: active ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? step.accent
                                  : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      if (!_isLast)
                        TextButton(
                          onPressed: _finish,
                          child: const Text(
                            'Pular tour',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Balão de fala ───────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final _Step step;
  final bool isLast;
  final double pulse;
  const _Bubble({
    super.key,
    required this.step,
    required this.isLast,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: step.accent.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: step.accent.withValues(alpha: 0.22),
              blurRadius: 24,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(step.icon, color: step.accent, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      color: step.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            // dica "toque para continuar" pulsando
            Opacity(
              opacity: 0.55 + 0.45 * (0.5 + 0.5 * math.sin(pulse * math.pi * 2)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? 'Toque para começar' : 'Toque para continuar',
                    style: TextStyle(
                      color: step.accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isLast ? Icons.celebration : Icons.touch_app,
                    color: step.accent,
                    size: 15,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mascote (reaproveita o visual do SparkyCompanion) ───────────
class _Mascot extends StatelessWidget {
  final Color accent;
  final double idle;
  const _Mascot({required this.accent, required this.idle});

  @override
  Widget build(BuildContext context) {
    final blinking = idle > 0.92 && idle < 0.97;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.75), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.5),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _layer('assets/images/sparky.png'),
            if (blinking) _layer('assets/images/sparky_blink.png'),
          ],
        ),
      ),
    );
  }

  Widget _layer(String asset) => Transform.scale(
        scale: 1.5,
        alignment: Alignment.topCenter,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.8),
          filterQuality: FilterQuality.high,
        ),
      );
}

// ── Pinta o scrim (com furo no alvo) + fio luminoso + seta ──────
class _CoachPainter extends CustomPainter {
  final Rect? hole; // alvo a destacar (null = sem furo)
  final Offset? from; // origem do fio (perto do Sparky)
  final Offset? to; // ponta do fio (perto do alvo)
  final Color accent;
  final double pulse; // 0..1 loop
  _CoachPainter({
    required this.hole,
    required this.from,
    required this.to,
    required this.accent,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.80);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    if (hole == null) {
      canvas.drawRect(full, scrim);
    } else {
      final inflated = hole!.inflate(10);
      final rr = RRect.fromRectAndRadius(inflated, const Radius.circular(16));
      // scrim com furo
      final path = Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(rr),
      );
      canvas.drawPath(path, scrim);

      // anel fixo em volta do furo
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent.withValues(alpha: 0.9),
      );
      // anel pulsante (expande e some)
      final grow = inflated.inflate(6 * pulse);
      canvas.drawRRect(
        RRect.fromRectAndRadius(grow, Radius.circular(16 + 6 * pulse)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = accent.withValues(alpha: ((1 - pulse) * 0.8).clamp(0, 1)),
      );
    }

    // fio luminoso Sparky → alvo
    if (from != null && to != null) {
      // brilho (traço largo translúcido)
      canvas.drawLine(
        from!,
        to!,
        Paint()
          ..color = accent.withValues(alpha: 0.22)
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        from!,
        to!,
        Paint()
          ..color = accent
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      // ponto de luz viajando pelo fio
      final dot = Offset.lerp(from!, to!, pulse)!;
      canvas.drawCircle(
        dot,
        4,
        Paint()..color = Colors.white.withValues(alpha: (1 - pulse).clamp(0, 1)),
      );

      // seta (cabeça) apontando para o alvo
      final ang = (to! - from!).direction;
      const len = 15.0;
      final p1 = to! - Offset.fromDirection(ang - 0.5, len);
      final p2 = to! - Offset.fromDirection(ang + 0.5, len);
      final head = Path()
        ..moveTo(to!.dx, to!.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(head, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _CoachPainter old) =>
      old.hole != hole ||
      old.from != from ||
      old.to != to ||
      old.accent != accent ||
      old.pulse != pulse;
}
