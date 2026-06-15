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

class AdminEntityListView extends ConsumerStatefulWidget {
  final AdminEntity entity;
  final List<FieldConfig> fields;
  final String Function(Map<String, dynamic> data) titleExtractor;
  final String Function(Map<String, dynamic> data)? subtitleExtractor;
  final void Function(String docId, Map<String, dynamic> data)? onAfterCreate;

  const AdminEntityListView({
    super.key,
    required this.entity,
    required this.fields,
    required this.titleExtractor,
    this.subtitleExtractor,
    this.onAfterCreate,
  });

  @override
  ConsumerState<AdminEntityListView> createState() =>
      _AdminEntityListViewState();
}

class _AdminEntityListViewState extends ConsumerState<AdminEntityListView> {
  bool _reorderMode = false;
  List<QueryDocumentSnapshot>? _localDocs;

  void _enterReorderMode(List<QueryDocumentSnapshot> docs) {
    setState(() {
      _reorderMode = true;
      _localDocs = List.from(docs);
    });
  }

  void _cancelReorderMode() {
    setState(() {
      _reorderMode = false;
      _localDocs = null;
    });
  }

  Future<void> _saveOrder() async {
    if (_localDocs == null) return;
    final ids = _localDocs!.map((d) => d.id).toList();
    await ref
        .read(adminControllerProvider.notifier)
        .reorderItems(widget.entity, ids);
    if (mounted) {
      setState(() {
        _reorderMode = false;
        _localDocs = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ordem salva com sucesso!'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

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

  Future<void> _onFabPressed(BuildContext context) async {
    switch (widget.entity) {
      case AdminEntity.categories:
        await _openForm(context);

      case AdminEntity.modules:
        final sel = await _showParentSelector(
          context,
          title: 'Novo Módulo',
          levels: ['category'],
        );
        if (sel == null || !context.mounted) return;
        await _openForm(
          context,
          initialValues: {'categoryId': sel.categoryId ?? ''},
        );

      case AdminEntity.trails:
        await _openTrailWizard(context);

      case AdminEntity.lessons:
        final sel = await _showParentSelector(
          context,
          title: 'Nova Lição',
          levels: ['category', 'module', 'trail'],
        );
        if (sel == null || !context.mounted) return;
        await _openForm(
          context,
          initialValues: {
            '_categoryId': sel.categoryId ?? '',
            '_moduleId': sel.moduleId ?? '',
            'trailId': sel.trailId ?? '',
          },
        );

      case AdminEntity.questions:
        final sel = await _showParentSelector(
          context,
          title: 'Nova Questão',
          levels: ['category', 'module', 'trail', 'lesson'],
        );
        if (sel == null || !context.mounted) return;
        await _openForm(
          context,
          initialValues: {
            '_categoryId': sel.categoryId ?? '',
            '_moduleId': sel.moduleId ?? '',
            '_trailId': sel.trailId ?? '',
            'lessonId': sel.lessonId ?? '',
          },
        );
    }
  }

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

  Future<void> _openForm(
    BuildContext context, {
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
        title: docId == null
            ? 'Novo ${widget.entity.label}'
            : 'Editar ${widget.entity.label}',
        fields: widget.fields,
        initialValues: merged,
        onSave: (data) async {
          if (docId == null) {
            return ctrl.create(widget.entity, data);
          } else {
            await ctrl.update(widget.entity, docId, data);
            return '';
          }
        },
      ),
    );

    if (!context.mounted) return;

    if (result != null && result != false) {
      final newDocId = result is String ? result : '';
      if (docId == null && widget.onAfterCreate != null) {
        widget.onAfterCreate!(newDocId, existing ?? {});
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
          'Deseja remover este item de ${widget.entity.label}? Esta ação não pode ser desfeita.',
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
              ref
                  .read(adminControllerProvider.notifier)
                  .delete(widget.entity, docId);
              Navigator.of(context).pop();
            },
            child:
                const Text('EXCLUIR', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    QueryDocumentSnapshot doc, {
    bool showDragHandle = false,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      key: ValueKey(doc.id),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showDragHandle
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.cardBorder.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          widget.titleExtractor(data),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: widget.subtitleExtractor != null
            ? Text(
                widget.subtitleExtractor!(data),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        leading: showDragHandle
            ? const Icon(Icons.drag_handle,
                color: AppColors.primary, size: 24)
            : CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  (widget.titleExtractor(data).isNotEmpty
                          ? widget.titleExtractor(data)[0]
                          : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700),
                ),
              ),
        trailing: showDragHandle
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.blue, size: 20),
                    onPressed: () =>
                        _openForm(context, docId: doc.id, existing: data),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error, size: 20),
                    onPressed: () =>
                        _confirmDelete(context, doc.id, data),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        stream: controller.streamFor(widget.entity),
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              _localDocs == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final streamDocs =
              snapshot.data?.docs.cast<QueryDocumentSnapshot>() ?? [];

          // Atualiza docs locais somente fora do modo reordenação
          if (!_reorderMode) {
            _localDocs = null;
          }

          final docs = _reorderMode ? (_localDocs ?? streamDocs) : streamDocs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum item em ${widget.entity.label}',
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

          if (_reorderMode) {
            return Column(
              children: [
                // Banner informativo
                Container(
                  width: double.infinity,
                  color: AppColors.primary.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Arraste os itens para reordenar. Toque em SALVAR para confirmar.',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelReorderMode,
                        child: const Text('CANCELAR',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: _saveOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: const Text('SALVAR'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _localDocs!.removeAt(oldIndex);
                        _localDocs!.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) => Padding(
                      key: ValueKey(docs[index].id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildItem(context, docs[index],
                          showDragHandle: true),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, idx) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _buildItem(context, docs[index]),
          );
        },
      ),
      floatingActionButton: _reorderMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Botão reordenar
                FloatingActionButton.small(
                  heroTag: 'reorder_${widget.entity.name}',
                  onPressed: () {
                    final ctrl =
                        ref.read(adminControllerProvider.notifier);
                    final stream = ctrl.streamFor(widget.entity);
                    stream.first.then((snap) {
                      if (mounted) {
                        _enterReorderMode(
                            snap.docs.cast<QueryDocumentSnapshot>());
                      }
                    });
                  },
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.primary,
                  tooltip: 'Reordenar',
                  child: const Icon(Icons.swap_vert),
                ),
                const SizedBox(height: 8),
                // Botão adicionar
                FloatingActionButton.extended(
                  heroTag: 'add_${widget.entity.name}',
                  onPressed: () => _onFabPressed(context),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: widget.entity == AdminEntity.trails
                      ? const Icon(Icons.map_outlined)
                      : const Icon(Icons.add),
                  label: Text(widget.entity == AdminEntity.trails
                      ? 'Nova Trilha'
                      : 'Novo ${widget.entity.label.split('/').first}'),
                ),
              ],
            ),
    );
  }
}
