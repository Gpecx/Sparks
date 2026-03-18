import 'dart:async';
import 'dart:math';
import 'package:spark_app/models/match_models.dart';

/// Serviço Mock que simula um Firebase Realtime Database / WebSocket
/// para o modo Duelo de Faíscas.
class MatchService {
  static final MatchService _instance = MatchService._internal();
  factory MatchService() => _instance;
  MatchService._internal();

  final _random = Random();
  Match? _currentMatch;
  Timer? _opponentTimer;

  // Stream controllers para notificar a UI
  final _matchController = StreamController<Match>.broadcast();
  final _opponentAnsweredController = StreamController<int>.broadcast();

  Stream<Match> get matchStream => _matchController.stream;
  Stream<int> get opponentAnsweredStream => _opponentAnsweredController.stream;
  Match? get currentMatch => _currentMatch;

  /// Banco de perguntas para o duelo
  static const List<DuelQuestion> _questionBank = [
    DuelQuestion(
      question: 'Qual a tensão mínima que exige treinamento NR-10?',
      options: ['12V', '24V', '50V', '110V'],
      correctIndex: 2,
    ),
    DuelQuestion(
      question: 'Qual EPI é obrigatório para trabalho em altura acima de 2m?',
      options: ['Capacete', 'Cinto de segurança', 'Luva isolante', 'Óculos'],
      correctIndex: 1,
    ),
    DuelQuestion(
      question: 'O que significa a sigla EPI?',
      options: [
        'Equipamento de Proteção Individual',
        'Estrutura de Proteção Interna',
        'Equipamento Padrão Industrial',
        'Estrutura Preventiva Integral',
      ],
      correctIndex: 0,
    ),
    DuelQuestion(
      question: 'Qual NR trata de trabalho em altura?',
      options: ['NR-10', 'NR-12', 'NR-33', 'NR-35'],
      correctIndex: 3,
    ),
    DuelQuestion(
      question: 'Qual o primeiro passo ao encontrar um fio desencapado?',
      options: [
        'Isolar a área imediatamente',
        'Tocar para verificar a tensão',
        'Continuar trabalhando',
        'Chamar um colega para ver',
      ],
      correctIndex: 0,
    ),
  ];

  /// Inicia a busca por um oponente (mock: cria sala após 2-4 seg de "espera")
  Future<Match> findMatch(String playerId) async {
    // Simula busca por oponente
    await Future.delayed(Duration(seconds: _random.nextInt(2) + 2));

    final questions = List<DuelQuestion>.from(_questionBank)..shuffle(_random);

    _currentMatch = Match(
      id: 'match_${DateTime.now().millisecondsSinceEpoch}',
      player1Id: playerId,
      player2Id: 'bot_oponente',
      questions: questions.take(5).toList(),
      status: MatchStatus.active,
    );

    _matchController.add(_currentMatch!);
    return _currentMatch!;
  }

  /// Registra a resposta do jogador e simula a resposta do oponente
  void submitAnswer({
    required int questionIndex,
    required int selectedOption,
    required int timeTakenMs,
  }) {
    if (_currentMatch == null) return;
    final q = _currentMatch!.questions[questionIndex];

    // Score do jogador
    _currentMatch!.player1Scores.add(RoundScore(
      playerId: _currentMatch!.player1Id,
      questionIndex: questionIndex,
      isCorrect: selectedOption == q.correctIndex,
      timeTakenMs: timeTakenMs,
    ));

    _matchController.add(_currentMatch!);

    // Simula oponente respondendo com delay aleatório
    _opponentTimer?.cancel();
    final opponentDelay = Duration(milliseconds: _random.nextInt(3000) + 500);
    _opponentTimer = Timer(opponentDelay, () {
      if (_currentMatch == null) return;

      // Bot acerta ~65% das vezes
      final botCorrect = _random.nextDouble() < 0.65;
      final botTime = _random.nextInt(4000) + 1000;

      _currentMatch!.player2Scores.add(RoundScore(
        playerId: _currentMatch!.player2Id,
        questionIndex: questionIndex,
        isCorrect: botCorrect,
        timeTakenMs: botTime,
      ));

      _opponentAnsweredController.add(questionIndex);
      _matchController.add(_currentMatch!);
    });
  }

  /// Notifica que o oponente respondeu antes do jogador (simulação)
  void simulateOpponentFastAnswer(int questionIndex) {
    _opponentAnsweredController.add(questionIndex);
  }

  /// Finaliza a partida
  void finishMatch() {
    if (_currentMatch != null) {
      _currentMatch!.status = MatchStatus.finished;
      _matchController.add(_currentMatch!);
    }
    _opponentTimer?.cancel();
  }

  /// Simula desconexão do oponente
  void simulateDisconnect() {
    if (_currentMatch != null) {
      _currentMatch!.status = MatchStatus.disconnected;
      _matchController.add(_currentMatch!);
    }
    _opponentTimer?.cancel();
  }

  /// Limpa tudo
  void dispose() {
    _opponentTimer?.cancel();
    _currentMatch = null;
  }
}
