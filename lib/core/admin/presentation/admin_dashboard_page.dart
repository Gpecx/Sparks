import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/core/admin/presentation/admin_controller.dart';
import 'package:spark_app/core/admin/presentation/widgets/admin_entity_form.dart';
import 'package:spark_app/core/admin/presentation/widgets/admin_entity_list_view.dart';
import 'package:spark_app/providers/user_provider.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ADMIN DASHBOARD PAGE
//  Menu Lateral (Drawer) com navegação entre as 4 entidades.
// ─────────────────────────────────────────────────────────────────

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  AdminEntity _selected = AdminEntity.categories;

  // ── Definição dos campos de cada entidade ────────────────────────
  static const _entityFields = <AdminEntity, List<FieldConfig>>{
    AdminEntity.categories: [
      FieldConfig(key: 'title', label: 'Título'),
      FieldConfig(key: 'subtitle', label: 'Subtítulo', required: false),
      FieldConfig(key: 'description', label: 'Descrição', maxLines: 3, required: false),
      FieldConfig(key: 'order', label: 'Ordem (número)', hint: 'ex: 1', required: false, keyboardType: TextInputType.number),
    ],
    AdminEntity.modules: [
      FieldConfig(key: 'title', label: 'Título'),
      FieldConfig(key: 'subtitle', label: 'Subtítulo', required: false),
      FieldConfig(key: 'categoryId', label: 'ID da Categoria', hint: 'ex: capacitacao_tecnica'),
      FieldConfig(key: 'order', label: 'Ordem (número)', hint: 'ex: 1', required: false, keyboardType: TextInputType.number),
    ],
    AdminEntity.lessons: [
      FieldConfig(key: 'title', label: 'Título'),
      FieldConfig(key: 'subtitle', label: 'Subtítulo', required: false),
      FieldConfig(key: 'moduleId', label: 'ID do Módulo', hint: 'ex: mod01_fundamentos'),
      FieldConfig(key: 'type', label: 'Tipo', hint: 'lesson | eval'),
      FieldConfig(key: 'content', label: 'Conteúdo (Markdown)', maxLines: 6, required: false),
    ],
    AdminEntity.questions: [
      FieldConfig(key: 'statement', label: 'Enunciado', maxLines: 3),
      FieldConfig(key: 'lessonId', label: 'ID da Lição'),
      FieldConfig(key: 'type', label: 'Tipo', hint: 'multipleChoice | trueFalse | fillInTheBlanks'),
      FieldConfig(key: 'options', label: 'Opções (separadas por |)', hint: 'A|B|C|D', required: false),
      FieldConfig(key: 'correctIndex', label: 'Índice correto (0-based)', hint: '0', required: false, keyboardType: TextInputType.number),
      FieldConfig(key: 'explanation', label: 'Explicação', maxLines: 3),
    ],
  };

  static const _entityIcons = <AdminEntity, IconData>{
    AdminEntity.categories: Icons.category_outlined,
    AdminEntity.modules:    Icons.layers_outlined,
    AdminEntity.lessons:    Icons.menu_book_outlined,
    AdminEntity.questions:  Icons.quiz_outlined,
  };

  // ── Title/Subtitle extractor por entidade ────────────────────────
  static String _titleOf(AdminEntity e, Map<String, dynamic> d) => switch (e) {
        AdminEntity.categories => d['title'] ?? '—',
        AdminEntity.modules    => d['title'] ?? '—',
        AdminEntity.lessons    => d['title'] ?? '—',
        AdminEntity.questions  => d['statement'] ?? '—',
      };

  static String? _subtitleOf(AdminEntity e, Map<String, dynamic> d) => switch (e) {
        AdminEntity.categories => d['subtitle'],
        AdminEntity.modules    => '📂 ${d['categoryId'] ?? ''}  •  ${d['subtitle'] ?? ''}',
        AdminEntity.lessons    => '📦 ${d['moduleId'] ?? ''}  •  ${d['type'] ?? ''}',
        AdminEntity.questions  => 'Tipo: ${d['type'] ?? ''}  •  Lição: ${d['lessonId'] ?? ''}',
      };

  @override
  Widget build(BuildContext context) {
    // ── Guard de segurança ───────────────────────────────────────
    final userAsync = ref.watch(userModelProvider);
    final role = userAsync.value?.role;
    if (role != 'admin') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outlined, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Acesso Negado',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Você não tem permissão para acessar esta página.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Voltar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final adminState = ref.watch(adminControllerProvider);

    // ── Feedback de erro/sucesso via SnackBar ────────────────────
    ref.listen(adminControllerProvider, (_, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(adminControllerProvider.notifier).clearMessages();
      }
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(adminControllerProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SPARK Admin',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  _selected.label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        // Badge de loading global
        actions: [
          if (adminState.isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            ),
        ],
      ),
      // ── Drawer lateral ────────────────────────────────────────────
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header do Drawer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border(bottom: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accentGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Painel Admin',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Gerenciamento de conteúdo',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Items do menu
              ...AdminEntity.values.map((entity) => _DrawerItem(
                    icon: _entityIcons[entity]!,
                    label: entity.label,
                    isSelected: _selected == entity,
                    onTap: () {
                      setState(() => _selected = entity);
                      Navigator.of(context).pop();
                    },
                  )),
              const Spacer(),
              // Footer info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Coleções: categories, modules, lessons, questions',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // ── Body — Lista da entidade selecionada ──────────────────────
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: AdminEntityListView(
          key: ValueKey(_selected),
          entity: _selected,
          fields: _entityFields[_selected]!,
          titleExtractor: (data) => _titleOf(_selected, data),
          subtitleExtractor: (data) => _subtitleOf(_selected, data) ?? '',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  DRAWER ITEM — Widget auxiliar para item do menu lateral
// ─────────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
