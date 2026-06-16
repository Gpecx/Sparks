import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/core/data/offline_duel_questions.dart';
import 'package:spark_app/core/utils/rank_utils.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/models/match_models.dart';
import 'package:spark_app/services/match_service.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/widgets/sparks_background.dart';

/// Fases da tela do Duelo de Faíscas.
enum _DuelPhase { connecting, offline, searching, playing, waitingResult, finished, error }

class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> with TickerProviderStateMixin {
  final MatchService _matchService = MatchService();
  final UserService _userService = UserService();

  _DuelPhase _phase = _DuelPhase.connecting;
  String? _errorMessage;

  // ── Partida ──────────────────────────────────────────────────────
  bool _isBot = false;
  bool _offlineMode = false; // treino offline (sem internet, banco local)
  String? _matchId;
  List<DuelQuestion> _questions = [];
  final List<RoundScore> _myScores = [];
  final List<RoundScore> _oppScores = [];
  String _oppName = 'Oponente';

  int _currentIndex = 0;
  int _selectedOption = -1;
  bool _hasAnswered = false;
  bool _opponentAnswered = false;
  int _revealCorrect = -1; // índice correto revelado após responder
  bool _submitting = false;

  // Resultado
  int _eloChange = 0;
  String? _winnerId;

  String get _uid => _userService.uid;
  double get _myTotal => _myScores.fold(0.0, (s, r) => s + r.score);
  double get _oppTotal => _oppScores.fold(0.0, (s, r) => s + r.score);

  // ── Matchmaking ──────────────────────────────────────────────────
  Timer? _heartbeatTimer;
  Timer? _botOfferTimer;
  Timer? _abandonTimer;
  bool _showBotOffer = false;
  StreamSubscription<String?>? _queueSub;
  StreamSubscription<DuelMatch>? _matchSub;

  // ── ELO / Division (lidos ao vivo do UserService) ────────────────
  int get _eloRating => _userService.eloRating;
  int get _wins => _userService.wins;
  int get _losses => _userService.losses;
  Patente get _patente => RankUtils.fromElo(_eloRating);

  // Timer de questão
  late AnimationController _timerController;
  static const int _questionTimeSec = 15;
  int _elapsedMs = 0;
  Timer? _tickTimer;

  // Animações
  late AnimationController _pulseController;
  late AnimationController _opponentAlertController;
  late Animation<double> _pulseAnim;
  late Animation<double> _opponentAlertAnim;

  final _random = Random();
  Timer? _botOpponentTimer;

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

