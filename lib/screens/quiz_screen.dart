import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/controllers/energy_controller.dart';

class QuizScreen extends StatefulWidget {
  final bool isEvaluation;
  const QuizScreen({super.key, this.isEvaluation = false});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final EnergyController _energyCtrl = EnergyController();
  int _selectedOption = -1;
  bool _hasAnswered = false;
  bool _isCorrect = false;
  int _currentQuestion = 0;
  int _totalCorrect = 0;

  // Banco de perguntas
  final List<Map<String, dynamic>> _questions = [
    {
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
    {
      'module': 'Módulo 2: NR-10',
      'question': 'Qual a tensão mínima que exige treinamento específico de NR-10?',
      'options': [
        '12 Volts',
        '24 Volts',
        '50 Volts',
        '110 Volts',
      ],
      'correct': 2,
      'explanation': 'A NR-10 estabelece que intervenções em instalações elétricas com tensão igual ou superior a 50 Volts em corrente alternada ou superior a 120 Volts em corrente contínua exigem treinamento específico.',
    },
    {
      'module': 'Módulo 2: NR-10',
      'question': 'A cada quantos anos o treinamento de reciclagem da NR-10 deve ser realizado?',
      'options': [
        'A cada 1 ano',
        'A cada 2 anos',
        'A cada 3 anos',
        'A cada 5 anos',
      ],
      'correct': 1,
      'explanation': 'Os trabalhadores autorizados devem receber treinamento de reciclagem bienal (a cada 2 anos) e sempre que houver troca de função ou mudança de empresa.',
    },
    {
      'module': 'Módulo 2: NR-10',
      'question': 'Qual EPI é obrigatório para trabalhos em circuitos energizados?',
      'options': [
        'Capacete de construção civil',
        'Luvas isolantes de borracha classe adequada à tensão',
        'Botas de PVC simples',
        'Óculos de proteção UV',
      ],
      'correct': 1,
      'explanation': 'Para trabalhos em circuitos energizados são obrigatórias as luvas isolantes de borracha (classe adequada à tensão de trabalho), além de outros EPIs especificados conforme a atividade.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _energyCtrl.addListener(_onEnergyChanged);
    // Cobrar energia de entrada
    if (!_energyCtrl.spendEntryEnergy()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOutOfEnergyModal();
      });
    }
  }

  @override
  void dispose() {
    _energyCtrl.removeListener(_onEnergyChanged);
    super.dispose();
  }

  void _onEnergyChanged() {
    if (mounted) setState(() {});
  }

  void _confirmAnswer() {
    if (_selectedOption == -1) return;
    final q = _questions[_currentQuestion];

    setState(() {
      _hasAnswered = true;
      if (_selectedOption == q['correct']) {
        _isCorrect = true;
        _totalCorrect++;
        int bonus = _energyCtrl.registerCorrectAnswer();
        if (bonus > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔥 Streak! +$bonus de energia bônus!'),
              backgroundColor: AppColors.gold,
            ),
          );
        }
      } else {
        _isCorrect = false;
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
      // Quiz concluído — Verifica pontuação
      double score = _totalCorrect / _questions.length;
      bool passed = widget.isEvaluation ? score >= 0.8 : score >= 0.7;

      if (passed) {
        // Concede XP baseado na performance
        int xpEarned = (score * 100).toInt() + (_totalCorrect * 10);
        _energyCtrl.addXp(xpEarned);
        // Exibe feedback de sucesso, então mostra propaganda e retorna true
        _showQuizResultModal(true, score, xpEarned);
      } else {
        // Exibe feedback de falha, não passa adiante
        _showQuizResultModal(false, score, 0);
      }
      return;
    }

    setState(() {
      _currentQuestion++;
      _selectedOption = -1;
      _hasAnswered = false;
      _isCorrect = false;
    });
  }

