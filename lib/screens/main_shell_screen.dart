import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/controllers/energy_controller.dart';
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
import 'package:spark_app/models/user_model.dart';
import 'package:spark_app/widgets/sparky_tutorial.dart';
import 'package:spark_app/l10n/app_localizations.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const MainShellScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MainShellScreen> createState() => MainShellScreenState();
}

class MainShellScreenState extends ConsumerState<MainShellScreen> {
  late int _currentIndex;

  // Âncoras para o tour guiado do Sparky (holofote + seta).
  final GlobalKey _tourHome = GlobalKey();
  final GlobalKey _tourStudies = GlobalKey();
  final GlobalKey _tourCategories = GlobalKey();
  final GlobalKey _tourTools = GlobalKey();
  final GlobalKey _tourMenu = GlobalKey();

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
    // Tour do Sparky: disparado SÓ para contas novas (campo `tutorialSeen`
    // por conta no Firestore). A decisão fica no build(), via ref.listen ao
    // userModelProvider, pois o modelo carrega de forma assíncrona.
    // "Rever tutorial" (pedido de outra tela, ex.: Configurações).
    sparkyTourReplayRequest.addListener(_onReplayRequested);
  }

  // Garante que o tour automático seja avaliado uma única vez por sessão.
  bool _autoTourChecked = false;

  /// Mostra o tour automaticamente apenas para CONTAS NOVAS (tutorialSeen ==
  /// false). Contas antigas têm o campo ausente → tutorialSeen == true (default
  /// no modelo) → nada acontece aqui; elas só veem o tour via Configurações.
  void _maybeAutoTour(UserModel? user) {
    if (_autoTourChecked || user == null) return;
    if (user.tutorialSeen) return;
    _autoTourChecked = true;
    // Todo o trabalho de UI é adiado para depois do frame — este método pode
    // ser chamado durante o build (leitura do valor em cache).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _currentIndex = 0); // tour aponta para a barra na aba Início
      SparkyTutorial.show(context, targets: _tourTargets);
    });
  }

  /// Vai para a aba Início e reabre o tour com holofote nos alvos reais.
  void _onReplayRequested() {
    if (!mounted) return;
    setState(() => _currentIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SparkyTutorial.show(context, targets: _tourTargets);
    });
  }

  @override
  void dispose() {
    sparkyTourReplayRequest.removeListener(_onReplayRequested);
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

  Map<String, GlobalKey> get _tourTargets => {
        'home': _tourHome,
        'studies': _tourStudies,
        'categories': _tourCategories,
        'tools': _tourTools,
        'menu': _tourMenu,
      };

  /// Permite que telas filhas troquem a aba ativa.
  void switchTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  /// Abre o menu com as opções secundárias (Perfil, Ranking, Loja).
  void _showMoreMenu() {
    final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;
    final isTestMode = ref.watch(devModeProvider);
    final isAdmin = ref.watch(userModelProvider.select((user) => user.value?.isAdmin ?? false));

    // Sincroniza o status de assinante com a bateria de energia (bateria
    // infinita ∞ para quem tem plano ativo). Sem isso, a flag só era
    // marcada logo após o checkout do trial e nunca ao reabrir o app.
    ref.listen<bool>(
      userModelProvider.select((user) => user.value?.isSubscriber ?? false),
      (prev, isSubscriber) => EnergyController().setPremium(isSubscriber),
    );
    // Sync inicial (caso o provider já tenha dado em cache quando o shell
    // monta, o listen acima não dispara — então aplicamos o valor atual).
    final isSubscriberNow =
        ref.read(userModelProvider).value?.isSubscriber ?? false;
    if (EnergyController().isPremiumUser != isSubscriberNow) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => EnergyController().setPremium(isSubscriberNow),
      );
    }

    // Tour automático só para contas novas. Escuta a carga do modelo e também
    // checa o valor já em cache (quando o provider resolve antes do build).
    ref.listen<AsyncValue<UserModel?>>(
      userModelProvider,
      (prev, next) => _maybeAutoTour(next.value),
    );
    _maybeAutoTour(ref.read(userModelProvider).value);

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
              label: l10n.shellSemanticMain,
              child: Row(
                children: [
                  Semantics(
                    label: l10n.shellSemanticSideNav,
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
                      destinations: [
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.home_outlined,
                            semanticLabel: l10n.navHome,
                          ),
                          selectedIcon: Icon(
                            Icons.home,
                            semanticLabel: l10n.navHome,
                          ),
                          label: Text(l10n.navHome),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.category_outlined,
                            semanticLabel: l10n.navCategories,
                          ),
                          selectedIcon: Icon(
                            Icons.category,
                            semanticLabel: l10n.navCategories,
                          ),
                          label: Text(l10n.navCategories),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.menu_book_outlined,
                            semanticLabel: l10n.navStudies,
                          ),
                          selectedIcon: Icon(
                            Icons.menu_book,
                            semanticLabel: l10n.navStudies,
                          ),
                          label: Text(l10n.navStudies),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.calculate_outlined,
                            semanticLabel: l10n.navTools,
                          ),
                          selectedIcon: Icon(
                            Icons.calculate,
                            semanticLabel: l10n.navTools,
                          ),
                          label: Text(l10n.navTools),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.emoji_events_outlined,
                            semanticLabel: l10n.navRanking,
                          ),
                          selectedIcon: Icon(
                            Icons.emoji_events,
                            semanticLabel: l10n.navRanking,
                          ),
                          label: Text(l10n.navRanking),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.person_outline,
                            semanticLabel: l10n.navProfile,
                          ),
                          selectedIcon: Icon(
                            Icons.person,
                            semanticLabel: l10n.navProfile,
                          ),
                          label: Text(l10n.navProfile),
                        ),
                        NavigationRailDestination(
                          icon: Icon(
                            Icons.store_outlined,
                            semanticLabel: l10n.navStore,
                          ),
                          selectedIcon: Icon(
                            Icons.store,
                            semanticLabel: l10n.navStore,
                          ),
                          label: Text(l10n.navStore),
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
          label: l10n.shellSemanticMain,
          child: Scaffold(
            floatingActionButton: devFab ??
                _CategoriasFab(
                  key: _tourCategories,
                  selected: _currentIndex == 1,
                  onPressed: () => setState(() => _currentIndex = 1),
                ),
            floatingActionButtonLocation: devFab != null
                ? FloatingActionButtonLocation.endFloat
                : FloatingActionButtonLocation.centerDocked,
            body: scaffoldBody,
            bottomNavigationBar: Semantics(
              label: l10n.shellSemanticBottomNav,
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
                        key: _tourHome,
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        label: l10n.navHome,
                        selected: _currentIndex == 0,
                        onTap: () => setState(() => _currentIndex = 0),
                      ),
                      _NavItem(
                        key: _tourStudies,
                        icon: Icons.menu_book_outlined,
                        activeIcon: Icons.menu_book,
                        label: l10n.navStudies,
                        selected: _currentIndex == 2,
                        onTap: () => setState(() => _currentIndex = 2),
                      ),
                      const SizedBox(width: 56), // espaço do FAB central
                      _NavItem(
                        key: _tourTools,
                        icon: Icons.calculate_outlined,
                        activeIcon: Icons.calculate,
                        label: 'Ferramentas',
                        selected: _currentIndex == 3,
                        onTap: () => setState(() => _currentIndex = 3),
                      ),
                      _NavItem(
                        key: _tourMenu,
                        icon: Icons.more_horiz,
                        activeIcon: Icons.more_horiz,
                        label: l10n.navMenu,
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
    super.key,
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

  const _CategoriasFab({
    super.key,
    required this.selected,
    required this.onPressed,
  });

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
      tooltip: AppLocalizations.of(context)!.categoriesFabTooltip,
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
