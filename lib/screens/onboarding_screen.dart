import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Minigame States
  final Map<String, String> _quizAnswers = {};
  bool _quizCompleted = false;

  List<Map<String, dynamic>> get _pages => [
    {
      'title': AppLocalizations.of(context)!.onbWelcomeTitle,
      'description': AppLocalizations.of(context)!.onbWelcomeDesc,
      'icon': Icons.hub_outlined,
    },
    {
      'title': AppLocalizations.of(context)!.onbEnergyTitle,
      'description': AppLocalizations.of(context)!.onbEnergyDesc,
      'icon': Icons.bolt,
    },
    {
      'title': AppLocalizations.of(context)!.onbRankingTitle,
      'description': AppLocalizations.of(context)!.onbRankingDesc,
      'icon': Icons.emoji_events_outlined,
    },
  ];

  List<Map<String, dynamic>> get _quizQuestions {
    final l = AppLocalizations.of(context)!;
    return [
      {
        'id': 'energy',
        'question': l.onbQ1,
        'options': [l.onbOptSparkPoints, l.onbOptEnergy, l.onbOptStreak, l.onbOptXp],
        'correct': l.onbOptEnergy,
      },
      {
        'id': 'streak',
        'question': l.onbQ2,
        'options': [l.onbOptRanking, l.onbOptClan, l.onbOptStreak, l.onbOptEnergy],
        'correct': l.onbOptStreak,
      },
    ];
  }

  void _nextPage() {
    if (_currentPage < _pages.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      if (_quizCompleted) {
        Navigator.pop(context); // Go back or go to home screen
      } else {
        SparkSnack.error(context, AppLocalizations.of(context)!.onbCompleteMinigame);
      }
    }
  }

  void _answerQuiz(String questionId, String answer) {
    setState(() {
      _quizAnswers[questionId] = answer;
      if (_quizAnswers.length == _quizQuestions.length) {
        // Verifica se todas estão corretas
        bool allCorrect = true;
        for (var q in _quizQuestions) {
          if (_quizAnswers[q['id']] != q['correct']) {
            allCorrect = false;
          }
        }
        if (allCorrect) {
          _quizCompleted = true;
          // Mostra animacao sucesso
        } else {
          // Reseta para tentar novamente
          _quizAnswers.clear();
          SparkSnack.error(context, AppLocalizations.of(context)!.onbWrongAnswers);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SparksBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Progress Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.onbSkip, style: const TextStyle(color: AppColors.textMuted)),
                    ),
                    Row(
                      children: List.generate(_pages.length + 1, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? AppColors.primary : AppColors.cardBorder.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 48), // Spacer for balance
                  ],
                ),
              ),

              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  children: [
                    ..._pages.map((page) => _buildInfoPage(page)),
                    _buildMinigamePage(),
                  ],
                ),
              ),

              // Bottom Button
              Padding(
                padding: const EdgeInsets.all(32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    key: ValueKey('btn_${_currentPage}_$_quizCompleted'),
                    onPressed: _currentPage == _pages.length && !_quizCompleted ? null : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentPage == _pages.length && _quizCompleted 
                          ? AppColors.primary 
                          : (_currentPage == _pages.length ? AppColors.cardBorder : AppColors.primary),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: _currentPage == _pages.length && !_quizCompleted ? 0 : 4,
                    ),
                    child: Text(
                      _currentPage == _pages.length
                          ? (_quizCompleted ? AppLocalizations.of(context)!.onbCompleteEnter : AppLocalizations.of(context)!.onbSolveQuiz)
                          : AppLocalizations.of(context)!.onbNext,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
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

  Widget _buildInfoPage(Map<String, dynamic> page) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(page['icon'], size: 80, color: AppColors.primary),
          ),
          const SizedBox(height: 48),
          Text(
            page['title'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            page['description'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinigamePage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.videogame_asset_outlined, size: 64, color: AppColors.gold),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.onbQuickTest,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.onbQuickTestDesc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          
          if (_quizCompleted)
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, size: 80, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(AppLocalizations.of(context)!.onbCongrats,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            )
          else
            ..._quizQuestions.map((q) => _buildQuizQuestion(q)),
        ],
      ),
    );
  }

  Widget _buildQuizQuestion(Map<String, dynamic> q) {
    String selected = _quizAnswers[q['id']] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            q['question'],
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (q['options'] as List<String>).map((opt) {
              bool isSelected = selected == opt;
              return InkWell(
                onTap: () => _answerQuiz(q['id'], opt),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.inputBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
