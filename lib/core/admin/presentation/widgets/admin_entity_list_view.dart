import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/core/admin/presentation/admin_controller.dart';
import 'package:spark_app/core/admin/presentation/widgets/admin_entity_form.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ENTITY LIST VIEW — Lista genérica para qualquer entidade admin
// ─────────────────────────────────────────────────────────────────

class AdminEntityListView extends ConsumerWidget {
  final AdminEntity entity;
  final List<FieldConfig> fields;
  final String Function(Map<String, dynamic> data) titleExtractor;
  final String Function(Map<String, dynamic> data)? subtitleExtractor;

  /// Chamado quando o usuário toca num item (para atualizar contexto hierárquico).
  final void Function(String docId, Map<String, dynamic> data)? onItemSelected;

  const AdminEntityListView({
    super.key,
    required this.entity,
    required this.fields,
    required this.titleExtractor,
    this.subtitleExtractor,
    this.onItemSelected,
  });

  void _openForm(
    BuildContext context,
    WidgetRef ref, {
    String? docId,
    Map<String, dynamic>? existing,
  }) {
    final ctrl = ref.read(adminControllerProvider.notifier);
    final state = ref.read(adminControllerProvider);

    showDialog(
      context: context,
      builder: (_) => AdminEntityForm(
        title: docId == null ? 'Novo ${entity.label}' : 'Editar ${entity.label}',
        fields: fields,
        initialValues: existing?.map((k, v) => MapEntry(k, v?.toString() ?? '')) ?? {},
        isSaving: state.isSaving,
        onSave: (data) async {
          if (docId == null) {
            await ctrl.create(entity, data);
          } else {
            // Extrai IDs de pais do documento existente (para hierarquia correta)
            await ctrl.update(entity, docId, data);
          }
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
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
        title: const Text('Confirmar exclusão', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Deseja remover este item de ${entity.label}? Esta ação não pode ser desfeita.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(adminControllerProvider.notifier).delete(entity, docId);
              Navigator.of(context).pop();
            },
            child: const Text('EXCLUIR', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(adminControllerProvider.notifier);

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
                  Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum item em ${entity.label}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use o botão + para adicionar o primeiro.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onTap: onItemSelected != null
                      ? () => onItemSelected!(doc.id, data)
                      : null,
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
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      (titleExtractor(data).isNotEmpty
                              ? titleExtractor(data)[0]
                              : '?')
                          .toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.blue, size: 20),
                        onPressed: () => _openForm(
                          context,
                          ref,
                          docId: doc.id,
                          existing: data,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        onPressed: () => _confirmDelete(context, ref, doc.id, data),
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
        onPressed: () => _openForm(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Novo ${entity.label.split('/').first}'),
      ),
    );
  }
}
