import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/dashboard_screen.dart';
import 'package:spark_app/screens/categories_screen.dart';
import 'package:spark_app/screens/leaderboard_screen.dart';
import 'package:spark_app/screens/profile_screen.dart';
import 'package:spark_app/screens/store_screen.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => MainShellScreenState();
}

class MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    CategoriesScreen(),
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

  @override
  Widget build(BuildContext context) {
    final isTestMode = ref.watch(devModeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 800;

        Widget mainContent = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _screens[_currentIndex],
          ),
        );

        // ── Wrapper com banner TEST MODE (só em kDebugMode) ─────
        Widget scaffoldBody = mainContent;
        if (kDebugMode && isTestMode) {
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
        if (kDebugMode && isTestMode) {
          devFab = _DevModeFab(
            onToggle: () => ref.read(devModeProvider.notifier).deactivate(),
          );
        }

        if (isLargeScreen) {
          return Scaffold(
            floatingActionButton: devFab,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _currentIndex = index),
                  backgroundColor: AppColors.navBarBackground,
                  indicatorColor: AppColors.primary.withValues(alpha: 0.2),
                  selectedIconTheme:
                      const IconThemeData(color: AppColors.primary),
                  unselectedIconTheme:
                      const IconThemeData(color: AppColors.textMuted),
                  selectedLabelTextStyle: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  unselectedLabelTextStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Início')),
                    NavigationRailDestination(
                        icon: Icon(Icons.route_outlined),
                        selectedIcon: Icon(Icons.route),
                        label: Text('Trilha')),
                    NavigationRailDestination(
                        icon: Icon(Icons.emoji_events_outlined),
                        selectedIcon: Icon(Icons.emoji_events),
                        label: Text('Ranking')),
                    NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('Perfil')),
                    NavigationRailDestination(
                        icon: Icon(Icons.store_outlined),
                        selectedIcon: Icon(Icons.store),
                        label: Text('Loja')),
                  ],
                ),
                VerticalDivider(
                    thickness: 1,
                    width: 1,
                    color: AppColors.cardBorder.withValues(alpha: 0.3)),
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: scaffoldBody,
                  ),
                ),
              ],
            ),
          );
        }

        // Layout Mobile
        return Scaffold(
          floatingActionButton: devFab,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: scaffoldBody,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.navBarBackground,
              border: Border(
                top: BorderSide(
                  color: AppColors.cardBorder.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textMuted,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Início',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.route_outlined),
                  activeIcon: Icon(Icons.route),
                  label: 'Trilha',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events_outlined),
                  activeIcon: Icon(Icons.emoji_events),
                  label: 'Ranking',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.store_outlined),
                  activeIcon: Icon(Icons.store),
                  label: 'Loja',
                ),
              ],
            ),
          ),
        );
      },
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
          bottom: BorderSide(color: Color(0xFFFFB300), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: Color(0xFFFFB300), size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '⚠️  TEST MODE ACTIVE — Todas as lições desbloqueadas',
              style: TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDeactivate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
              ),
              child: const Text(
                'DESATIVAR',
                style: TextStyle(
                    color: Color(0xFFFFB300),
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
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
      foregroundColor: const Color(0xFFFFB300),
      tooltip: 'Desativar Modo Dev',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
      ),
      child: const Icon(Icons.bug_report, size: 20),
    );
  }
}
