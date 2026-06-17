import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/models/user_model.dart';
import 'package:spark_app/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────
//  SPARKY COMPANION — mascote de canto que reage a eventos do app.
//
//  Como usar de QUALQUER tela (ConsumerWidget / com `ref`):
//    ref.read(sparkyCompanionProvider.notifier).celebrate('Boa! 🎉');
//    ref.read(sparkyCompanionProvider.notifier).levelUp(7);
//    ref.read(sparkyCompanionProvider.notifier).streak(10);
//    ref.read(sparkyCompanionProvider.notifier).achievement('Mestre do SPDA');
//    ref.read(sparkyCompanionProvider.notifier).cheer('Mandou bem!');
//    ref.read(sparkyCompanionProvider.notifier).sad('Quase lá!');
//
//  O widget [SparkyCompanion] já está montado no app inteiro (main.dart),
//  então basta disparar — ele aparece no canto, reage e se esconde sozinho.
// ─────────────────────────────────────────────────────────────────

enum SparkyReaction { hidden, celebrate, levelUp, streak, achievement, cheer, sad }

class SparkyCompanionState {
  final SparkyReaction reaction;
  final String message;
  final int nonce; // muda a cada disparo (re-dispara mesmo se a reação repetir)
  const SparkyCompanionState({
    this.reaction = SparkyReaction.hidden,
    this.message = '',
    this.nonce = 0,
  });
}

class SparkyCompanionController extends Notifier<SparkyCompanionState> {
  @override
  SparkyCompanionState build() => const SparkyCompanionState();

  void _fire(SparkyReaction r, String m) {
    state = SparkyCompanionState(
      reaction: r,
      message: m,
      nonce: state.nonce + 1,
    );
  }

  void celebrate([String m = 'Boa! 🎉']) => _fire(SparkyReaction.celebrate, m);
  void levelUp(int level) => _fire(SparkyReaction.levelUp, 'Nível $level! ⚡');
  void streak(int days) => _fire(SparkyReaction.streak, 'Sequência de $days! 🔥');
  void achievement(String name) =>
      _fire(SparkyReaction.achievement, '🏆 $name');
  void cheer(String m) => _fire(SparkyReaction.cheer, m);
  void sad(String m) => _fire(SparkyReaction.sad, m);
  void hide() => _fire(SparkyReaction.hidden, '');
}

final sparkyCompanionProvider =
    NotifierProvider<SparkyCompanionController, SparkyCompanionState>(
  SparkyCompanionController.new,
);

// ─────────────────────────────────────────────────────────────────

class SparkyCompanion extends ConsumerStatefulWidget {
  const SparkyCompanion({super.key});

  @override
  ConsumerState<SparkyCompanion> createState() => _SparkyCompanionState();
}