    _bootstrap();
  }

  // ═══════════════════════════════════════════════════════════
  //  CONECTIVIDADE + MATCHMAKING
  // ═══════════════════════════════════════════════════════════
  Future<void> _bootstrap() async {
    // Não confiamos em detectores de rede (dão falso "offline" em desktop/web).
    // O juiz da conexão é a própria chamada ao Firebase: se o matchmaking
    // falhar por rede, caímos na tela offline (que oferece treino com bots).
    _startMatchmaking();
  }

  Future<void> _startMatchmaking() async {
    setState(() {
      _phase = _DuelPhase.searching;
      _showBotOffer = false;
    });

    // Listener do nosso doc de fila — dispara quando um oponente nos pareia.
    _queueSub?.cancel();
    _queueSub = _matchService.myQueueMatchStream().listen((matchId) {
      if (matchId != null && mounted && _phase == _DuelPhase.searching) {
        _onMatched(matchId);
      }
    });

    // Heartbeat: mantém a fila viva e tenta parear a cada 6s.
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!mounted || _phase != _DuelPhase.searching) return;
      await _pollQueue();
    });

    // Oferece treino contra bot se demorar a achar oponente.
    _botOfferTimer?.cancel();
    _botOfferTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && _phase == _DuelPhase.searching) {
        setState(() => _showBotOffer = true);
      }
    });

    await _pollQueue(initial: true);
  }

  Future<void> _pollQueue({bool initial = false}) async {
    try {
      final res = await _matchService.joinQueue();
      if (!mounted) return;
      if (res.matched) {
        _onMatched(res.matchId!);
      }
    } catch (e) {
      if (!mounted) return;
      // Só a 1ª tentativa decide offline; falhas de heartbeat são transitórias.
      if (initial) {
        debugPrint('[duel] matchmaking falhou (offline?): $e');
        setState(() => _phase = _DuelPhase.offline);
      }
    }
  }

  void _onMatched(String matchId) {
    if (_matchId != null) return; // já pareado
    _cancelMatchmakingTimers();
    _queueSub?.cancel();
    setState(() {
      _matchId = matchId;
      _isBot = false;
      _phase = _DuelPhase.playing;
    });

    // Sincroniza a partida em tempo real.
    _matchSub = _matchService.matchStream(matchId).listen(_onMatchSnapshot);
  }

  void _onMatchSnapshot(DuelMatch match) {
    if (!mounted) return;
    // Carrega as questões na primeira atualização.
    final firstLoad = _questions.isEmpty;
    setState(() {
      _questions = match.questions;
      _oppName = match.oppName(_uid);
      _myScores
        ..clear()
        ..addAll(match.myScores(_uid));
      _oppScores
        ..clear()
        ..addAll(match.oppScores(_uid));
    });

    // Alerta "Oponente respondeu!" quando o oponente passa do índice atual.
    if (_oppScores.length > _currentIndex && !_hasAnswered) {
      _triggerOpponentAlert();
    }

    // Servidor encerrou o duelo → mostra resultado.
    if (match.isFinished && _phase != _DuelPhase.finished) {
      _winnerId = match.winnerId;
      _finalizeFromServer();
    }

    if (firstLoad && _questions.isNotEmpty) {
      _startQuestion();
    }
  }

  void _triggerOpponentAlert() {
    if (_opponentAnswered) return;
    setState(() => _opponentAnswered = true);
    _opponentAlertController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  // ── Treino contra bot ────────────────────────────────────────────
  /// [offline] = sem internet: usa o banco de perguntas LOCAL (embutido).
  /// Online: busca perguntas reais das trilhas (com fallback local se cair).
  Future<void> _startBotMatch({bool offline = false}) async {
    _cancelMatchmakingTimers();
    _queueSub?.cancel();
    // Sai da fila em background (best-effort): NÃO esperamos a Cloud Function,
    // que pode ter cold start de vários segundos e faria o botão "travar".
    if (!offline) {
      _matchService.leaveQueue();
    }
    if (!mounted) return;

    setState(() => _phase = _DuelPhase.connecting);

    List<DuelQuestion> questions;
    if (offline) {
      questions = _localBotQuestions();
    } else {
      try {
        questions = await _matchService.getBotQuestions(count: 8);
        if (questions.isEmpty) questions = _localBotQuestions();
      } catch (_) {
        // Caiu a conexão ao preparar o treino → usa o banco local.
        questions = _localBotQuestions();
        offline = true;
      }
    }
    if (!mounted) return;

    setState(() {
      _isBot = true;
      _offlineMode = offline;
      _oppName = offline ? 'Bot (offline)' : 'Bot Treino';
      _questions = questions;
      _myScores.clear();
      _oppScores.clear();
      _currentIndex = 0;
      _phase = _DuelPhase.playing;
    });
    _startQuestion();
  }

  List<DuelQuestion> _localBotQuestions() {
    final bank = [...kOfflineDuelQuestions]..shuffle(_random);
    return bank.take(8).toList();
  }

  void _cancelMatchmakingTimers() {
    _heartbeatTimer?.cancel();
    _botOfferTimer?.cancel();
  }

  /// Cancela a busca e volta ao menu IMEDIATAMENTE. Cancela timers/listener
  /// antes (senão o heartbeat de 6s recoloca o jogador na fila) e sai da fila
  /// em background — sem esperar a Cloud Function (cold start travaria o botão).
  void _cancelSearchAndExit() {
    _cancelMatchmakingTimers();
    _queueSub?.cancel();
    _matchService.leaveQueue(); // best-effort, fire-and-forget
    if (mounted) Navigator.pop(context);
  }

  void _fail(String message) {
    setState(() {
      _phase = _DuelPhase.error;
      _errorMessage = message;
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  CICLO DE QUESTÃO
  // ═══════════════════════════════════════════════════════════
  void _startQuestion() {
    _elapsedMs = 0;
    _selectedOption = -1;
    _hasAnswered = false;
    _opponentAnswered = false;
    _revealCorrect = -1;
    _opponentAlertController.reset();

    _timerController.forward(from: 0);
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _elapsedMs += 100;
      if (_elapsedMs >= _questionTimeSec * 1000) {
        _tickTimer?.cancel();
        if (!_hasAnswered) _submitAnswer(-1);
      }
    });

    // Modo treino: bot responde com delay aleatório.
    if (_isBot) {
      _scheduleBotAnswer();
    }
  }

  void _scheduleBotAnswer() {
    _botOpponentTimer?.cancel();
    final idx = _currentIndex;
    final alertDelay = Duration(milliseconds: _random.nextInt(5000) + 1500);
    _botOpponentTimer = Timer(alertDelay, () {
      if (!mounted || idx != _currentIndex) return;
      if (!_hasAnswered) _triggerOpponentAlert();

      // Bot pontua a rodada (~65% de acerto).
      final q = _questions[idx];
      final botCorrect = _random.nextDouble() < 0.65;
      final botTime = _random.nextInt(4000) + 1000;
      _oppScores.add(RoundScore.local(
        questionIndex: idx,
        isCorrect: botCorrect && q.correctIndex != null,
        timeTakenMs: botTime,
      ));
      if (mounted) setState(() {});
    });
  }

  Future<void> _submitAnswer(int option) async {
    if (_hasAnswered || _submitting) return;

    setState(() {
      _selectedOption = option;
      _hasAnswered = true;
    });
    _timerController.stop();
    _tickTimer?.cancel();
    HapticFeedback.mediumImpact();

    final elapsed = _elapsedMs;
    final idx = _currentIndex;

    if (_isBot) {
      final q = _questions[idx];
      final isCorrect = option == q.correctIndex;
      _myScores.add(RoundScore.local(
        questionIndex: idx,
        isCorrect: isCorrect,
        timeTakenMs: elapsed,
      ));
      setState(() => _revealCorrect = q.correctIndex ?? -1);
      _advanceAfterDelay();
      return;
    }

    // PvP: valida no servidor.
    setState(() => _submitting = true);
    try {
      final res = await _matchService.submitAnswer(
        matchId: _matchId!,
        questionIndex: idx,
        selectedOption: option,
        elapsedMs: elapsed,
      );
      if (!mounted) return;
      setState(() {
        _revealCorrect = res.correctIndex;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Falha de rede: segue o jogo (o placar virá pelo snapshot).
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao enviar resposta. Continuando...')),
      );
    }
    _advanceAfterDelay();
  }

  void _advanceAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentIndex + 1 >= _questions.length) {
        _onMyQuestionsDone();
      } else {
        setState(() => _currentIndex++);
        _startQuestion();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  FIM DA PARTIDA
  // ═══════════════════════════════════════════════════════════
  Future<void> _onMyQuestionsDone() async {
    if (_isBot) {
      // Treino não afeta o ranking.
      setState(() {
        _eloChange = 0;
        _winnerId = _myTotal > _oppTotal
            ? _uid
            : (_myTotal == _oppTotal ? null : 'bot');
        _phase = _DuelPhase.finished;
      });
      return;
    }

    setState(() => _phase = _DuelPhase.waitingResult);

    try {
      final res = await _matchService.finalize(matchId: _matchId!);
      if (!mounted) return;
      if (res.finished) {
        _applyFinalResult(res);
        return;
      }
    } catch (e) {
      debugPrint('[duel] finalize: $e');
    }

    // Oponente ainda jogando: aguarda o snapshot 'finished' ou força após 20s.
    _abandonTimer?.cancel();
    _abandonTimer = Timer(const Duration(seconds: 20), () async {
      if (!mounted || _phase == _DuelPhase.finished) return;
      try {
        final res = await _matchService.finalize(matchId: _matchId!, force: true);
        if (mounted && res.finished) _applyFinalResult(res);
      } catch (e) {
        if (mounted) _fail('Não foi possível apurar o resultado.');
      }
    });
  }

  /// Chamado quando o snapshot indica que o servidor já encerrou o duelo.
  Future<void> _finalizeFromServer() async {
    if (_phase == _DuelPhase.finished) return;
    try {
      final res = await _matchService.finalize(matchId: _matchId!);
      if (mounted && res.finished) _applyFinalResult(res);
    } catch (e) {
      debugPrint('[duel] finalizeFromServer: $e');
    }
  }

  void _applyFinalResult(FinalizeResult res) {
    _abandonTimer?.cancel();
    setState(() {
      _eloChange = res.eloChange;
      _winnerId = res.winnerId;
      _phase = _DuelPhase.finished;
    });

    // Concluir um duelo também conta como atividade de estudo do dia.
    Future.microtask(() async {
      try {
        await _userService.registerStudyActivity()
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('[Duel] Erro ao registrar atividade de estudo: $e');
      }
    });
  }

  @override
  void dispose() {
    _timerController.dispose();
    _pulseController.dispose();
    _opponentAlertController.dispose();
    _tickTimer?.cancel();
    _heartbeatTimer?.cancel();
    _botOfferTimer?.cancel();
    _abandonTimer?.cancel();
    _botOpponentTimer?.cancel();
    _queueSub?.cancel();
    _matchSub?.cancel();
    // Se ainda estava procurando, sai da fila.
    if (_phase == _DuelPhase.searching) {
      _matchService.leaveQueue();
    }
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _DuelPhase.connecting:
      case _DuelPhase.searching:
        return _buildSearchingScreen();
      case _DuelPhase.offline:
        return _buildOfflineScreen();
      case _DuelPhase.error:
        return _buildErrorScreen();
      case _DuelPhase.waitingResult:
        return _buildWaitingResultScreen();
      case _DuelPhase.finished:
        return _buildResultScreen();
      case _DuelPhase.playing:
        if (_questions.isEmpty) return _buildSearchingScreen();
        return _buildPlayingScreen();
    }
  }

  Widget _buildPlayingScreen() {
    final q = _questions[_currentIndex];
    final p1Progress = _myScores.length;
    final p2Progress = _oppScores.length;
    final total = _questions.length;

    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'DUELO DE FAÍSCAS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          if (_isBot) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('TREINO',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                            ),
                          ],
                        ],
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
              _buildDualProgressBar(p1Progress, p2Progress, total),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _timerController,
                builder: (_, _) => _buildTimerBar(),
              ),
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: _opponentAlertAnim,
                builder: (_, _) {
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        q.statement,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(q.options.length, (i) {
                        return _buildOptionTile(i, q.options[i], _revealCorrect);
                      }),
                      if (_submitting)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(
                            child: SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                          ),
                        ),
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
            _buildPlayerProgressRow(
              name: 'Você',
              progress: total == 0 ? 0 : p1 / total,
              score: _myTotal,
              color: AppColors.primary,
              icon: Icons.person,
              isYou: true,
            ),
            const SizedBox(height: 8),
            Divider(color: AppColors.cardBorder.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 8),
            _buildPlayerProgressRow(
              name: _oppName,
              progress: total == 0 ? 0 : p2 / total,
              score: _oppTotal,
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
          width: 80,
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isYou ? Colors.white : AppColors.textSecondary,
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
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800),
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

    final revealed = _hasAnswered && correctIndex >= 0;
    if (_hasAnswered) {
      if (revealed && index == correctIndex) {
        borderColor = AppColors.accent;
        bgColor = AppColors.accent.withValues(alpha: 0.15);
      } else if (isSelected) {
        borderColor = revealed ? Colors.redAccent : AppColors.primary;
        bgColor = (revealed ? Colors.redAccent : AppColors.primary).withValues(alpha: 0.15);
      } else {
        borderColor = Colors.transparent;
        textColor = AppColors.textMuted;
      }
    } else if (isSelected) {
      borderColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.15);
    }

    return GestureDetector(
      onTap: _hasAnswered
          ? null
          : () {
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
                color: revealed && index == correctIndex
                    ? AppColors.accent.withValues(alpha: 0.2)
                    : AppColors.inputBackground,
                border: Border.all(
                  color: revealed && index == correctIndex
                      ? AppColors.accent
                      : AppColors.cardBorder.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: revealed && index == correctIndex
                    ? const Icon(Icons.check, color: AppColors.accent, size: 16)
                    : Text(
                        String.fromCharCode(65 + index),
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
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
    final connecting = _phase == _DuelPhase.connecting;
    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                      Icon(_patente.icon, color: _patente.color, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_patente.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                            Text(
                              _patente.isMaster
                                  ? 'ELO $_eloRating · ${_wins}W ${_losses}L'
                                  : 'ELO $_eloRating · faltam ${_patente.eloToNext} p/ subir',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, _) => Opacity(
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
                Text(
                  connecting ? 'CONECTANDO...' : 'PROCURANDO OPONENTE...',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  connecting ? 'Preparando sua arena de faíscas' : 'Aguardando outro jogador entrar na fila',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Color(0x33555555),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 28),
                if (_showBotOffer)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Text(
                          'Demorando para achar alguém?',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _startBotMatch,
                          icon: const Icon(Icons.smart_toy_outlined, color: AppColors.gold, size: 18),
                          label: const Text('TREINAR CONTRA BOT', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Treino não vale ranking',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _cancelSearchAndExit,
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
  //  TELA OFFLINE
  // ═══════════════════════════════════════════════════════════
  Widget _buildOfflineScreen() {
    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.error, width: 2),
                    ),
                    child: const Icon(Icons.wifi_off, color: AppColors.error, size: 48),
                  ),
                  const SizedBox(height: 24),
                  const Text('SEM CONEXÃO', style: TextStyle(color: AppColors.error, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  const Text(
                    'O duelo contra jogadores reais precisa de internet. Sem conexão, você pode treinar contra bots — só para praticar, sem valer ranking.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => _startBotMatch(offline: true),
                      icon: const Icon(Icons.smart_toy_outlined, color: AppColors.background),
                      label: const Text('TREINAR OFFLINE', style: TextStyle(color: AppColors.background, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _bootstrap,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('TENTAR CONECTAR', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('VOLTAR AO MENU', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return _buildMessageScreen(
      icon: Icons.error_outline,
      color: AppColors.error,
      title: 'OPS!',
      message: _errorMessage ?? 'Algo deu errado no duelo.',
      primaryLabel: 'TENTAR NOVAMENTE',
      onPrimary: _bootstrap,
    );
  }

  Widget _buildWaitingResultScreen() {
    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, _) => Opacity(
                    opacity: _pulseAnim.value,
                    child: const Icon(Icons.hourglass_top, color: AppColors.gold, size: 56),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('AGUARDANDO OPONENTE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                const Text('Apurando o resultado do duelo...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 24),
                Text('Seu placar: ${_myTotal.toInt()} pts', style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageScreen({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String primaryLabel,
    required VoidCallback onPrimary,
  }) {
    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12),
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Icon(icon, color: color, size: 48),
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: onPrimary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(primaryLabel, style: const TextStyle(color: AppColors.background, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('VOLTAR AO MENU', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
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
    final p1Score = _myTotal;
    final p2Score = _oppTotal;
    // Vencedor é autoritativo do servidor (PvP); no treino vem do cálculo local.
    final won = _winnerId == _uid;
    final draw = _winnerId == null;

    final resultColor = won ? AppColors.primary : (draw ? AppColors.gold : Colors.redAccent);
    final resultIcon = won ? Icons.emoji_events : (draw ? Icons.handshake : Icons.close);
    final resultText = won ? 'VITÓRIA!' : (draw ? 'EMPATE!' : 'DERROTA');

    final p1Correct = _myScores.where((s) => s.isCorrect).length;
    final p2Correct = _oppScores.where((s) => s.isCorrect).length;
    final total = _questions.isEmpty ? 1 : _questions.length;

    return SparksBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: resultColor.withValues(alpha: 0.12),
                        border: Border.all(color: resultColor, width: 3),
                        boxShadow: [
                          BoxShadow(color: resultColor.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 10),
                        ],
                      ),
                      child: Icon(resultIcon, color: resultColor, size: 55),
                    ),
                    const SizedBox(height: 24),
                    Text(resultText, style: TextStyle(color: resultColor, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 3)),
                    const SizedBox(height: 8),
                    Text(
                      _isBot ? 'Partida de treino' : (won ? 'Vitória!' : (draw ? 'Empate!' : 'Não foi dessa vez.')),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    // ELO change (ou aviso de treino)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: resultColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: resultColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_isBot ? Icons.smart_toy_outlined : _patente.icon, color: _isBot ? AppColors.gold : _patente.color, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _isBot
                                ? (_offlineMode ? 'Treino offline — não afeta o ranking' : 'Treino — não afeta o ranking')
                                : 'ELO ${_eloChange >= 0 ? '+' : ''}$_eloChange  ·  ${_patente.label}',
                            style: TextStyle(color: resultColor, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          _buildResultRow('Você', p1Score, p1Correct, total, AppColors.primary, true),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.3))),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('VS', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                ),
                                Expanded(child: Divider(color: AppColors.cardBorder.withValues(alpha: 0.3))),
                              ],
                            ),
                          ),
                          _buildResultRow(_oppName, p2Score, p2Correct, total, AppColors.gold, false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.home, color: AppColors.background),
                        label: const Text('VOLTAR AO MENU', style: TextStyle(color: AppColors.background, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: resultColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _playAgain,
                      child: const Text('JOGAR NOVAMENTE', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _playAgain() {
    _matchSub?.cancel();
    _abandonTimer?.cancel();
    _botOpponentTimer?.cancel();
    setState(() {
      _matchId = null;
      _isBot = false;
      _offlineMode = false;
      _questions = [];
      _myScores.clear();
      _oppScores.clear();
      _currentIndex = 0;
      _selectedOption = -1;
      _hasAnswered = false;
      _opponentAnswered = false;
      _revealCorrect = -1;
      _eloChange = 0;
      _winnerId = null;
      _oppName = 'Oponente';
    });
    _bootstrap();
  }

  Widget _buildResultRow(String name, double score, int correct, int total, Color color, bool isYou) {
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
              Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('$correct/$total acertos', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        Text(
          '${score.toInt()} pts',
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
