import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/user_provider.dart';
import '../../constants/fs.dart';
import 'admin_controller.dart';
import 'widgets/admin_dialogs_new.dart';
import 'widgets/admin_cards.dart';
import 'widgets/admin_content_panel.dart';
import 'widgets/admin_support_panel.dart';
import 'widgets/admin_access_codes_panel.dart';
import 'widgets/admin_users_panel.dart';
import 'widgets/admin_stats_panel.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Guard de acesso: somente role=='admin'. Quem chegar via deep-link
    // /admin sem ser admin é mandado de volta pra home. (A função no servidor
    // já valida role, mas isto fecha a exposição da própria UI admin.)
    final userAsync = ref.watch(userModelProvider);
    if (!userAsync.hasValue) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final user = userAsync.value;
    if (user == null || !user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home');
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final state = ref.watch(adminControllerProvider);
    final controller = ref.read(adminControllerProvider.notifier);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;

    // ── Escuta erros do controller e exibe SnackBar ──────────────
    ref.listen<AdminState>(adminControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    next.errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                controller.clearMessages();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: isDesktop ? null : Drawer(
        backgroundColor: AppColors.surface,
        child: _buildSidebar(context, ref, state, controller),
      ),
      appBar: isDesktop ? null : AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.bolt, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text('SPARK ADMIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Row(
        children: [
          if (isDesktop)
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: _buildSidebar(context, ref, state, controller),
            ),
          
          Expanded(
            child: Column(
              children: [
                if (state.sidebarIndex == 1) 
                  _buildTopNavBar(state, controller, isDesktop || isTablet),

                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                    child: _buildMainArea(context, ref, state, controller, isDesktop, isTablet),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainArea(BuildContext context, WidgetRef ref, AdminState state, AdminController controller, bool isDesktop, bool isTablet) {
    switch (state.sidebarIndex) {
      case 0: return _buildOverview(context, ref);
      case 1: return _getContentTab(context, ref, state, controller, isDesktop, isTablet);
      case 2: return const AdminUsersPanel();
      case 4: return const AdminSupportPanel();
      case 5: return const AdminAccessCodesPanel();
      default: return const Center(child: Text('Em desenvolvimento', style: TextStyle(color: Colors.white)));
    }
  }

  Widget _buildOverview(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stats em tempo real ─────────────────────────────
              const AdminStatsPanel(),
              const SizedBox(height: 40),
              // ── Divider ───────────────────────────────────
              Divider(color: Colors.white.withValues(alpha: 0.07)),
              const SizedBox(height: 32),
              // ── Quick actions ────────────────────────────
              const Text(
                'Ações Rápidas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _quickActionCard(
                    context,
                    icon: Icons.code,
                    title: 'Importar JSON',
                    subtitle: 'Importar uma trilha via JSON',
                    color: AppColors.primary,
                    onTap: () => AdminDialogs.showImportJSON(context, ref),
                  ),
                  _quickActionCard(
                    context,
                    icon: Icons.upload_file,
                    title: 'Importar em Massa',
                    subtitle: 'Carregar all_trails.json completo',
                    color: const Color(0xFF6C63FF),
                    onTap: () => AdminDialogs.showBulkImportJSON(context, ref),
                  ),
                  _quickActionCard(
                    context,
                    icon: Icons.menu_book,
                    title: 'Importar E-book',
                    subtitle: 'Importar um e-book via JSON',
                    color: const Color(0xFF2DD4BF),
                    onTap: () => AdminDialogs.showImportEbook(context, ref),
                  ),
                  _quickActionCard(
                    context,
                    icon: Icons.library_books,
                    title: 'Importar E-books (massa)',
                    subtitle: 'Carregar all_ebooks.json completo',
                    color: const Color(0xFF14B8A6),
                    onTap: () => AdminDialogs.showBulkImportEbooks(context, ref),
                  ),
                  _quickActionCard(
                    context,
                    icon: Icons.auto_awesome,
                    title: 'Gerador de Trilhas',
                    subtitle: 'Crie estruturas rapidamente',
                    color: AppColors.orange,
                    onTap: () => AdminDialogs.showTrailWizard(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }


  Widget _getContentTab(BuildContext context, WidgetRef ref, AdminState state, AdminController controller, bool isDesktop, bool isTablet) {
    switch (state.contentTabIndex) {
      case 0: return _buildCategoriesTab(context, ref, state, controller, isDesktop, isTablet);
      case 1: return _buildModulesTab(context, ref, state, controller, isDesktop, isTablet);
      case 2: return _buildTrailsTab(context, ref, state, controller, isDesktop, isTablet);
      default: return _buildCategoriesTab(context, ref, state, controller, isDesktop, isTablet);
    }
  }

  // --- TOP NAV BAR ---
  Widget _buildTopNavBar(AdminState state, AdminController controller, bool showLabels) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface, 
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _navTab('1. Categorias', isActive: state.contentTabIndex == 0, onTap: () => controller.setContentTab(0)),
            _navTab('2. Módulos', isActive: state.contentTabIndex == 1, onTap: () => controller.setContentTab(1)),
            _navTab('3. Trilhas', isActive: state.contentTabIndex == 2, onTap: () => controller.setContentTab(2)),
          ],
        ),
      ),
    );
  }

  Widget _navTab(String title, {required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: isActive ? const Border(bottom: BorderSide(color: AppColors.primary, width: 3)) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // --- SIDEBAR ---
  Widget _buildSidebar(BuildContext context, WidgetRef ref, AdminState state, AdminController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CONTEÚDO', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              _sidebarItem(context, Icons.grid_view_rounded, 'Visão Geral', isActive: state.sidebarIndex == 0, onTap: () => controller.setSidebarMenu(0)),
              _sidebarItem(context, Icons.layers_outlined, 'Estrutura', isActive: state.sidebarIndex == 1, onTap: () => controller.setSidebarMenu(1)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SISTEMA', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              _sidebarItem(context, Icons.people_outline, 'Usuários', isActive: state.sidebarIndex == 2, onTap: () => controller.setSidebarMenu(2)),
              _sidebarItem(context, Icons.vpn_key_outlined, 'Códigos de acesso', isActive: state.sidebarIndex == 5, onTap: () => controller.setSidebarMenu(5)),
              _sidebarItem(context, Icons.support_agent_outlined, 'Suporte', isActive: state.sidebarIndex == 4, onTap: () => controller.setSidebarMenu(4)),
              _sidebarItem(context, Icons.settings_outlined, 'Configurações', isActive: state.sidebarIndex == 3, onTap: () => controller.setSidebarMenu(3)),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: _sidebarItem(context, Icons.logout_rounded, 'Voltar ao App', onTap: () => context.go('/')),
        ),
      ],
    );
  }

  Widget _sidebarItem(BuildContext context, IconData icon, String title, {bool isActive = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: () {
        if (onTap != null) onTap();
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.isDrawerOpen) {
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: isActive ? AppColors.primary : AppColors.textSecondary, fontWeight: isActive ? FontWeight.w700 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // --- CATEGORIAS ---
  // Header responsivo das abas de conteúdo. No MOBILE empilha (título em cima,
  // ações em baixo) — antes a Row[Expanded(título) + Wrap(botões)] fazia a Wrap
  // consumir quase toda a largura e esmagar o título.
  Widget _tabHeader({
    required bool isMobile,
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    // Sempre Column: título em cima, botões embaixo em Wrap.
    // Evita o esmagamento do título quando há muitos botões.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: actions),
      ],
    );
  }

  Widget _buildCategoriesTab(BuildContext context, WidgetRef ref, AdminState state, AdminController controller, bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tabHeader(
          isMobile: !isDesktop && !isTablet,
          title: 'Categorias',
          subtitle: 'Selecione uma categoria para ver seus módulos.',
          actions: [
            OutlinedButton.icon(
              onPressed: () => AdminDialogs.showDeleteAllContent(context, ref),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('LIMPAR TUDO'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(140, 40),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => AdminDialogs.showBulkImportJSON(context, ref),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('IMPORTAR EM MASSA'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
                side: const BorderSide(color: Color(0xFF6C63FF)),
                minimumSize: const Size(160, 40),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => AdminDialogs.showImportJSON(context, ref),
              icon: const Icon(Icons.code, size: 18),
              label: const Text('IMPORTAR JSON'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                minimumSize: const Size(140, 40),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => AdminDialogs.showCreateCategory(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('NOVA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(100, 40),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: controller.streamFor(AdminEntity.categories),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('Nenhuma categoria.', style: TextStyle(color: Colors.grey)));

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                  mainAxisExtent: 160,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isSelected = state.selectedCategoryId == docs[index].id;
                  return AdminEntityCard(
                    title: data[FS.title] ?? 'Sem título',
                    description: data['description'] ?? '',
                    colorType: AppColors.primary,
                    badgeText: 'Selecionar',
                    isActive: isSelected,
                    onTap: () => controller.selectCategory(docs[index].id),
                    onDelete: () {
                      AdminDialogs.showConfirmDelete(
                        context: context,
                        title: 'Deletar Categoria',
                        content: 'Tem certeza que deseja deletar "${data[FS.title]}"? Isso removerá todos os módulos e trilhas vinculados.',
                        onConfirm: () async {
                          await controller.delete(AdminEntity.categories, docs[index].id);
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- MÓDULOS ---
  Widget _buildModulesTab(BuildContext context, WidgetRef ref, AdminState state, AdminController controller, bool isDesktop, bool isTablet) {
    if (state.selectedCategoryId == null) {
      return const Center(child: Text('Selecione uma categoria primeiro na aba anterior.', style: TextStyle(color: AppColors.textSecondary)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tabHeader(
          isMobile: !isDesktop && !isTablet,
          title: 'Módulos',
          subtitle: 'Gerencie os blocos de ensino deste módulo.',
          actions: [
            ElevatedButton.icon(
              onPressed: () => AdminDialogs.showCreateModule(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('NOVO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                minimumSize: const Size(100, 40),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: controller.streamFor(AdminEntity.modules),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('Nenhum módulo.', style: TextStyle(color: Colors.grey)));

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                  mainAxisExtent: 160,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isSelected = state.selectedModuleId == docs[index].id;
                  return AdminEntityCard(
                    title: data[FS.title] ?? 'Sem título',
                    description: data['subtitle'] ?? '',
                    colorType: AppColors.blue,
                    badgeText: 'Selecionar',
                    isActive: isSelected,
                    onTap: () => controller.selectModule(docs[index].id),
                    onDelete: () {
                      AdminDialogs.showConfirmDelete(
                        context: context,
                        title: 'Deletar Módulo',
                        content: 'Tem certeza que deseja deletar "${data[FS.title]}"? Isso removerá todas as trilhas vinculadas.',
                        onConfirm: () async {
                          await controller.delete(AdminEntity.modules, docs[index].id);
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TRILHAS (PAINEL INTERATIVO) ---
  Widget _buildTrailsTab(BuildContext context, WidgetRef ref, AdminState state, AdminController controller, bool isDesktop, bool isTablet) {
    if (state.selectedModuleId == null) {
      return const Center(child: Text('Selecione um módulo primeiro na aba anterior.', style: TextStyle(color: AppColors.textSecondary)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tabHeader(
          isMobile: !isDesktop && !isTablet,
          title: 'Trilhas e Lições',
          subtitle: 'Crie a jornada completa com lições e questões.',
          actions: [
            ElevatedButton.icon(
              onPressed: () => AdminDialogs.showTrailWizard(context, ref),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('GERAR TRILHA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                minimumSize: const Size(140, 40),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: AdminContentPanel(
            categoryId: state.selectedCategoryId!,
            moduleId: state.selectedModuleId!,
          ),
        ),
      ],
    );
  }
}
