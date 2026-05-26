// ─────────────────────────────────────────────────────────────────
//  SPARK ADMIN TRAIL WIZARD
//  Wizard de 4 passos para criação de trilhas com estrutura completa
// ─────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_controller.dart';
import '../../../../theme/app_theme.dart';
import 'spark_admin_widgets.dart';

// ─────────────────────────────────────────────────────────────────
//  TRAIL WIZARD DIALOG
// ─────────────────────────────────────────────────────────────────

class AdminTrailWizardDialog extends ConsumerStatefulWidget {
  final String? categoryId;
  final String? moduleId;

  const AdminTrailWizardDialog({
    this.categoryId,
    this.moduleId,
    super.key,
  });

  @override
  ConsumerState<AdminTrailWizardDialog> createState() => _AdminTrailWizardDialogState();
}

class _AdminTrailWizardDialogState extends ConsumerState<AdminTrailWizardDialog> {
  int _currentStep = 0;

  // Step 0: Configuração básica
  late TextEditingController _titleController;

  // Step 1: Estrutura
  late TextEditingController _numLessonsController;
  late TextEditingController _numEvaluationsController;
  late TextEditingController _questionsPerLessonController;
  late TextEditingController _questionsPerEvaluationController;

  // Step 2: Nomes de lições e avaliações
  late List<TextEditingController> _lessonNameControllers;
  late List<TextEditingController> _evaluationNameControllers;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _numLessonsController = TextEditingController(text: '5');
    _numEvaluationsController = TextEditingController(text: '2');
    _questionsPerLessonController = TextEditingController(text: '5');
    _questionsPerEvaluationController = TextEditingController(text: '10');
    _lessonNameControllers = [];
    _evaluationNameControllers = [];
    _initializeNameControllers();
  }

  void _initializeNameControllers() {
    final numLessons = int.tryParse(_numLessonsController.text) ?? 5;
    final numEvals = int.tryParse(_numEvaluationsController.text) ?? 2;

    _lessonNameControllers = List.generate(
      numLessons,
      (i) => TextEditingController(text: 'Lição ${i + 1}'),
    );

    _evaluationNameControllers = List.generate(
      numEvals,
      (i) => TextEditingController(text: 'Avaliação ${i + 1}'),
    );
  }

  void _updateNameControllers() {
    final numLessons = int.tryParse(_numLessonsController.text) ?? 5;
    final numEvals = int.tryParse(_numEvaluationsController.text) ?? 2;

    // Ajusta lições
    if (_lessonNameControllers.length < numLessons) {
      for (int i = _lessonNameControllers.length; i < numLessons; i++) {
        _lessonNameControllers.add(TextEditingController(text: 'Lição ${i + 1}'));
      }
    } else if (_lessonNameControllers.length > numLessons) {
      for (int i = numLessons; i < _lessonNameControllers.length; i++) {
        _lessonNameControllers[i].dispose();
      }
      _lessonNameControllers = _lessonNameControllers.sublist(0, numLessons);
    }

    // Ajusta avaliações
    if (_evaluationNameControllers.length < numEvals) {
      for (int i = _evaluationNameControllers.length; i < numEvals; i++) {
        _evaluationNameControllers.add(TextEditingController(text: 'Avaliação ${i + 1}'));
      }
    } else if (_evaluationNameControllers.length > numEvals) {
      for (int i = numEvals; i < _evaluationNameControllers.length; i++) {
        _evaluationNameControllers[i].dispose();
      }
      _evaluationNameControllers = _evaluationNameControllers.sublist(0, numEvals);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numLessonsController.dispose();
    _numEvaluationsController.dispose();
    _questionsPerLessonController.dispose();
    _questionsPerEvaluationController.dispose();
    for (var controller in _lessonNameControllers) {
      controller.dispose();
    }
    for (var controller in _evaluationNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Criar Trilha',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: List.generate(4, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: _buildStepContent(),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.card,
                    ),
                    onPressed: _currentStep > 0
                        ? () => setState(() => _currentStep--)
                        : null,
                    child: const Text(
                      'Anterior',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Passo ${_currentStep + 1} de 4',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: _currentStep < 3
                        ? () => setState(() => _currentStep++)
                        : () => _submitWizard(),
                    child: Text(
                      _currentStep < 3 ? 'Próximo' : 'Criar Trilha',
                      style: const TextStyle(color: AppColors.background),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox();
    }
  }

  // ── PASSO 0: Título da Trilha ────────────────────────────────

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passo 1: Informações Básicas',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Título da Trilha',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Ex: Proteção de Linhas de Transmissão',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ],
    );
  }

  // ── PASSO 1: Estrutura ───────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passo 2: Configurar Estrutura',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _buildNumberField(
          label: 'Número de Lições',
          controller: _numLessonsController,
          onChanged: (_) => _updateNameControllers(),
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          label: 'Número de Avaliações',
          controller: _numEvaluationsController,
          onChanged: (_) => _updateNameControllers(),
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          label: 'Questões por Lição',
          controller: _questionsPerLessonController,
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          label: 'Questões por Avaliação',
          controller: _questionsPerEvaluationController,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preview da Estrutura',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '📚 ${_numLessonsController.text} Lições (${_questionsPerLessonController.text} questões cada)',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '✅ ${_numEvaluationsController.text} Avaliações (${_questionsPerEvaluationController.text} questões cada)',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── PASSO 2: Nomes de Lições e Avaliações ───────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passo 3: Personalizar Nomes',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Nomes das Lições',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._lessonNameControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Lição ${index + 1}',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          );
        }),
        const SizedBox(height: 24),
        const Text(
          'Nomes das Avaliações',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._evaluationNameControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Avaliação ${index + 1}',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          );
        }),
      ],
    );
  }

  // ── PASSO 3: Revisão ─────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passo 4: Revisão Final',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _buildReviewItem('Título da Trilha', _titleController.text),
        _buildReviewItem('Número de Lições', _numLessonsController.text),
        _buildReviewItem('Número de Avaliações', _numEvaluationsController.text),
        _buildReviewItem('Questões por Lição', _questionsPerLessonController.text),
        _buildReviewItem('Questões por Avaliação', _questionsPerEvaluationController.text),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '✓ Ao confirmar, a trilha será criada com todas as lições e avaliações. Você poderá editar os detalhes depois.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ],
    );
  }

  void _submitWizard() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira um título para a trilha')),
      );
      return;
    }

    final numLessons = int.tryParse(_numLessonsController.text) ?? 0;
    final numEvaluations = int.tryParse(_numEvaluationsController.text) ?? 0;
    final questionsPerLesson = int.tryParse(_questionsPerLessonController.text) ?? 0;
    final questionsPerEvaluation = int.tryParse(_questionsPerEvaluationController.text) ?? 0;

    if (numLessons <= 0 || numEvaluations <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de lições e avaliações deve ser maior que 0')),
      );
      return;
    }

    ref.read(adminControllerProvider.notifier).generateTrail(
      categoryId: widget.categoryId,
      moduleId: widget.moduleId,
      title: title,
      numLessons: numLessons,
      numEvaluations: numEvaluations,
      questionsPerLesson: questionsPerLesson,
      questionsPerEvaluation: questionsPerEvaluation,
      lessonNames: _lessonNameControllers.map((c) => c.text).toList(),
      evaluationNames: _evaluationNameControllers.map((c) => c.text).toList(),
    );

    Navigator.pop(context);
  }
}