class _SparkyCompanionState extends ConsumerState<SparkyCompanion>
    with TickerProviderStateMixin {
  late final AnimationController _enter; // desliza/escala pra dentro
  late final AnimationController _burst; // partículas (confete/raios)
  late final AnimationController _idle; // flutuar + piscar
  late final AnimationController _bounce; // pulinho ao aparecer

  SparkyReaction _reaction = SparkyReaction.hidden;
  String _message = '';
  int _burstSeed = 0;
  Timer? _hideTimer;

  // Baseline pra detectar SUBIDA de nível/streak/conquista na sessão.
  int? _lastLevel;
  int? _lastStreak;
  Set<String>? _lastBadges;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _burst = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 620));
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _enter.dispose();
    _burst.dispose();
    _idle.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _onEvent(SparkyCompanionState s) {
    if (s.reaction == SparkyReaction.hidden) {
      _dismiss();
      return;
    }
    setState(() {
      _reaction = s.reaction;
      _message = s.message;
      _burstSeed++;
    });
    _enter.forward();
    _bounce.forward(from: 0);
    if (_hasParticles(s.reaction)) _burst.forward(from: 0);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 4200), _dismiss);
  }

  void _dismiss() {
    _hideTimer?.cancel();
    if (mounted) _enter.reverse();
  }

  bool _hasParticles(SparkyReaction r) =>
      r == SparkyReaction.celebrate ||
      r == SparkyReaction.levelUp ||
      r == SparkyReaction.streak ||
      r == SparkyReaction.achievement;

  @override
  Widget build(BuildContext context) {
    // Escuta os disparos manuais vindos de qualquer tela.
    ref.listen<SparkyCompanionState>(sparkyCompanionProvider, (prev, next) {
      if (prev?.nonce != next.nonce) _onEvent(next);
    });

    // Auto-reação: observa nível/streak do usuário e comemora quando sobem
    // (sem mexer nos serviços — só observa o estado já existente).
    ref.listen<AsyncValue<UserModel?>>(userModelProvider, (prev, next) {
      final u = next.value;
      if (u == null) return;
      final badges = u.unlockedBadgeIds.toSet();
      if (_lastLevel == null) {
        // baseline inicial: não dispara
        _lastLevel = u.level;
        _lastStreak = u.currentStreak;
        _lastBadges = badges;
        return;
      }
      final notifier = ref.read(sparkyCompanionProvider.notifier);
      final newBadges = badges.difference(_lastBadges ?? const {});
      // prioridade: conquista > nível > streak (uma reação por atualização)
      if (newBadges.isNotEmpty) {
        Future.microtask(() {
          if (mounted) notifier.achievement('Conquista desbloqueada!');
        });
      } else if (u.level > _lastLevel!) {
        Future.microtask(() {
          if (mounted) notifier.levelUp(u.level);
        });
      } else if (u.currentStreak > (_lastStreak ?? 0) && u.currentStreak >= 2) {
        Future.microtask(() {
          if (mounted) notifier.streak(u.currentStreak);
        });
      }
      _lastLevel = u.level;
      _lastStreak = u.currentStreak;
      _lastBadges = badges;
    });

    return Positioned(
      right: 14,
      bottom: 26 + MediaQuery.of(context).padding.bottom,
      // Material transparente: o companheiro é montado acima do Material do
      // app (no builder), então sem isto o texto fica com as linhas amarelas
      // de debug ("missing Material"). Aqui ele ganha o ancestral certo.
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _burst, _idle, _bounce]),
        builder: (context, _) {
          final e = _enter.value;
          if (e <= 0.001) return const SizedBox.shrink();
          final ease = Curves.easeOutCubic.transform(e);
          final pop = Curves.easeOutBack.transform(e.clamp(0.0, 1.0));
          final floatY = math.sin(_idle.value * math.pi * 2) * 3;
          final jump = math.sin(math.pi * _bounce.value) * -12;
          final sad = _reaction == SparkyReaction.sad;

          return Opacity(
            opacity: ease,
            child: Transform.translate(
              offset: Offset((1 - ease) * 70, (1 - ease) * 90),
              child: Transform.scale(
                scale: 0.6 + 0.4 * pop,
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_message.isNotEmpty)
                      Flexible(child: _bubble(_message)),
                    const SizedBox(width: 8),
                    Transform.translate(
                      offset: Offset(0, floatY + (sad ? 4 : jump)),
                      child: _mascotWithParticles(sad),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _mascotWithParticles(bool sad) {
    const size = 84.0;
    // piscar curto dentro do ciclo idle
    final iv = _idle.value;
    final blinking = iv > 0.92 && iv < 0.97;

    return GestureDetector(
      onTap: _dismiss, // toque dispensa o companheiro
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // partículas irradiando (transbordam o círculo)
            if (_hasParticles(_reaction))
              Positioned(
                left: -68,
                right: -68,
                top: -88,
                bottom: -20,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CelebrationPainter(
                      progress: _burst.value,
                      seed: _burstSeed,
                      reaction: _reaction,
                    ),
                  ),
                ),
              ),
            // círculo do mascote
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: (sad ? AppColors.blue : AppColors.primary)
                      .withValues(alpha: 0.65),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (sad ? AppColors.blue : AppColors.primary)
                        .withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: Transform.rotate(
                  angle: sad ? 0.12 : 0.0, // cabecinha "caída" quando triste
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _layer('assets/images/sparky.png'),
                      if (blinking) _layer('assets/images/sparky_blink.png'),
                    ],
                  ),
                ),
              ),
            ),
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

  Widget _bubble(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Confete (celebrate/achievement) ou raios/faíscas (levelUp/streak).
class _CelebrationPainter extends CustomPainter {
  final double progress; // 0..1
  final int seed;
  final SparkyReaction reaction;
  _CelebrationPainter({
    required this.progress,
    required this.seed,
    required this.reaction,
  });

  static const _confetti = [
    AppColors.primary,
    AppColors.gold,
    AppColors.blue,
    AppColors.orange,
    Colors.white,
  ];

  bool get _isSpark =>
      reaction == SparkyReaction.levelUp || reaction == SparkyReaction.streak;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    // origem ~ centro do mascote (parte de baixo da área de partículas)
    final origin = Offset(size.width / 2, size.height - 32);
    final rng = math.Random(seed);
    final n = _isSpark ? 14 : 22;

    for (int i = 0; i < n; i++) {
      final ang = _isSpark
          ? -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 1.3
          : -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 1.1;
      final speed = (_isSpark ? 70 : 95) * (0.6 + rng.nextDouble() * 0.8);
      final dist = speed * Curves.easeOut.transform(progress);
      final gx = origin.dx + math.cos(ang) * dist;
      // confete cai (gravidade); faísca sobe reta
      final gravity = _isSpark ? 0.0 : 120 * progress * progress;
      final gy = origin.dy + math.sin(ang) * dist + gravity;
      final fade = (1 - progress);

      if (_isSpark) {
        final col = reaction == SparkyReaction.streak
            ? Color.lerp(AppColors.gold, AppColors.orange, rng.nextDouble())!
            : AppColors.gold;
        final p = Paint()
          ..color = col.withValues(alpha: (0.9 * fade).clamp(0.0, 1.0))
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        final tail = Offset(math.cos(ang), math.sin(ang)) * 7;
        canvas.drawLine(Offset(gx, gy), Offset(gx - tail.dx, gy - tail.dy), p);
      } else {
        final col = _confetti[i % _confetti.length];
        final paint = Paint()
          ..color = col.withValues(alpha: (fade).clamp(0.0, 1.0));
        canvas.save();
        canvas.translate(gx, gy);
        canvas.rotate(rng.nextDouble() * math.pi * 2 + progress * 6);
        final w = 3.0 + rng.nextDouble() * 3;
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: w * 1.6), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter old) =>
      old.progress != progress || old.seed != seed;
}
