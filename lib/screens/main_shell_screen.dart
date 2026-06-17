import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/services/covenant_service.dart';
import 'package:spark_app/services/user_service.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/dashboard_screen.dart';
import 'package:spark_app/screens/categories_screen.dart';
import 'package:spark_app/screens/estudos_screen.dart';
import 'package:spark_app/screens/tools_screen.dart';
import 'package:spark_app/screens/leaderboard_screen.dart';
import 'package:spark_app/screens/profile_screen.dart';
import 'package:spark_app/screens/store_screen.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';
import 'package:spark_app/providers/user_provider.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const MainShellScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MainShellScreen> createState() => MainShellScreenState();
}

class MainShellScreenState extends ConsumerState<MainShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      CovenantService().initialize(uid);
      // Inicia escuta em tempo real do Firestore para o usuário logado
      UserService().startListening();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  final List<Widget> _screens = [
    DashboardScreen(),
    CategoriesScreen(),
    const EstudosScreen(),
    const ToolsScreen(),
    LeaderboardScreen(),
    const ProfileScreen(),
    StoreScreen(),
  ];

  /// Permite que telas filhas troquem a aba ativa.
  void switchTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  /// Abre o menu com as opções secundárias (Perfil, Ranking, Loja).
  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navBarBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Widget tile(IconData icon, String title, String subtitle, int index) {
          final selected = _currentIndex == index;
          return ListTile(
            leading: Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: selected ? AppColors.primary : Colors.white,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              setState(() => _currentIndex = index);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              tile(Icons.person, 'Perfil',
                  'Sua conta e configurações', 5),
              tile(Icons.emoji_events, 'Ranking',
                  'Classificação geral', 4),
              tile(Icons.store, 'Loja', 'Loja de itens', 6),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTestMode = ref.watch(devModeProvider);
    final isAdmin = ref.watch(userModelProvider.select((user) => user.value?.isAdmin ?? false));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 800;

        Widget mainContent = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            // Transição suave (fade) ao trocar de aba — reforça a fluidez do app.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: _screens[_currentIndex],
              ),
            ),
          ),
        );

        // ── Wrapper com banner TEST MODE (só em kDebugMode) ─────
        Widget scaffoldBody = mainContent;
        if (kDebugMode && isTestMode && isAdmin) {
          scaffoldBody = Column(
            children: [
              // Banner de aviso TEST MODE ACTIVE
              _DevModeBanner(
                onDeactivate: () =>
                    ref.read(devModeProvider.notifier).deactivate(),
              ),
              Expanded(child: mainContent),
            ],
          );
        }

        // ── FAB de controle do Dev Mode ─────────────────────────
        Widget? devFab;
        if (kDebugMode && isTestMode && isAdmin) {
          devFab = _DevModeFab(
            onToggle: () => ref.read(devModeProvider.notifier).deactivate(),
          );
        }

        if (isLargeScreen) {
          return Scaffold(
            floatingActionButton: devFab,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            body: Semantics(
              label: 'Tela principal do SPARK',
              child: Row(
                children: [
                  Semantics(
                    label: 'Menu de navegação lateral',
                    child: NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (index) =>
                          setState(() => _currentIndex = index),
                      backgroundColor: AppColors.navBarBackground,
                      indicatorColor: AppColors.primary.withValues(alpha: 0.2),
                      selectedIconTheme: const IconThemeData(
                        color: AppColors.primary,
                      ),
                      unselectedIconTheme: const IconThemeData(
                        color: AppColors.textMuted,
                      ),
                      selectedLabelTextStyle: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelTextStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.home_outlined,
                            semanticLabel: 'Início',
                          ),
                          selectedIcon: Icon(
                            Icons.home,
                            semanticLabel: 'Início selecionado',
                          ),
                          label: Text('Início'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.category_outlined,
                            semanticLabel: 'Categorias',
                          ),
                          selectedIcon: Icon(
                            Icons.category,
                            semanticLabel: 'Categorias selecionada',
                          ),
                          label: Text('Categorias'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.menu_book_outlined,
                            semanticLabel: 'Estudos',
                          ),
                          selectedIcon: Icon(
                            Icons.menu_book,
                            semanticLabel: 'Estudos selecionado',
                          ),
                          label: Text('Estudos'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.calculate_outlined,
                            semanticLabel: 'Ferramentas',
                          ),
                          selectedIcon: Icon(
                            Icons.calculate,
                            semanticLabel: 'Ferramentas selecionada',
                          ),
                          label: Text('Ferramentas'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.emoji_events_outlined,
                            semanticLabel: 'Ranking',
                          ),
                          selectedIcon: Icon(
                            Icons.emoji_events,
                            semanticLabel: 'Ranking selecionado',
                          ),
                          label: Text('Ranking'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.person_outline,
                            semanticLabel: 'Perfil',
                          ),
                          selectedIcon: Icon(
                            Icons.person,
                            semanticLabel: 'Perfil selecionado',
                          ),
                          label: Text('Perfil'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.store_outlined,
                            semanticLabel: 'Loja',
                          ),
                          selectedIcon: Icon(
                            Icons.store,
                            semanticLabel: 'Loja selecionada',
                          ),
                          label: Text('Loja'),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(
                    thickness: 1,
                    width: 1,
                    color: AppColors.cardBorder.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: Container(
                      color: AppColors.background,
                      child: scaffoldBody,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Layout Mobile — nav: Início · Estudos · (FAB Categorias) · Perfil · Menu
        // Índices: 0 Início · 1 Categorias · 2 Estudos · 3 Ferramentas · 4 Ranking · 5 Perfil · 6 Loja
        const moreIndexes = [5, 4, 6]; // Perfil, Ranking e Loja no menu "..."
        final isMoreSelected = moreIndexes.contains(_currentIndex);

        return Semantics(
          label: 'Tela principal do SPARK',
          child: Scaffold(
            floatingActionButton: devFab ??
                _CategoriasFab(
                  selected: _currentIndex == 1,
                  onPressed: () => setState(() => _currentIndex = 1),
                ),
            floatingActionButtonLocation: devFab != null
                ? FloatingActionButtonLocation.endFloat
                : FloatingActionButtonLocation.centerDocked,
            body: scaffoldBody,
            bottomNavigationBar: Semantics(
              label: 'Barra de navegação inferior',
              explicitChildNodes: true,
              child: BottomAppBar(
                color: AppColors.navBarBackground,
                elevation: 0,
                shape: const CircularNotchedRectangle(),
                notchMargin: 8,
                padding: EdgeInsets.zero,
                height: 64,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppColors.cardBorder.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        label: 'Início',
                        selected: _currentIndex == 0,
                        onTap: () => setState(() => _currentIndex = 0),
                      ),
                      _NavItem(
                        icon: Icons.menu_book_outlined,
                        activeIcon: Icons.menu_book,
                        label: 'Estudos',
                        selected: _currentIndex == 2,
                        onTap: () => setState(() => _currentIndex = 2),
                      ),
                      const SizedBox(width: 56), // espaço do FAB central
                      _NavItem(
                        icon: Icons.calculate_outlined,
                        activeIcon: Icons.calculate,
                        label: 'Ferramentas',
                        selected: _currentIndex == 3,
                        onTap: () => setState(() => _currentIndex = 3),
                      ),
                      _NavItem(
                        icon: Icons.more_horiz,
                        activeIcon: Icons.more_horiz,
                        label: 'Menu',
                        selected: isMoreSelected,
                        onTap: _showMoreMenu,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Item da barra de navegação inferior (mobile) ────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FAB central "Categorias" ────────────────────────────────────
class _CategoriasFab extends StatelessWidget {
  final bool selected;
  final VoidCallback onPressed;

  const _CategoriasFab({required this.selected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: selected
            ? const BorderSide(color: Colors.white, width: 2)
            : BorderSide.none,
      ),
      tooltip: 'Categorias de aprendizado',
      child: Icon(selected ? Icons.category : Icons.category_outlined, size: 26),
    );
  }
}

// ── Banner "TEST MODE ACTIVE" ───────────────────────────────────
class _DevModeBanner extends StatelessWidget {
  final VoidCallback onDeactivate;

  const _DevModeBanner({required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0E00), Color(0xFF2A1800)],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.warningAmber, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: AppColors.warningAmber, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '⚠️  TEST MODE ACTIVE — Todas as lições desbloqueadas',
              style: TextStyle(
                color: AppColors.warningAmber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Desativar modo desenvolvedor',
            child: GestureDetector(
              onTap: onDeactivate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.warningAmber.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'DESATIVAR',
                  style: TextStyle(
                    color: AppColors.warningAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── FAB discreto de controle Dev Mode ──────────────────────────
class _DevModeFab extends StatelessWidget {
  final VoidCallback onToggle;

  const _DevModeFab({required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: onToggle,
      backgroundColor: const Color(0xFF2A1800),
      foregroundColor: AppColors.warningAmber,
      tooltip: 'Desativar Modo Dev',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.warningAmber, width: 1.5),
      ),
      child: const Icon(Icons.bug_report, size: 20),
    );
  }
}
