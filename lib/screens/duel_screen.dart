import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/models/match_models.dart';
import 'package:spark_app/services/match_service.dart';
import 'package:spark_app/controllers/energy_controller.dart';
import 'package:spark_app/widgets/sparks_background.dart';

class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> with TickerProviderStateMixin {
  final MatchService _matchService = MatchService();
  Match? _match;
  bool _isSearching = true;
  bool _matchFinished = false;
  int _currentIndex = 0;
  int _selectedOption = -1;
  bool _hasAnswered = false;
  bool _opponentAnswered = false;

  // ELO / Division system
  int _eloRating = 1250;
  int _wins = 12;
  int _losses = 5;
  String get _division {
    if (_eloRating >= 2000) return 'Diamond';
    if (_eloRating >= 1600) return 'Platinum';
    if (_eloRating >= 1200) return 'Silver';
    if (_eloRating >= 800) return 'Bronze';
    return 'Iron';
  }
  String get _divisionTier {
    final rem = _eloRating % 400;
    if (rem >= 300) return 'III';
    if (rem >= 150) return 'II';
    return 'I';
  }
  IconData get _divisionIcon {
    if (_eloRating >= 2000) return Icons.diamond;
    if (_eloRating >= 1600) return Icons.workspace_premium;
    if (_eloRating >= 1200) return Icons.shield;
    return Icons.security;
  }

  // Bet animation
  bool _showBetDeduction = false;

  // Timer
  late AnimationController _timerController;
  static const int _questionTimeSec = 15;
  int _elapsedMs = 0;
  Timer? _tickTimer;

  // Animações
  late AnimationController _pulseController;
  late AnimationController _opponentAlertController;
  late Animation<double> _pulseAnim;
  late Animation<double> _opponentAlertAnim;

  // Streams
  StreamSubscription? _matchSub;
  StreamSubscription? _opponentSub;

