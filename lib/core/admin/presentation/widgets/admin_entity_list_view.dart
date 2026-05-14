import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/core/admin/presentation/admin_controller.dart';
import 'package:spark_app/core/admin/presentation/widgets/admin_entity_form.dart';
import 'package:spark_app/core/admin/presentation/widgets/admin_parent_selector_dialog.dart';
import 'package:spark_app/core/admin/presentation/widgets/admin_trail_wizard_dialog.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ENTITY LIST VIEW — Lista genérica para qualquer entidade admin
// ─────────────────────────────────────────────────────────────────

class AdminEntityListView extends ConsumerWidget {
  final AdminEntity entity;
  final List<FieldConfig> fields;
  final String Function(Map<String, dynamic> data) titleExtractor;
  final String Function(Map<String, dynamic> data)? subtitleExtractor;

  /// Chamado após criar uma entidade para navegação guiada (opcional)
  final void Function(String docId, Map<String, dynamic> data)? onAfterCreate;

  const AdminEntityListView({
    super.key,
    required this.entity,
    required this.fields,
    required this.titleExtractor,
    this.subtitleExtractor,
    this.onAfterCreate,
  });

  // ── Abre o wizard de trilha ──────────────────────────────────────
  Future<void> _openTrailWizard(
    BuildContext context, {
    String? preselectedCategoryId,
    String? preselectedModuleId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AdminTrailWizardDialog(
        categoryId: preselectedCategoryId,
        moduleId: preselectedModuleId,
      ),
    );

    if (result == true && context.mounted) {
      showDialog(
        context: context,
        builder: (_) => const AdminSuccessDialog(),
      );
    }
  }

  // ── Lógica do FAB — abre seletor de pai depois abre form/wizard ──
  Future<void> _onFabPressed(BuildContext context, WidgetRef ref) async {
    switch (entity) {
      // Categoria: sem pai, abre direto o form
      case AdminEntity.categories:
        await _openForm(context, ref);

      // Módulo: seleciona categoria antes
      case AdminEntity.modules:
        final sel = await _showParentSelector(
          context,
          title: 'Novo Módulo',
          levels: ['category'],
        );
        if (sel == null || !context.mounted) return;
        await _openForm(
          context,
          ref,
          initialValues: {'categoryId': sel.categoryId ?? ''},
        );

      // Trilha: abre o wizard (já tem seletor interno)
      case AdminEntity.trails:
        await _openTrailWizard(context);

      // Lição: seleciona cat → mod → trilha antes
      case AdminEntity.lessons:
        final sel = await _showParentSelector(
          context,
          title: 'Nova Lição',
          levels: ['category', 'module', 'trail'],
        );
        if (sel == null || !context.mounted) return;
        await _openForm(
          context,
          ref,
          initialValues: {
            '_categoryId': sel.categoryId ?? '',
            '_moduleId': sel.moduleId ?? '',
            'trailId': sel.trailId ?? '',
          },
        );

      // Questão: seleciona cat → mod → trilha → lição antes
      case AdminEntity.questions:
        final sel = await _showParentSelector(
          context,
          title: 'Nova Questão',
          levels: ['category', 'module', 'trail', 'lesson'],
        );
        if (sel == null || !context.mounted) return;
        await _openForm(
          context,
          ref,
          initialValues: {
            '_categoryId': sel.categoryId ?? '',
            '_moduleId': sel.moduleId ?? '',
            '_trailId': sel.trailId ?? '',
            'lessonId': sel.lessonId ?? '',
          },
        );
    }
  }

  // ── Abre o seletor de pai ────────────────────────────────────────
  Future<ParentSelection?> _showParentSelector(
    BuildContext context, {
    required String title,
    required List<String> levels,
  }) {
    return showDialog<ParentSelection>(
      context: context,
      builder: (_) => AdminParentSelectorDialog(
        title: title,
        levels: levels,
      ),
    );
  }

  // ── Abre o form genérico ─────────────────────────────────────────
  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    String? docId,
    Map<String, dynamic>? existing,
    Map<String, String> initialValues = const {},
  }) async {
    final ctrl = ref.read(adminControllerProvider.notifier);

    final merged = <String, String>{
      ...initialValues,
      ...(existing?.map((k, v) => MapEntry(k, v?.toString() ?? '')) ?? {}),
    };

    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => AdminEntityForm(
        title: docId == null ? 'Novo ${entity.label}' : 'Editar ${entity.label}',
        fields: fields,
        initialValues: merged,
        onSave: (data) async {
          if (docId == null) {
            return ctrl.create(entity, data);
          } else {
            await ctrl.update(entity, docId, data);
            return '';
          }
        },
      ),
    );

    if (!context.mounted) return;

    // result é o docId (String) ou true para edição
    if (result != null && result != false) {
      final newDocId = result is String ? result : '';
      if (docId == null && onAfterCreate != null) {
        onAfterCreate!(newDocId, existing ?? {});
        return;
      }
      showDialog(
        context: context,
        builder: (_) => const AdminSuccessDialog(),
      );
    }
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String docId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Confirmar exclusão',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Deseja remover este item de ${entity.label}? Esta ação não pode ser desfeita.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCELAR',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(adminControllerProvider.notifier).delete(entity, docId);
              Navigator.of(context).pop();
            },
            child: const Text('EXCLUIR',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(adminControllerProvider.notifier);

    ref.listen(adminControllerProvider, (prev, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        controller.clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: controller.streamFor(entity),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum item em ${entity.label}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use o botão + para adicionar o primeiro.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, idx) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.4)),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    titleExtractor(data),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: subtitleExtractor != null
                      ? Text(
                          subtitleExtractor!(data),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      (titleExtractor(data).isNotEmpty
                              ? titleExtractor(data)[0]
                              : '?')
                          .toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.blue, size: 20),
                        onPressed: () => _openForm(context, ref,
                            docId: doc.id, existing: data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error, size: 20),
                        onPressed: () =>
                            _confirmDelete(context, ref, doc.id, data),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onFabPressed(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: entity == AdminEntity.trails
            ? const Icon(Icons.map_outlined)
            : const Icon(Icons.add),
        label: Text(entity == AdminEntity.trails
            ? 'Nova Trilha'
            : 'Novo ${entity.label.split('/').first}'),
      ),
    );
  }
}