  // === MODAL DE RESULTADO DO QUIZ ===
  void _showQuizResultModal(bool passed, double score, int xpEarned) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
                  color: passed ? AppColors.primary.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: passed ? AppColors.primary.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  passed ? Icons.emoji_events : Icons.close,
                  size: 50,
                  color: passed ? AppColors.primary : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                passed ? 'Módulo Concluído!' : 'Desempenho Insuficiente',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                passed
                    ? 'Parabéns! Você alcançou ${(score * 100).toInt()}% de acertos e ganhou $xpEarned XP!'
                    : 'Você obteve ${(score * 100).toInt()}%. É necessário no mínimo ${widget.isEvaluation ? '80%' : '70%'} para avançar. Revise o material e tente novamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Fechar Modal
                    if (passed) {
                      _showPowerplayAd(); // Mostrar propaganda antes de sair
                    } else {
                      Navigator.pop(context, false); // Falhou
                    }
                  },
                  icon: Icon(passed ? Icons.play_arrow : Icons.replay, color: AppColors.background),
                  label: Text(
                    passed ? 'CONTINUAR' : 'REFAZER',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
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
                    Navigator.pop(context);
                    Navigator.pop(context, false);
                  },
                  child: const Text('Sair', style: TextStyle(color: AppColors.textMuted)),
                ),
            ],
          ),
        );
      },
    );
  }

  // === MODAL DE ENERGIA ESGOTADA ===
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
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.battery_alert,
                  size: 50,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bateria Esgotada!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Você gastou toda a sua energia nas revisões. Aguarde a recarga automática ou recarregue agora usando seus Pontos Spark na loja.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Recarga rápida com Sparks
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_energyCtrl.rechargeWithSparks()) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('⚡ Energia recarregada!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Pontos Spark insuficientes!'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.bolt, color: AppColors.background),
                  label: Text(
                    'RECARREGAR (${EnergyController.fullRechargeSparkCost} Sparks)',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Ir para a loja
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    Navigator.pushNamed(this.context, '/store');
                  },
                  icon: const Icon(Icons.store, color: AppColors.background),
                  label: const Text(
                    'IR PARA A LOJA',
                    style: TextStyle(
                      color: AppColors.background,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Sair do Quiz',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // === PROPAGANDA POWERPLAY AO CONCLUIR MÓDULO ===
  void _showPowerplayAd() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF061629), Color(0xFF0D2641)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFF00C402).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botão Pular
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, true); // Retorna true informando sucesso na lição
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pular ✕',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Logo Powerplay
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C402), Color(0xFF1D5F31)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C402).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  'POWERPLAY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '🎉 Parabéns pelo módulo!',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Continue aprendendo com vídeos técnicos exclusivos. Experimente grátis por 7 dias!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C402),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, true); // Marca lição como concluída mesmo se ir p/ detail
                      Navigator.pushNamed(context, '/standard-detail');
                    },
                    child: const Text(
                      'TESTE GRÁTIS POR 7 DIAS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentQuestion];
    final progress = (_currentQuestion + 1) / _questions.length;

    // --- CÓDIGO NOVO AQUI: Lógica para descobrir qual ícone de bateria usar ---
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF091E35), Color(0xFF061629)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. HEADER E BARRA DE ENERGIA
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: AppColors.cardBorder,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                            minHeight: 8,
                          ),
                        ),
                      ),
                    ),
                    // Indicador de Energia
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _energyCtrl.hasEnergy
                              ? AppColors.gold.withValues(alpha: 0.4)
                              : Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            batteryIcon, // Usando a variável que criamos lá em cima!
                            color: _energyCtrl.hasEnergy ? AppColors.gold : Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _energyCtrl.energyDisplay,
                            style: TextStyle(
                              color: _energyCtrl.hasEnergy ? AppColors.gold : Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_energyCtrl.isRecharging) ...[
                            const SizedBox(width: 6),
                            Text(
                              _energyCtrl.regenTimeRemaining,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. PERGUNTA
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        q['module'],
                        style: TextStyle(
                          color: AppColors.accent.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pergunta ${_currentQuestion + 1} de ${_questions.length}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q['question'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 3. OPÇÕES DE RESPOSTA
                      ...List.generate((q['options'] as List).length, (index) {
                        return _buildOptionTile(index, q['options'][index], q['correct']);
                      }),
                    ],
                  ),
                ),
              ),

              // 4. ÁREA DE FEEDBACK / BOTÃO INFERIOR
              _buildBottomArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(int index, String text, int correctIndex) {
    bool isSelected = _selectedOption == index;
    
    Color borderColor = AppColors.cardBorder;
    Color bgColor = AppColors.card;
    Color textColor = Colors.white;

    if (_hasAnswered) {
      if (index == correctIndex) {
        borderColor = AppColors.accent;
        bgColor = AppColors.accent.withValues(alpha: 0.15);
      } else if (isSelected && !_isCorrect) {
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
      onTap: _hasAnswered
          ? null
          : () {
              setState(() {
                _selectedOption = index;
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomArea() {
    final q = _questions[_currentQuestion];

    if (!_hasAnswered) {
      bool canConfirm = _selectedOption != -1;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF061629),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canConfirm ? _confirmAnswer : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canConfirm ? AppColors.primary : AppColors.card,
              disabledBackgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'VERIFICAR',
              style: TextStyle(
                color: canConfirm ? Colors.white : AppColors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      );
    }

    Color feedbackColor = _isCorrect ? AppColors.accent : Colors.redAccent;
    IconData feedbackIcon = _isCorrect ? Icons.check_circle : Icons.cancel;
    String feedbackTitle = _isCorrect ? 'Excelente!' : 'Atenção ao detalhe!';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: feedbackColor.withValues(alpha: 0.15),
        border: Border(top: BorderSide(color: feedbackColor, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(feedbackIcon, color: feedbackColor, size: 28),
              const SizedBox(width: 10),
              Text(
                feedbackTitle,
                style: TextStyle(
                  color: feedbackColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!_isCorrect) ...[
            const SizedBox(height: 10),
            Text(
              q['explanation'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: feedbackColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _currentQuestion + 1 >= _questions.length ? 'FINALIZAR' : 'CONTINUAR',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}