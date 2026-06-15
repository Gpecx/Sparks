import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/controllers/energy_controller.dart';
import 'package:spark_app/widgets/spark_emitter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/services/progress_service.dart';
import 'package:spark_app/services/question_service.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/services/covenant_service.dart';
import 'package:spark_app/widgets/streak_lightning_emitter.dart';
import 'package:spark_app/models/quiz_models.dart';
import 'package:spark_app/providers/progress_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final bool isEvaluation;
  final Lesson? lesson; // <-- lição real com questões técnicas
  final String? categoryId;
  final String? moduleId;
  final String? trailId;

  const QuizScreen({
    super.key,
    this.isEvaluation = false,
    this.lesson,
    this.categoryId,
    this.moduleId,
    this.trailId,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> with TickerProviderStateMixin {
  final UserService _userService = UserService();
  final EnergyController _energyCtrl = EnergyController();
  
  // ── VARIÁVEIS DE ESTADO HÍBRIDAS ──
  int _selectedOption = -1; // Para Múltipla Escolha
  List<String?> _draggedSlots = []; // Para Arrastar Palavras
  bool? _swipeAnswer; // Para Verdadeiro/Falso (True = Direita, False = Esquerda)
  
  bool _hasAnswered = false;
  bool _isCorrect = false;
  int _currentQuestion = 0;
  int _totalCorrect = 0;
  bool _isCompleting = false;
  int _currentStreak = 0; // Streak da sessão atual

  // Controladores de animação épica
  late AnimationController _shakeController;
  late AnimationController _epicStreakController;
  late AnimationController _completionController;

  // Estado de carregamento (busca questões do Firestore)
  bool _isLoading = false;
  bool _noQuestionsFound = false; // true quando a lição não tem questões cadastradas

  // ── BANCO DE PERGUNTAS ──
  final List<Map<String, dynamic>> _questions = [
    {
      'type': 'multiple', // Adicionamos o tipo
      'module': 'Módulo 2: NR-10',
      'question': 'De acordo com a NR-10, qual é o requisito obrigatório para intervenções em instalações elétricas energizadas?',
      'options': [
        'Apenas o uso de luvas de borracha simples.',
        'A presença de um técnico de segurança do trabalho em tempo integral.',
        'Trabalhadores qualificados e com treinamentos específicos e atualizados.',
        'Desligamento automático do disjuntor geral em até 5 segundos.',
      ],
      'correct': 2,
      'explanation': 'Segundo a NR-10, as intervenções em instalações elétricas com tensão igual ou superior a 50 Volts só podem ser realizadas por trabalhadores que atendam às exigências de qualificação, capacitação e autorização.',
    },
    {
      'type': 'multiple',
      'module': 'Módulo 2: NR-10',
      'question': 'Qual o principal objetivo da NR-10?',
      'options': [
        'Regular o uso de equipamentos de construção civil.',
        'Estabelecer segurança em instalações e serviços em eletricidade.',
        'Definir normas para trabalho em altura.',
        'Padronizar o uso de EPIs em ambientes de escritório.',
      ],
      'correct': 1,
      'explanation': 'A NR-10 tem como principal objetivo estabelecer os requisitos e condições mínimas para a implementação de medidas de controle e sistemas preventivos de segurança em instalações e serviços em eletricidade.',
    },
    // NOVO DESAFIO: VERDADEIRO OU FALSO (SWIPE)
    {
      'type': 'swipe',
      'module': 'Módulo 2: NR-10',
      'question': 'Verdadeiro ou Falso?',
      'statement': 'Qualquer funcionário da empresa pode acessar a sala de painéis elétricos (subestação), desde que esteja usando capacete de segurança.',
      'answer': false, 
      'explanation': 'Falso! Apenas pessoas advertidas ou profissionais autorizados podem acessar áreas de instalações elétricas restritas.',
    },
    // NOVO DESAFIO: ARRASTAR PALAVRAS (DRAG)
    {
      'type': 'drag',
      'module': 'Módulo 2: NR-10',
      'question': 'Complete a regra fundamental de treinamento da NR-10:',
      'prefix': 'Intervenções acima de',
      'suffix': 'exigem treinamento.',
      'answer': ['50 Volts', 'específico'], 
      'options': ['50 Volts', 'específico', '10 Volts', 'opcional', 'básico'], 
      'explanation': 'A norma define 50V AC ou 120V DC como o limite para obrigatoriedade de treinamento.',
    },
    // SENTENCE BUILDER
    {
      'type': 'sentence_builder',
      'module': 'Módulo 3: NR-35',
      'question': 'Monte a frase correta sobre trabalho em altura:',
      'fragments': [
        {'text': 'O uso de ', 'isGap': false},
        {'text': 'cinto de segurança', 'isGap': true, 'id': 'slot0'},
        {'text': ' é obrigatório em ', 'isGap': false},
        {'text': 'alturas acima de 2m', 'isGap': true, 'id': 'slot1'},
        {'text': '.', 'isGap': false},
      ],
      'options': ['cinto de segurança', 'alturas acima de 2m', 'capacete', 'escadas', 'pisos molhados'],
      'answer': ['cinto de segurança', 'alturas acima de 2m'],
      'explanation': 'Conforme NR-35, trabalho em altura (acima de 2 metros) exige uso obrigatório de cinto de segurança tipo paraquedista.',
    },
    // Q6: Multiple
    {
      'type': 'multiple',
      'module': 'Módulo 2: NR-10',
      'question': 'Qual o EPI essencial para proteção contra choques elétricos?',
      'options': [
        'Luva de vaqueta sem isolamento',
        'Capacete com aba frontal isolante',
        'Óculos de sol comum',
        'Bota de couro com biqueira de aço',
      ],
      'correct': 1,
      'explanation': 'Para trabalhos com eletricidade, o capacete e o calçado devem ser dielétricos (isolantes), sem partes metálicas.',
    },
    // Q7: Swipe
    {
      'type': 'swipe',
      'module': 'Módulo 3: NR-35',
      'question': 'Verdadeiro ou Falso?',
      'statement': 'Um cinto de segurança comum (abdominal) pode ser utilizado para retenção de quedas em trabalhos acima de 2 metros.',
      'answer': false, 
      'explanation': 'Falso! Para retenção de quedas em trabalho em altura, é obrigatório o uso de cinto de segurança tipo paraquedista.',
    },
    // Q8: Drag
    {
      'type': 'drag',
      'module': 'Módulo 2: NR-10',
      'question': 'Complete o princípio básico contra choques:',
      'prefix': 'Toda instalação elétrica deve possuir',
      'suffix': 'de proteção confiável.',
      'answer': ['aterramento'], 
      'options': ['aterramento', 'alerta visual', 'sirene', 'fio neutro'], 
      'explanation': 'O aterramento elétrico é a medida preventiva fundamental contra choques provenientes de falhas de isolamento.',
    },
    // Q9: Sentence Builder
    {
      'type': 'sentence_builder',
      'module': 'Módulo 2: NR-10',
      'question': 'Qual a primeira etapa da Desenergização?',
      'fragments': [
        {'text': 'A primeira etapa é o ', 'isGap': false},
        {'text': 'seccionamento', 'isGap': true, 'id': 'slot0'},
        {'text': ' da rede.', 'isGap': false},
      ],
      'options': ['seccionamento', 'aterramento', 'bloqueio', 'aviso', 'teste'],
      'answer': ['seccionamento'],
      'explanation': 'A sequência correta da desenergização começa sempre pelo seccionamento (desligamento) da fonte de energia.',
    },
    // Q10: Multiple
    {
      'type': 'multiple',
      'module': 'Módulo 3: NR-35',
      'question': 'O que é o Talabarte de Retenção de Queda?',
      'options': [
        'Dispositivo em Y que liga o cinto à ancoragem.',
        'Um mosquetão simples de alpinismo.',
        'A própria corda guia.',
        'O laço abdominal do cinto de segurança.',
      ],
      'correct': 0,
      'explanation': 'O talabarte em Y com absorvedor de energia é o dispositivo utilizado para conectar o cinto do tipo paraquedista ao ponto de ancoragem repetidamente.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _energyCtrl.addListener(_onEnergyChanged);

    // Inicializa animações primeiro
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _epicStreakController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _completionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    if (widget.lesson != null) {
      if (widget.lesson!.questions.isNotEmpty) {
        // Lição local com questões — converte e usa imediatamente
        _questions
          ..clear()
          ..addAll(_convertLessonToQuestions(widget.lesson!));
        _initializeQuestionState();
        _checkEnergy();
      } else if (widget.categoryId != null && widget.moduleId != null && widget.trailId != null) {
        // Lição sem questões locais e com IDs do Firestore — busca do Firestore
        _isLoading = true;
        _loadQuestionsFromFirestore();
      } else {
        // Sem categoria/módulo/trilha — usa banco de mock local (modo demo/standalone)
        _initializeQuestionState();
        _checkEnergy();
      }
    } else {
      // Sem lição real — usa banco de mock local (modo demo/standalone)
      _initializeQuestionState();
      _checkEnergy();
    }
  }

  /// Busca questões da lição no Firestore e popula _questions.
  Future<void> _loadQuestionsFromFirestore() async {
    try {
      final firestoreQuestions = await QuestionService().getQuestions(
        widget.categoryId!,
        widget.moduleId!,
        widget.trailId!,
        widget.lesson!.id,
        limit: 20,
      );

      if (!mounted) return;

      if (firestoreQuestions.items.isNotEmpty) {
        // Pool de termos reais da lição (respostas de outras lacunas) para
        // enriquecer o banco de palavras do minigame preencher lacunas — garante
        // distratores plausíveis mesmo sem o campo `options` na importação.
        final blankPool = <String>{};
        for (final q in firestoreQuestions.items) {
          if (q.type == 'fillInTheBlanks') {
            for (final b in (q.blanks ?? const <Map<String, dynamic>>[])) {
              final a = (b['answer'] as String?)?.trim();
              if (a != null && a.isNotEmpty) blankPool.add(a);
            }
          }
        }
        // Questões encontradas no Firestore — limpa o mock e usa as reais
        _questions
          ..clear()
          ..addAll(firestoreQuestions.items.map((q) => q.toQuizMap(widget.lesson!.title, blankPool: blankPool)));
        setState(() {
          _isLoading = false;
          _noQuestionsFound = false;
        });
        _initializeQuestionState();
        _checkEnergy();
      } else {
        // Nenhuma questão cadastrada nessa lição no Firestore
        debugPrint('[QuizScreen] Nenhuma questão encontrada no Firestore para a lição: ${widget.lesson!.id}');
        setState(() {
          _isLoading = false;
          _noQuestionsFound = true;
        });
      }
    } catch (e) {
      debugPrint('[QuizScreen] Erro ao buscar questões do Firestore: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _noQuestionsFound = true;
      });
    }
  }

  void _checkEnergy() {
    if (!_energyCtrl.spendEntryEnergy()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOutOfEnergyModal();
      });
    }
  }

  /// Converte as questões do modelo [Lesson] para o formato interno da tela.
  List<Map<String, dynamic>> _convertLessonToQuestions(Lesson lesson) {
    final result = <Map<String, dynamic>>[];
    for (final q in lesson.questions) {
      if (q is MultipleChoice) {
        result.add({
          'type': 'multiple',
          'module': lesson.title,
          'question': q.statement,
          'options': q.options,
          'correct': q.correctIndex,
          'explanation': q.explanation,
        });
      } else if (q is TrueFalse) {
        result.add({
          'type': 'swipe',
          'module': lesson.title,
          'question': 'Verdadeiro ou Falso?',
          'statement': q.statement,
          'answer': q.isTrue,
          'explanation': q.explanation,
        });
      } else if (q is FillInTheBlanks) {
        // Minigame preencher lacunas (sentence_builder com chips arrastáveis).
        // Distratores reais: respostas de outras lacunas da mesma lição.
        final pool = <String>{};
        for (final other in lesson.questions) {
          if (other is FillInTheBlanks) {
            for (final b in other.blanks) {
              if (b.answer.trim().isNotEmpty) pool.add(b.answer.trim());
            }
          }
        }
        final text = q.textWithBlanks.trim().isNotEmpty ? q.textWithBlanks : q.statement;
        final answers = q.blanks.map((b) => b.answer.trim()).where((a) => a.isNotEmpty).toList();
        final segments = text.split(RegExp(r'_{4,}'));
        final fragments = <Map<String, dynamic>>[];
        for (var i = 0; i < segments.length; i++) {
          if (segments[i].isNotEmpty) {
            fragments.add({'text': segments[i], 'isGap': false});
          }
          if (i < segments.length - 1 && i < answers.length) {
            fragments.add({'text': answers[i], 'isGap': true, 'id': 'slot$i'});
          }
        }
        final gapCount = fragments.where((f) => f['isGap'] == true).length;
        final usedAnswers = answers.take(gapCount).toList();
        final bank = <String>[...usedAnswers];
        for (final d in pool) {
          if (bank.length >= usedAnswers.length + 3) break;
          if (!bank.contains(d)) bank.add(d);
        }
        bank.shuffle();
        if (usedAnswers.isEmpty) continue;
        result.add({
          'type': 'sentence_builder',
          'module': lesson.title,
          'question': usedAnswers.length > 1
              ? 'Arraste os termos para preencher as lacunas:'
              : 'Arraste o termo para preencher a lacuna:',
          'fragments': fragments,
          'options': bank,
          'answer': usedAnswers,
          'explanation': q.explanation,
        });
      }
    }
    return result;
  }

  // Prepara as variáveis baseadas no tipo da pergunta atual
  void _initializeQuestionState() {
    final q = _questions[_currentQuestion];
    _selectedOption = -1;
    _swipeAnswer = null;
    if (q['type'] == 'drag' || q['type'] == 'sentence_builder') {
      _draggedSlots = List.filled((q['answer'] as List).length, null);
    }
  }

  @override
  void dispose() {
    _energyCtrl.removeListener(_onEnergyChanged);
    _shakeController.dispose();
    _epicStreakController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  void _onEnergyChanged() {
    if (mounted) setState(() {});
  }

  // Lógica unificada para verificar a resposta correta
  void _confirmAnswer() {
    if (_hasAnswered) return;
    
    final q = _questions[_currentQuestion];
    bool correct = false;

    if (q['type'] == 'multiple') {
      if (_selectedOption == -1) return;
      correct = _selectedOption == q['correct'];
    } else if (q['type'] == 'drag' || q['type'] == 'sentence_builder') {
      correct = true;
      for (int i = 0; i < _draggedSlots.length; i++) {
        if (_draggedSlots[i] != q['answer'][i]) {
          correct = false;
          break;
        }
      }
      // Sentence Builder: se errou, devolve as palavras com shake
      if (!correct && q['type'] == 'sentence_builder') {
        HapticFeedback.mediumImpact();
      }
    } else if (q['type'] == 'swipe') {
      correct = _swipeAnswer == q['answer'];
    }

    setState(() {
      _hasAnswered = true;
      _isCorrect = correct;
      if (correct) {
        _totalCorrect++;
        _currentStreak++;
        int bonus = _energyCtrl.registerCorrectAnswer();
        CovenantService().addProgress('cov_precisao', 1);
        
        // PROGRESSIVE ANIMATIONS LOGIC
        if (_currentStreak == 5) {
          // 5 Seguidas: Faíscas + Label
          HapticFeedback.heavyImpact();
          _epicStreakController.forward(from: 0);
        } else if (_currentStreak == 10) {
          // 10 Seguidas: Tela balança, Electrified Streak, +100XP
          HapticFeedback.vibrate();
          _shakeController.forward(from: 0);
          _epicStreakController.forward(from: 0);
          _energyCtrl.addXp(100);
          SparkSnack.reward(context, 'STREAK ÉPICO! +100 XP Bônus!');
        } else if (bonus > 0 && _currentStreak < 5) {
          SparkSnack.reward(context, 'Acerto em sequência! +$bonus energia bônus!');
        }
      } else {
        _currentStreak = 0;
        _energyCtrl.resetStreak();
        _energyCtrl.spendErrorEnergy();
      }
    });
  }

  void _nextQuestion() {
    if (!_energyCtrl.hasEnergy) {
      _showOutOfEnergyModal();
      return;
    }

    if (_currentQuestion + 1 >= _questions.length) {
      _onQuizComplete();
      return;
    }

    setState(() {
      _currentQuestion++;
      _hasAnswered = false;
      _isCorrect = false;
      _initializeQuestionState();
    });
  }

  Future<void> _onQuizComplete() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    final double score = _totalCorrect / _questions.length;
    final bool passed = widget.isEvaluation ? score >= 0.8 : score >= 0.7;
    int xpEarned = 0;

    if (passed) {
      CovenantService().addProgress('cov_conhecimento', 1);
      // XP base
      xpEarned = (score * 100).toInt() + (_totalCorrect * 10);
      final multiplier = _userService.xpMultiplier;
      xpEarned = (xpEarned * multiplier).toInt();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && widget.moduleId != null) {
        final lessonId = widget.lesson?.id ?? 'lesson_${_currentQuestion + 1}';

        // 1. Registrar progresso otimista em memória instantaneamente para a UI destravar
        ref.read(optimisticProgressProvider.notifier).addOptimisticProgress(
          OptimisticProgress(
            categoryId: widget.categoryId ?? '',
            moduleId: widget.moduleId!,
            lessonId: lessonId,
            moduleName: widget.lesson?.title ?? '',
          ),
        );

        // 2. Disparar gravação no Firestore em segundo plano (background)
        // e usar o retorno para saber se o módulo foi completado
        ProgressService().markLessonComplete(
          uid,
          widget.categoryId ?? '',
          widget.moduleId!,
          lessonId,
          xpEarned,
          0, // parâmetro legado (não utilizado)
          moduleName: widget.lesson?.title ?? '',
        ).then((moduleCompleted) {
          // Gravação bem-sucedida
          ref.read(optimisticProgressProvider.notifier).removeOptimisticProgress(
            widget.moduleId!,
            lessonId,
          );
        }).catchError((e) {
          debugPrint('[QuizScreen] Erro ao salvar progresso no Firebase em background: $e');
          ref.read(optimisticProgressProvider.notifier).removeOptimisticProgress(
            widget.moduleId!,
            lessonId,
          );
        });

        // XP: concedido por lição (métrica de progresso de aprendizado)
        Future.microtask(() async {
          try {
            await _userService.addXp(xpEarned).timeout(const Duration(seconds: 15));
          } catch (e) {
            debugPrint('[QuizScreen] Erro ao adicionar XP: $e');
          }
        });

        Future.microtask(() async {
          try {
            await _userService.registerStudyActivity().timeout(const Duration(seconds: 15));
          } catch (e) {
            debugPrint('[QuizScreen] Erro ao registrar atividade de estudo: $e');
          }
        });

        if (_totalCorrect == _questions.length) {
          Future.microtask(() async {
            try {
              await _userService.unlockBadge('queimador').timeout(const Duration(seconds: 10));
            } catch (e) {
              debugPrint('[QuizScreen] Erro ao desbloquear badge queimador: $e');
            }
          });
        }
        if (_currentStreak >= 10) {
          Future.microtask(() async {
            try {
              await _userService.unlockBadge('sniper').timeout(const Duration(seconds: 10));
            } catch (e) {
              debugPrint('[QuizScreen] Erro ao desbloquear badge sniper: $e');
            }
          });
        }
      }

      if (mounted) setState(() => _isCompleting = false);

      // Só depois que o Firestore foi atualizado, mostra a animação
      HapticFeedback.vibrate();
      if (mounted) {
        _completionController.forward(from: 0).then((_) {
          if (mounted) _showQuizResultModal(true, score, xpEarned);
        });
      }
    } else {
      if (mounted) setState(() => _isCompleting = false);
      // Reprovado — mostra modal imediatamente
      if (mounted) _showQuizResultModal(false, score, 0);
    }
  }

  // Constr\u00f3i a mensagem de sucesso baseada no contexto
  String _buildSuccessMessage(double score, int xpEarned) {
    final pct = (score * 100).toInt();
    return 'Parab\u00e9ns! Voc\u00ea alcan\u00e7ou $pct% de acertos e ganhou $xpEarned XP!';
  }

  // === MODAIS ===
  void _showQuizResultModal(bool passed, double score, int xpEarned) {
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (modalCtx, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: passed ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: passed ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  passed ? Icons.bolt : Icons.close,
                  size: 50,
                  color: passed ? Colors.blueAccent : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                passed
                    ? (widget.isEvaluation ? 'Avaliação Aprovada!' : 'Lição concluída!')
                    : 'Desempenho Insuficiente',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                passed
                    ? _buildSuccessMessage(score, xpEarned)
                    : 'Você obteve ${(score * 100).toInt()}%. É necessário no mínimo ${widget.isEvaluation ? '80%' : '70%'} para avançar. Revise o material e tente novamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Cuidado: capturamos o Navigator da tela principal ANTES de fechar o modal
                    final rootNavigator = Navigator.of(context);
                    Navigator.of(modalCtx).pop(); // fecha BottomSheet

                    if (passed) {
                      _showPowerplayAd();
                    } else {
                      rootNavigator.pop(false);
                    }
                  },
                  icon: Icon(passed ? Icons.play_arrow : Icons.replay, color: AppColors.background),
                  label: Text(passed ? 'CONTINUAR' : 'REFAZER', style: const TextStyle(color: AppColors.background, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: passed ? AppColors.primary : Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              if (!passed) const SizedBox(height: 12),
              if (!passed)
                TextButton(
                  onPressed: () {
                    final rootNavigator = Navigator.of(context);
                    Navigator.of(modalCtx).pop(); 
                    rootNavigator.pop(false); 
                  },
                  child: const Text('Sair', style: TextStyle(color: AppColors.textMuted)),
                ),
            ],
          ),
        ),
        );
      },
    );
  }

  void _showOutOfEnergyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 10)]),
                child: const Icon(Icons.battery_alert, size: 50, color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              const Text('Bateria Esgotada!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('Você gastou toda a sua energia. Aguarde a recarga automática (5 min por unidade) ou assine um plano para ter bateria infinita ∞.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    context.push('/store');
                  },
                  icon: const Icon(Icons.all_inclusive, color: AppColors.background),
                  label: const Text('VER PLANOS COM BATERIA ∞', style: TextStyle(color: AppColors.background, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Sair do Quiz', style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showPowerplayAd() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [AppColors.background, AppColors.card], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () {
                      final rootNavigator = Navigator.of(context);
                      Navigator.of(dialogCtx).pop(); // Fecha dialog
                      rootNavigator.pop(true);       // Fecha o Quiz
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Pular ✕', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cardBorder]),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4)],
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('POWERPLAY', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text('Parabens pelo modulo!', style: TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Text('Continue aprendendo com vídeos técnicos exclusivos. Experimente grátis por 7 dias!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      final rootNavigator = Navigator.of(context);
                      final rootRouter = GoRouter.of(context);
                      Navigator.of(dialogCtx).pop();
                      rootNavigator.pop(true);
                      rootRouter.push('/standard-detail');
                    },
                    child: const Text('TESTE GRÁTIS POR 7 DIAS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExitConfirmationModal() {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B14).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.15),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.error.withValues(alpha: 0.3),
                                    AppColors.error.withValues(alpha: 0.05),
                                  ],
                                ),
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 36),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Tem certeza?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Você vai perder todo seu progresso na lição se sair.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(ctx),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                      ),
                                      child: const Text(
                                        'CANCELAR',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [AppColors.error, Color(0xFFEF4444)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.error.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'SAIR',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ), // Column
                      ), // Material
                    ), // Container
                  ), // BackdropFilter
                ), // ClipRRect
              ), // Padding
            ), // Center
          ), // FadeTransition
        ); // SlideTransition
      },
    );
  }

  // === UI PRINCIPAL DA TELA ===
  @override
  Widget build(BuildContext context) {
    // Exibe tela de erro se nenhuma questão foi encontrada no Firestore
    if (_noQuestionsFound) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [AppColors.surface, AppColors.background],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 8)],
                  ),
                  child: const Icon(Icons.quiz_outlined, size: 44, color: AppColors.error),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Nenhuma questão cadastrada',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Esta lição ainda não possui questões cadastradas no sistema. '
                    'Por favor, entre em contato com o administrador.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.arrow_back, color: AppColors.background),
                    label: const Text('VOLTAR', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Exibe spinner enquanto busca questões do Firestore
    if (_isLoading || _questions.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [AppColors.surface, AppColors.background],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Carregando questões...',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = _questions[_currentQuestion];
    final progress = (_currentQuestion + 1) / _questions.length;

    IconData batteryIcon;
    final ratio = _energyCtrl.energy / EnergyController.maxEnergy;
    if (_energyCtrl.isPremiumUser) { batteryIcon = Icons.all_inclusive; }
    else if (ratio >= 0.7) { batteryIcon = Icons.battery_full; }
    else if (ratio >= 0.4) { batteryIcon = Icons.battery_4_bar; }
    else if (ratio >= 0.2) { batteryIcon = Icons.battery_2_bar; }
    else { batteryIcon = Icons.battery_alert; }

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_shakeController, _completionController, _epicStreakController]),
        builder: (context, child) {
          // Shake effect for 10x streak
          double dx = 0;
          if (_shakeController.isAnimating) {
            dx = 15 * (0.5 - (0.5 - _shakeController.value).abs()) * (DateTime.now().millisecond % 2 == 0 ? 1 : -1);
          }

          return Stack(
            children: [
              Transform.translate(
                offset: Offset(dx, 0),
                child: Container(
                  decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment.center, radius: 1.2, colors: [AppColors.surface, AppColors.background])),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // 1. HEADER E BARRA DE ENERGIA
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              GestureDetector(onTap: _showExitConfirmationModal, child: const Icon(Icons.close, color: Colors.white, size: 28)),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                                    child: LinearProgressIndicator(value: progress, backgroundColor: AppColors.cardBorder, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent), minHeight: 8),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _energyCtrl.hasEnergy ? AppColors.gold.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.5))),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(batteryIcon, color: _energyCtrl.hasEnergy ? AppColors.gold : Colors.redAccent, size: 20),
                                    const SizedBox(width: 4),
                                    Text(_energyCtrl.energyDisplay, style: TextStyle(color: _energyCtrl.hasEnergy ? AppColors.gold : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w700)),
                                    if (_energyCtrl.isRecharging) ...[
                                      const SizedBox(width: 6),
                                      Text(_energyCtrl.regenTimeRemaining, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 2. CORPO DA PERGUNTA (MÚLTIPLA ESCOLHA, DRAG OU SWIPE)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                Text(q['module'], style: TextStyle(color: AppColors.accent.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                                const SizedBox(height: 4),
                                Text('Pergunta ${_currentQuestion + 1} de ${_questions.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                const SizedBox(height: 12),
                                Text(q['question'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.4)),
                                const SizedBox(height: 30),

                                // --- CONDICIONAL DA MECÂNICA ---
                                if (q['type'] == 'multiple')
                                  ...List.generate((q['options'] as List).length, (index) {
                                    return _buildOptionTile(index, q['options'][index], q['correct']);
                                  })
                                else if (q['type'] == 'drag')
                                  _buildDragChallenge(q)
                                else if (q['type'] == 'sentence_builder')
                                  _buildSentenceBuilderChallenge(q)
                                else if (q['type'] == 'swipe')
                                  _buildSwipeChallenge(q),
                              ],
                            ),
                          ),
                        ),

                        // 3. ÁREA DE FEEDBACK / BOTÃO INFERIOR
                        _buildBottomArea(),
                      ],
                    ),
                  ),
                ),
              ),

              // CELEBRATION OVERLAYS
              Positioned.fill(
                child: StreakLightningEmitter(
                  trigger: _epicStreakController.isAnimating,
                  streakCount: _currentStreak,
                ),
              ),

              if (_completionController.isAnimating)
                Container(
                  color: Colors.blueAccent.withValues(alpha: 0.3 * (1.0 - _completionController.value)),
                  child: Center(
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
                        CurvedAnimation(parent: _completionController, curve: Curves.elasticOut)
                      ),
                      child: Icon(Icons.bolt, color: Colors.blueAccent, size: 200 + (50 * _completionController.value)),
                    ),
                  ),
                ),
              
              // Emissor de Faíscas de Acerto (pequenas faíscas nativas para acertos básicos)
              Positioned.fill(
                child: SparkEmitter(trigger: _hasAnswered && _isCorrect),
              ),
            ],
          );
        }
      ),
    );
  }

  // ── WIDGETS DE MÚLTIPLA ESCOLHA ──
  Widget _buildOptionTile(int index, String text, int correctIndex) {
    bool isSelected = _selectedOption == index;
    Color borderColor = AppColors.cardBorder;
    Color bgColor = AppColors.card;
    Color textColor = Colors.white;

    if (_hasAnswered) {
      if (index == correctIndex) {
        borderColor = AppColors.accent; bgColor = AppColors.accent.withValues(alpha: 0.15);
      } else if (isSelected && !_isCorrect) {
        borderColor = Colors.redAccent; bgColor = Colors.redAccent.withValues(alpha: 0.15);
      } else {
        borderColor = Colors.transparent; textColor = AppColors.textMuted;
      }
    } else if (isSelected) {
      borderColor = AppColors.primary; bgColor = AppColors.primary.withValues(alpha: 0.15);
    }

    return GestureDetector(
      onTap: _hasAnswered ? null : () => setState(() => _selectedOption = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor, width: 2)),
        child: Row(children: [Expanded(child: Text(text, style: TextStyle(color: textColor, fontSize: 16, height: 1.4, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)))]),
      ),
    );
  }

  // ── WIDGETS DE ARRASTAR (DRAG) ──
  Widget _buildDragChallenge(Map<String, dynamic> q) {
    return Column(
      children: [
        Wrap(
          spacing: 8, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(q['prefix'], style: const TextStyle(color: Colors.white, fontSize: 18)),
            ...List.generate(_draggedSlots.length, (index) => _buildTargetSlot(index)),
            Text(q['suffix'], style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 40),
        if (!_hasAnswered)
          Wrap(
            spacing: 10, runSpacing: 10,
            children: (q['options'] as List<String>).map((word) {
              return _draggedSlots.contains(word) ? _buildEmptyChip() : _buildDraggableWord(word);
            }).toList(),
          ),
      ],
    );
  }

  // ── SENTENCE BUILDER ──
  Widget _buildSentenceBuilderChallenge(Map<String, dynamic> q) {
    final fragments = q['fragments'] as List;
    int gapIndex = 0;

    return Column(
      children: [
        // Frase com lacunas
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: fragments.map<Widget>((frag) {
              if (frag['isGap'] == true) {
                final idx = gapIndex++;
                return _buildTargetSlot(idx);
              } else {
                return Text(
                  frag['text'],
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, height: 1.6),
                );
              }
            }).toList(),
          ),
        ),
        const SizedBox(height: 30),
        // Chips arrastáveis
        if (!_hasAnswered)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: (q['options'] as List<String>).map((word) {
              return _draggedSlots.contains(word) ? _buildEmptyChip() : _buildDraggableWord(word);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTargetSlot(int index) {
    String? word = _draggedSlots[index];
    return DragTarget<String>(
      builder: (context, candidate, rejected) {
        return GestureDetector(
          onTap: () {
            // Tocar numa palavra já colocada a remove do slot
            if (word != null && !_hasAnswered) {
              setState(() => _draggedSlots[index] = null);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            constraints: const BoxConstraints(minWidth: 80, minHeight: 45),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: word == null ? AppColors.card : AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: candidate.isNotEmpty
                    ? AppColors.primary
                    : word != null
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.cardBorder,
                width: 2,
              ),
              boxShadow: candidate.isNotEmpty
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10)]
                  : null,
            ),
            child: Center(
              child: Text(
                word ?? '________',
                style: TextStyle(
                  color: word == null ? AppColors.textMuted : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
      onAcceptWithDetails: (details) {
        if (!_hasAnswered) {
          setState(() => _draggedSlots[index] = details.data);
          HapticFeedback.selectionClick();
        }
      },
    );
  }

  Widget _buildDraggableWord(String word) {
    return Draggable<String>(
      data: word,
      feedback: Material(color: Colors.transparent, child: _chip(word, glow: true)),
      childWhenDragging: Opacity(opacity: 0.3, child: _chip(word)),
      child: _chip(word),
    );
  }

  Widget _chip(String label, {bool glow = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder),
        boxShadow: glow ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 15)] : null,
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildEmptyChip() => Container(
    constraints: const BoxConstraints(minWidth: 80, minHeight: 40),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.2)),
    ),
  );

  // ── WIDGET DE DESLIZAR (SWIPE) ESTILO TINDER ──
  Widget _buildSwipeChallenge(Map<String, dynamic> q) {
    if (_swipeAnswer != null) {
      bool isTrue = _swipeAnswer == true;
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: isTrue ? AppColors.primary.withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16), border: Border.all(color: isTrue ? AppColors.primary : Colors.redAccent, width: 2),
        ),
        child: Column(
          children: [
            Icon(isTrue ? Icons.check_circle : Icons.cancel, color: isTrue ? AppColors.primary : Colors.redAccent, size: 60),
            const SizedBox(height: 10),
            Text(isTrue ? 'VERDADEIRO' : 'FALSO', style: TextStyle(color: isTrue ? AppColors.primary : Colors.redAccent, fontSize: 24, fontWeight: FontWeight.w800)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back, color: Colors.redAccent.withValues(alpha: 0.6), size: 16),
            const SizedBox(width: 6),
            Text('FALSO', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(width: 24),
            Text('VERDADEIRO', style: TextStyle(color: AppColors.primary.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward, color: AppColors.primary.withValues(alpha: 0.6), size: 16),
          ],
        ),
        const SizedBox(height: 16),
        _SwipeTinderCard(
          key: ValueKey(_currentQuestion),
          statement: (q['options'] != null && (q['options'] as List).isNotEmpty) 
              ? q['options'][0] 
              : 'Sem enunciado',
          onSwiped: (bool isRight) {
            HapticFeedback.mediumImpact();
            setState(() {
              _swipeAnswer = isRight;
            });
            _confirmAnswer();
          },
        ),
      ],
    );
  }

  // ── RODAPÉ ──
  Widget _buildBottomArea() {
    final q = _questions[_currentQuestion];

    if (!_hasAnswered) {
      bool canConfirm = false;
      if (q['type'] == 'multiple') canConfirm = _selectedOption != -1;
      if (q['type'] == 'drag' || q['type'] == 'sentence_builder') canConfirm = !_draggedSlots.contains(null);
      if (q['type'] == 'swipe') return const SizedBox.shrink(); // Swipe não tem botão Verificar

      return Container(
        padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.cardBorder))),
        child: SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: canConfirm ? _confirmAnswer : null,
            style: ElevatedButton.styleFrom(backgroundColor: canConfirm ? AppColors.primary : AppColors.card, disabledBackgroundColor: AppColors.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: Text('VERIFICAR', style: TextStyle(color: canConfirm ? Colors.white : AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ),
      );
    }

    Color feedbackColor = _isCorrect ? AppColors.accent : Colors.redAccent;
    IconData feedbackIcon = _isCorrect ? Icons.check_circle : Icons.cancel;
    String feedbackTitle = _isCorrect ? 'Excelente!' : 'Atenção ao detalhe!';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: feedbackColor.withValues(alpha: 0.15), border: Border(top: BorderSide(color: feedbackColor, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(feedbackIcon, color: feedbackColor, size: 28), const SizedBox(width: 10), Text(feedbackTitle, style: TextStyle(color: feedbackColor, fontSize: 20, fontWeight: FontWeight.w700))]),
          if (!_isCorrect) ...[const SizedBox(height: 10), Text(q['explanation'], style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isCompleting ? null : _nextQuestion,
              style: ElevatedButton.styleFrom(backgroundColor: feedbackColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _isCompleting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_currentQuestion + 1 >= _questions.length ? 'FINALIZAR' : 'CONTINUAR', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  WIDGET SWIPE TINDER COM ROTAÇÃO E OVERLAY VERDE/VERMELHO
// ═══════════════════════════════════════════════════════════
class _SwipeTinderCard extends StatefulWidget {
  final String statement;
  final void Function(bool isRight) onSwiped;

  const _SwipeTinderCard({
    super.key,
    required this.statement,
    required this.onSwiped,
  });

  @override
  State<_SwipeTinderCard> createState() => _SwipeTinderCardState();
}

class _SwipeTinderCardState extends State<_SwipeTinderCard> {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  static const double _swipeThreshold = 100.0;

  double get _rotation => (_dragOffset.dx / 300).clamp(-0.3, 0.3);
  double get _swipeProgress => (_dragOffset.dx.abs() / _swipeThreshold).clamp(0, 1);
  bool get _isSwipingRight => _dragOffset.dx > 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => setState(() => _isDragging = true),
      onPanUpdate: (details) {
        setState(() => _dragOffset += details.delta);
      },
      onPanEnd: (_) {
        if (_dragOffset.dx.abs() > _swipeThreshold) {
          widget.onSwiped(_isSwipingRight);
        } else {
          setState(() {
            _dragOffset = Offset.zero;
            _isDragging = false;
          });
        }
      },
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: _rotation,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  widget.statement,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.5, fontWeight: FontWeight.w600),
                ),
              ),
              // Overlay de feedback visual (verde/vermelho)
              if (_isDragging && _swipeProgress > 0.1)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _isSwipingRight
                          ? AppColors.primary.withValues(alpha: _swipeProgress * 0.25)
                          : Colors.redAccent.withValues(alpha: _swipeProgress * 0.25),
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: _swipeProgress,
                        child: Icon(
                          _isSwipingRight ? Icons.check_circle : Icons.cancel,
                          color: _isSwipingRight ? AppColors.primary : Colors.redAccent,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}