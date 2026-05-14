// ─────────────────────────────────────────────────────────────────
//  SPARK ADMIN WIDGETS — Layout 3 Colunas
//  Arquivo: lib/core/admin/presentation/widgets/spark_admin_widgets.dart
// ─────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/core/admin/presentation/admin_controller.dart';
import 'package:spark_app/core/admin/presentation/widgets/admin_trail_wizard_dialog.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  MAIN ADMIN PANEL PAGE
// ─────────────────────────────────────────────────────────────────

class SPARKAdminPanel extends ConsumerStatefulWidget {
  const SPARKAdminPanel({super.key});

  @override
  ConsumerState<SPARKAdminPanel> createState() => _SPARKAdminPanelState();
}

class _SPARKAdminPanelState extends ConsumerState<SPARKAdminPanel> {
  String? _selectedCategoryId;
  String? _selectedModuleId;
  String? _selectedTrailId;
  String? _selectedLessonId;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'SPARK Admin Panel',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
      ),
      body: Row(
        children: [
          // ── COLUNA 1: CATEGORIAS (VERDE) ─────────────────────────
          Expanded(
            child: _LeftColumn(
              selectedCategoryId: _selectedCategoryId,
              onSelectCategory: (catId) {
                setState(() {
                  _selectedCategoryId = catId;
                  _selectedModuleId = null;
                  _selectedTrailId = null;
                  _selectedLessonId = null;
                });
              },
            ),
          ),

          // ── COLUNA 2: MÓDULOS (AZUL) ────────────────────────────
          if (_selectedCategoryId != null)
            Expanded(
              child: _MiddleColumn(
                categoryId: _selectedCategoryId!,
                selectedModuleId: _selectedModuleId,
                onSelectModule: (modId) {
                  setState(() {
                    _selectedModuleId = modId;
                    _selectedTrailId = null;
                    _selectedLessonId = null;
                  });
                },
              ),
            ),

          // ── COLUNA 3: TRILHAS/LIÇÕES/QUESTÕES (LARANJA) ────────
          if (_selectedCategoryId != null && _selectedModuleId != null)
            Expanded(
              child: _RightColumn(
                categoryId: _selectedCategoryId!,
                moduleId: _selectedModuleId!,
                selectedTrailId: _selectedTrailId,
                selectedLessonId: _selectedLessonId,
                onSelectTrail: (trailId) {
                  setState(() {
                    _selectedTrailId = trailId;
                    _selectedLessonId = null;
                  });
                },
                onSelectLesson: (lessonId) {
                  setState(() {
                    _selectedLessonId = lessonId;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  COLUNA 1: CATEGORIAS (VERDE)
// ─────────────────────────────────────────────────────────────────

class _LeftColumn extends ConsumerWidget {
  final String? selectedCategoryId;
  final Function(String) onSelectCategory;

  const _LeftColumn({
    required this.selectedCategoryId,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(adminControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.card)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border(bottom: BorderSide(color: AppColors.primary, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Categorias',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: () => _showCreateCategoryDialog(context, ref),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: StreamBuilder(
              stream: ctrl.streamFor(AdminEntity.categories),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhuma categoria',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final catId = docs[index].id;
                    final isSelected = catId == selectedCategoryId;

                    return Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.card,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.card,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(data['title'] ?? '—', style: const TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text(data['subtitle'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                        onTap: () => onSelectCategory(catId),
                        trailing: PopupMenuButton(
                          color: AppColors.surface,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Editar', style: TextStyle(color: AppColors.textPrimary)),
                              onTap: () => _showEditCategoryDialog(context, ref, catId, data),
                            ),
                            PopupMenuItem(
                              child: const Text('Deletar', style: TextStyle(color: AppColors.error)),
                              onTap: () => _showDeleteConfirmation(
                                context,
                                'Deletar Categoria',
                                'Isso deletará todos os módulos, trilhas, lições e questões associados.',
                                () => ref.read(adminControllerProvider.notifier).delete(AdminEntity.categories, catId),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateCategoryDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Criar Categoria', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Título',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subtitleController,
              decoration: InputDecoration(
                hintText: 'Subtítulo',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              ref.read(adminControllerProvider.notifier).create(AdminEntity.categories, {
                'title': titleController.text,
                'subtitle': subtitleController.text,
              });
              Navigator.pop(context);
            },
            child: const Text('Criar', style: TextStyle(color: AppColors.background)),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, String catId, Map<String, dynamic> data) {
    final titleController = TextEditingController(text: data['title']);
    final subtitleController = TextEditingController(text: data['subtitle']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Editar Categoria', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Título',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subtitleController,
              decoration: InputDecoration(
                hintText: 'Subtítulo',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              ref.read(adminControllerProvider.notifier).update(AdminEntity.categories, catId, {
                'title': titleController.text,
                'subtitle': subtitleController.text,
              });
              Navigator.pop(context);
            },
            child: const Text('Salvar', style: TextStyle(color: AppColors.background)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.error)),
        content: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Deletar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  COLUNA 2: MÓDULOS (AZUL)
// ─────────────────────────────────────────────────────────────────

class _MiddleColumn extends ConsumerWidget {
  final String categoryId;
  final String? selectedModuleId;
  final Function(String) onSelectModule;

  const _MiddleColumn({
    required this.categoryId,
    required this.selectedModuleId,
    required this.onSelectModule,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(adminControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.card)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1E88E5).withValues(alpha: 0.1),
              border: Border(bottom: BorderSide(color: Color(0xFF1E88E5), width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Módulos',
                  style: TextStyle(
                    color: Color(0xFF1E88E5),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF1E88E5)),
                  onPressed: () => _showCreateModuleDialog(context, ref),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: ctrl.streamFor(AdminEntity.modules),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs
                    .where((doc) => (doc.data() as Map)['categoryId'] == categoryId)
                    .toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhum módulo',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final modId = docs[index].id;
                    final isSelected = modId == selectedModuleId;

                    return Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFF1E88E5).withValues(alpha: 0.2) : AppColors.card,
                        border: Border.all(
                          color: isSelected ? Color(0xFF1E88E5) : AppColors.card,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(data['title'] ?? '—', style: const TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text(data['subtitle'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                        onTap: () => onSelectModule(modId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateModuleDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Criar Módulo', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Título',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E88E5)),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subtitleController,
              decoration: InputDecoration(
                hintText: 'Subtítulo',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E88E5)),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1E88E5)),
            onPressed: () {
              ref.read(adminControllerProvider.notifier).create(AdminEntity.modules, {
                'categoryId': categoryId,
                'title': titleController.text,
                'subtitle': subtitleController.text,
              });
              Navigator.pop(context);
            },
            child: const Text('Criar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  COLUNA 3: TRILHAS/LIÇÕES/QUESTÕES (LARANJA)
// ─────────────────────────────────────────────────────────────────

class _RightColumn extends ConsumerWidget {
  final String categoryId;
  final String moduleId;
  final String? selectedTrailId;
  final String? selectedLessonId;
  final Function(String) onSelectTrail;
  final Function(String) onSelectLesson;

  const _RightColumn({
    required this.categoryId,
    required this.moduleId,
    required this.selectedTrailId,
    required this.selectedLessonId,
    required this.onSelectTrail,
    required this.onSelectLesson,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(adminControllerProvider.notifier);

    return Container(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFFF9800).withValues(alpha: 0.1),
              border: Border(bottom: BorderSide(color: Color(0xFFFF9800), width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trilhas',
                  style: TextStyle(
                    color: Color(0xFFFF9800),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFFFF9800)),
                  onPressed: () => _showTrailWizard(context, ref),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: ctrl.streamFor(AdminEntity.trails),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs
                    .where((doc) => (doc.data() as Map)['moduleId'] == moduleId)
                    .toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhuma trilha',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final trailId = docs[index].id;
                    final isSelected = trailId == selectedTrailId;

                    return Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFFFF9800).withValues(alpha: 0.2) : AppColors.card,
                        border: Border.all(
                          color: isSelected ? Color(0xFFFF9800) : AppColors.card,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(data['title'] ?? '—', style: const TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text(
                          '${data['numLessons'] ?? 0} lições • ${data['numEvaluations'] ?? 0} avaliações',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        onTap: () => onSelectTrail(trailId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTrailWizard(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AdminTrailWizardDialog(
        categoryId: categoryId,
        moduleId: moduleId,
      ),
    );
  }
}