  @override
  void initState() {
    super.initState();

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _questionTimeSec),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _opponentAlertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opponentAlertAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _opponentAlertController, curve: Curves.elasticOut),
    );

    _opponentSub = _matchService.opponentAnsweredStream.listen((qIndex) {
      if (qIndex == _currentIndex && !_hasAnswered && mounted) {
        setState(() => _opponentAnswered = true);
        _opponentAlertController.forward(from: 0);
        HapticFeedback.lightImpact();
      }
    });

    // Trigger bet deduction animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showBetDeduction = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showBetDeduction = false);
      });
    });

    _startMatchmaking();
  }

  static const int betAmount = 20;

  Future<void> _startMatchmaking() async {
    final energyCtrl = EnergyController();
    if (!await energyCtrl.spendSparkPoints(betAmount)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pontos Spark insuficientes para apostar. Custo: 20'), backgroundColor: AppColors.error),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      final match = await _matchService.findMatch('jogador_local');
      if (!mounted) return;
      setState(() {
        _match = match;
        _isSearching = false;
      });
      _startQuestion();
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _startQuestion() {
    _elapsedMs = 0;
    _selectedOption = -1;
    _hasAnswered = false;
    _opponentAnswered = false;
    _opponentAlertController.reset();

    _timerController.forward(from: 0);
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _elapsedMs += 100;
      if (_elapsedMs >= _questionTimeSec * 1000) {
        _tickTimer?.cancel();
        if (!_hasAnswered) _autoSubmit();
      }
    });

    // Simula oponente respondendo rápido aleatoriamente
    if (_match != null) {
      final delay = Duration(milliseconds: 2000 + (DateTime.now().millisecond % 5000));
      Future.delayed(delay, () {
        if (!_hasAnswered && mounted) {
          _matchService.simulateOpponentFastAnswer(_currentIndex);
        }
      });
    }
  }

  void _autoSubmit() {
    // Tempo esgotou: submissão com erro
    if (!_hasAnswered && mounted) {
      _submitAnswer(-1);
    }
  }

  void _submitAnswer(int option) {
    if (_hasAnswered || _match == null) return;

    setState(() {
      _selectedOption = option;
      _hasAnswered = true;
    });

    _timerController.stop();
    _tickTimer?.cancel();

    _matchService.submitAnswer(
      questionIndex: _currentIndex,
      selectedOption: option,
      timeTakenMs: _elapsedMs,
    );

    HapticFeedback.mediumImpact();

    // Avançar após 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentIndex + 1 >= (_match?.questions.length ?? 5)) {
        _finishMatch();
      } else {
        setState(() {
          _currentIndex++;
        });
        _startQuestion();
      }
    });
  }

  void _finishMatch() {
    _matchService.finishMatch();
    
    if (_match != null) {
      final p1Score = _match!.player1TotalScore;
      final p2Score = _match!.player2TotalScore;
      final energyCtrl = EnergyController();

      if (p1Score > p2Score) {
        energyCtrl.addSparkPoints(betAmount * 2);
      } else if (p1Score == p2Score) {
        energyCtrl.addSparkPoints(betAmount);
      }
    }

    setState(() => _matchFinished = true);
  }

  @override
  void dispose() {
    _timerController.dispose();
    _pulseController.dispose();
    _opponentAlertController.dispose();
    _tickTimer?.cancel();
    _matchSub?.cancel();
    _opponentSub?.cancel();
    _matchService.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isSearching) return _buildSearchingScreen();
    if (_matchFinished && _match != null) return _buildResultScreen();
    if (_match == null) return const SizedBox.shrink();

    final q = _match!.questions[_currentIndex];
    final p1Progress = _match!.player1Scores.length;
    final p2Progress = _match!.player2Scores.length;
    final total = _match!.questions.length;

    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header com nomes dos jogadores ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'DUELO DE FAÍSCAS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/$total',
                        style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── BARRA DE PROGRESSO DUPLA ──
              _buildDualProgressBar(p1Progress, p2Progress, total),
              const SizedBox(height: 8),

              // ── Timer circular ──
              AnimatedBuilder(
                animation: _timerController,
                builder: (_, __) => _buildTimerBar(),
              ),
              const SizedBox(height: 4),

              // ── Alerta "Oponente respondeu!" ──
              AnimatedBuilder(
                animation: _opponentAlertAnim,
                builder: (_, __) {
                  if (_opponentAlertAnim.value < 0.01) return const SizedBox(height: 4);
                  return Opacity(
                    opacity: _opponentAlertAnim.value.clamp(0, 1),
                    child: Transform.scale(
                      scale: _opponentAlertAnim.value.clamp(0.8, 1.0),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, color: AppColors.gold, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Oponente respondeu!',
                              style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Pergunta ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        q.question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(q.options.length, (i) {
                        return _buildOptionTile(i, q.options[i], q.correctIndex);
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BARRA DE PROGRESSO DUPLA
  // ═══════════════════════════════════════════════════════════
  Widget _buildDualProgressBar(int p1, int p2, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            // Jogador 1 (Você)
            _buildPlayerProgressRow(
              name: 'Você',
              progress: p1 / total,
              score: _match!.player1TotalScore,
              color: AppColors.primary,
              icon: Icons.person,
              isYou: true,
            ),
            const SizedBox(height: 8),
            Divider(color: AppColors.cardBorder.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 8),
            // Jogador 2 (Oponente)
            _buildPlayerProgressRow(
              name: 'Oponente',
              progress: p2 / total,
              score: _match!.player2TotalScore,
              color: AppColors.gold,
              icon: Icons.flash_on,
              isYou: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerProgressRow({
    required String name,
    required double progress,
    required double score,
    required Color color,
    required IconData icon,
    required bool isYou,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 65,
          child: Text(
            name,
            style: TextStyle(
              color: isYou ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              backgroundColor: AppColors.inputBackground.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${score.toInt()} pts',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TIMER BAR
  // ═══════════════════════════════════════════════════════════
  Widget _buildTimerBar() {
    final remaining = 1.0 - _timerController.value;
    final seconds = (_questionTimeSec * remaining).ceil();
    final isLow = seconds <= 5;
    final color = isLow ? AppColors.error : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: remaining.clamp(0, 1),
                backgroundColor: AppColors.cardBorder.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${seconds}s',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  OPÇÕES
  // ═══════════════════════════════════════════════════════════
  Widget _buildOptionTile(int index, String text, int correctIndex) {
    bool isSelected = _selectedOption == index;
    Color borderColor = AppColors.cardBorder;
    Color bgColor = AppColors.card;
    Color textColor = Colors.white;

    if (_hasAnswered) {
      if (index == correctIndex) {
        borderColor = AppColors.accent;
        bgColor = AppColors.accent.withValues(alpha: 0.15);
      } else if (isSelected) {
        borderColor = Colors.redAccent;
        bgColor = Colors.redAccent.withValues(alpha: 0.15);
      } else {
        borderColor = Colors.transparent;
        textColor = AppColors.textMuted;
      }
    } else if (isSelected) {
      borderColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.15);
    }

    return GestureDetector(
      onTap: _hasAnswered ? null : () {
        setState(() => _selectedOption = index);
        _submitAnswer(index);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: isSelected && !_hasAnswered
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 12)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hasAnswered && index == correctIndex
                    ? AppColors.accent.withValues(alpha: 0.2)
                    : AppColors.inputBackground,
                border: Border.all(
                  color: _hasAnswered && index == correctIndex
                      ? AppColors.accent
                      : AppColors.cardBorder.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: _hasAnswered && index == correctIndex
                    ? const Icon(Icons.check, color: AppColors.accent, size: 16)
                    : Text(
                        String.fromCharCode(65 + index), // A, B, C, D
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TELA DE BUSCA
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchingScreen() {
    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ELO + Division badge
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_divisionIcon, color: AppColors.gold, size: 22),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_division $_divisionTier', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                          Text('ELO $_eloRating · ${_wins}W ${_losses}L', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Pulse icon
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: _pulseAnim.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: _pulseAnim.value * 0.3),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.bolt, color: AppColors.primary, size: 56),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'PROCURANDO OPONENTE...',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Text('Preparando sua arena de faíscas', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),

                // Bet deduction animation
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: _showBetDeduction ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: AnimatedSlide(
                    offset: _showBetDeduction ? Offset.zero : const Offset(0, 0.5),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, color: AppColors.error, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '-$betAmount Pontos Spark', // Use standard dash, not U+2212
                            style: const TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.cardBorder.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TELA DE RESULTADO
  // ═══════════════════════════════════════════════════════════
  Widget _buildResultScreen() {
    final p1Score = _match!.player1TotalScore;
    final p2Score = _match!.player2TotalScore;
    final won = p1Score > p2Score;
    final draw = p1Score == p2Score;

    final resultColor = won ? AppColors.primary : (draw ? AppColors.gold : Colors.redAccent);
    final resultIcon = won ? Icons.emoji_events : (draw ? Icons.handshake : Icons.close);
    final resultText = won ? 'VITÓRIA!' : (draw ? 'EMPATE!' : 'DERROTA');

    final p1Correct = _match!.player1Scores.where((s) => s.isCorrect).length;
    final p2Correct = _match!.player2Scores.where((s) => s.isCorrect).length;

    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícone de resultado
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: resultColor.withValues(alpha: 0.12),
                      border: Border.all(color: resultColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: resultColor.withValues(alpha: 0.35),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(resultIcon, color: resultColor, size: 55),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    resultText,
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    won ? '+$betAmount Pontos Adquiridos!' : (draw ? 'Seus $betAmount de aposta voltaram.' : 'Você perdeu os $betAmount apostados.'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  // ELO change
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: (won ? AppColors.primary : AppColors.error).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (won ? AppColors.primary : AppColors.error).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_divisionIcon, color: AppColors.gold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          won ? 'ELO +25 -> ${_eloRating + 25}' : (draw ? 'ELO 0' : 'ELO -15 -> ${_eloRating - 15}'),
                          style: TextStyle(color: won ? AppColors.primary : (draw ? AppColors.gold : AppColors.error), fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Scoreboard
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        _buildResultRow('Você', p1Score, p1Correct, AppColors.primary, true),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.3))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('VS', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
                              ),
                              Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.3))),
                            ],
                          ),
                        ),
                        _buildResultRow('Oponente', p2Score, p2Correct, AppColors.gold, false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Botão Voltar
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.home, color: AppColors.background),
                      label: const Text(
                        'VOLTAR AO MENU',
                        style: TextStyle(color: AppColors.background, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: resultColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _matchFinished = false;
                        _isSearching = true;
                        _currentIndex = 0;
                        _match = null;
                      });
                      _startMatchmaking();
                    },
                    child: const Text(
                      'JOGAR NOVAMENTE',
                      style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String name, double score, int correct, Color color, bool isYou) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(isYou ? Icons.person : Icons.flash_on, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('$correct/5 acertos', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            ],
          ),
        ),
        Text(
          '${score.toInt()} pts',
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
