import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../../constants/fs.dart'; // Para acessar FS.title
import '../admin_controller.dart';

// --- ORQUESTRADOR DO WIZARD ---
Future<void> startCreationWizard(BuildContext context, WidgetRef ref) async {
  // 1. Modal Categoria
  final catResult = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _CategoryStepDialog(),
  );
  if (catResult == null) return; 

  // 2. Modal Módulo
  if (context.mounted) {
    ref.read(adminControllerProvider.notifier).selectCategory(catResult);
    
    final modResult = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ModuleStepDialog(),
    );
    if (modResult == null) return; 

    // 3. Modal Trilha (Gerador)
    if (context.mounted) {
      ref.read(adminControllerProvider.notifier).selectModule(modResult);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _TrailGeneratorStepDialog(),
      );
    }
  }
}

// --- CATEGORIA ---
class _CategoryStepDialog extends ConsumerWidget {
  const _CategoryStepDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final isLoading = ref.watch(adminControllerProvider).isLoading;

    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Passo 1: Nova Categoria', style: TextStyle(color: AppColors.primary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Título')),
          TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Descrição')),
        ],
      ),
      actions: [
        if (!isLoading) TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: isLoading ? null : () async {
            final id = await ref.read(adminControllerProvider.notifier).create(AdminEntity.categories, {
              FS.title: titleCtrl.text,
              'description': descCtrl.text,
            });
            if (id != null && context.mounted) Navigator.pop(context, id);
          },
          child: isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
            : const Text('Próximo', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// --- MÓDULO ---
class _ModuleStepDialog extends ConsumerWidget {
  const _ModuleStepDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final isLoading = ref.watch(adminControllerProvider).isLoading;

    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Passo 2: Novo Módulo', style: TextStyle(color: Colors.blue)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Título do Módulo')),
        ],
      ),
      actions: [
        if (!isLoading) TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          onPressed: isLoading ? null : () async {
            final id = await ref.read(adminControllerProvider.notifier).create(AdminEntity.modules, {
              FS.title: titleCtrl.text,
            });
            if (id != null && context.mounted) Navigator.pop(context, id);
          },
          child: isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
            : const Text('Próximo', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// --- TRILHA (GERADOR DE ESQUELETO) ---
class _TrailGeneratorStepDialog extends ConsumerWidget {
  const _TrailGeneratorStepDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final lessonsCtrl = TextEditingController(text: '4');
    final quizzesCtrl = TextEditingController(text: '1');
    final questionsCtrl = TextEditingController(text: '5');
    final isLoading = ref.watch(adminControllerProvider).isLoading;

    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Passo 3: Gerar Trilha', style: TextStyle(color: Colors.orange)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('Isso criará automaticamente os rascunhos das lições e avaliações.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
             const SizedBox(height: 16),
             TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nome da Trilha Principal')),
             const SizedBox(height: 16),
             Row(
               children: [
                 Expanded(child: TextField(controller: lessonsCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Qtd. Lições'))),
                 const SizedBox(width: 16),
                 Expanded(child: TextField(controller: quizzesCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Qtd. Avaliações'))),
               ],
             ),
             const SizedBox(height: 16),
             TextField(controller: questionsCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Questões por Avaliação')),
          ],
        ),
      ),
      actions: [
        if (!isLoading) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: isLoading ? null : () async {
            final success = await ref.read(adminControllerProvider.notifier).generateTrail(
              title: titleCtrl.text,
              numLessons: int.tryParse(lessonsCtrl.text) ?? 0,
              numEvaluations: int.tryParse(quizzesCtrl.text) ?? 0,
              questionsPerLesson: 0, // Ajuste se quiser questões nas lições comuns
              questionsPerEvaluation: int.tryParse(questionsCtrl.text) ?? 0,
            );
            if (success && context.mounted) Navigator.pop(context);
          },
          child: isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Gerar Esqueleto', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}