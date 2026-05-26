import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/models/spark_admin_models.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/modules_screen.dart';
import 'package:spark_app/screens/main_shell_screen.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';
import 'package:spark_app/providers/content_providers.dart';
import 'package:go_router/go_router.dart';

// Paleta Spark: verdes e tons harmônicos — sem cinzas apagados
final List<Map<String, dynamic>> _themeConfig = [
  // Verde neon (cor principal Spark)
  {'color': const Color(0xFF00C402), 'gradientEnd': const Color(0xFF007A01), 'icon': Icons.bolt},
  // Verde médio vibrante
  {'color': const Color(0xFF22C55E), 'gradientEnd': const Color(0xFF15803D), 'icon': Icons.memory},
  // Verde-teal (complementar harmônico)
  {'color': const Color(0xFF2DD4BF), 'gradientEnd': const Color(0xFF0F766E), 'icon': Icons.gavel},
  // Verde-lima (brilhante, tom Spark)
  {'color': const Color(0xFF84CC16), 'gradientEnd': const Color(0xFF3F6212), 'icon': Icons.lightbulb},
  // Verde escuro (accentGreen Spark)
  {'color': const Color(0xFF4ADE80), 'gradientEnd': const Color(0xFF166534), 'icon': Icons.layers},
  // Verde-água intenso
  {'color': const Color(0xFF34D399), 'gradientEnd': const Color(0xFF065F46), 'icon': Icons.science},
];

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTestMode = kDebugMode && ref.watch(devModeProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final shell = context.findAncestorStateOfType<MainShellScreenState>();
                              if (shell != null) {
                                shell.switchTab(0);
                              } else {
                                context.go('/home');
                              }
                            },
                            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'CATEGORIAS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Escolha uma área para começar a aprender',
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Lista de Categorias ─────────────────────────
                Expanded(
                  child: categoriesAsync.when(
                    data: (categories) {
                      if (categories.isEmpty) {
                        return const Center(
                          child: Text(
                            'Nenhuma categoria disponível',
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          // Obter o tema de forma cíclica caso haja mais categorias que temas definidos
                          final theme = _themeConfig[index % _themeConfig.length];
                          
                          final isLocked = cat.order > 100; 
                          // Apenas para evitar dead_code linter
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _CategoryCard(
                              category: cat,
                              isTestMode: isTestMode,
                              isLocked: isLocked,
                              themeColor: theme['color'] as Color,
                              themeGradientEnd: theme['gradientEnd'] as Color,
                              themeIcon: theme['icon'] as IconData,
                              onTap: (!isTestMode && isLocked)
                                  ? () {
                                      HapticFeedback.heavyImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: const [
                                              Icon(Icons.lock, color: Colors.white, size: 16),
                                              SizedBox(width: 8),
                                              Text('Esta categoria estará disponível em breve!'),
                                            ],
                                          ),
                                          backgroundColor: const Color(0xFF37474F),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                    }
                                  : () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ModulesScreen(
                                            category: cat,
                                            themeColor: theme['color'] as Color,
                                            themeIcon: theme['icon'] as IconData,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Erro ao carregar categorias: $err',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  CARD DE CATEGORIA (com estado de bloqueio visual)
// ─────────────────────────────────────────────────────────────────

class _CategoryCard extends ConsumerStatefulWidget {
  final SPARKCategory category;
  final VoidCallback onTap;
  final bool isTestMode;
  final bool isLocked;
  final Color themeColor;
  final Color themeGradientEnd;
  final IconData themeIcon;

  const _CategoryCard({
    required this.category,
    required this.onTap,
    this.isTestMode = false,
    this.isLocked = false,
    required this.themeColor,
    required this.themeGradientEnd,
    required this.themeIcon,
  });

  @override
  ConsumerState<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends ConsumerState<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final locked = !widget.isTestMode && widget.isLocked;

    // Cores ficam apagadas quando bloqueada
    final displayColor = locked ? const Color(0xFF78909C) : widget.themeColor;
    final displayGradEnd = locked ? const Color(0xFF37474F) : widget.themeGradientEnd;

    final modulesAsync = ref.watch(modulesStreamProvider(cat.id));
    final moduleCount = modulesAsync.asData?.value.length ?? 0;

    return MouseRegion(
      cursor: locked ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) {
          _scaleCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _scaleCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: Opacity(
            opacity: locked ? 0.55 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    displayColor.withValues(alpha: 0.15),
                    displayGradEnd.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: displayColor.withValues(alpha: locked ? 0.2 : 0.35),
                  width: 1.5,
                ),
                boxShadow: locked
                    ? null
                    : [
                        BoxShadow(
                          color: displayColor.withValues(alpha: 0.1),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // Ícone
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [displayColor, displayGradEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: locked
                            ? null
                            : [
                                BoxShadow(
                                  color: displayColor.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                      ),
                      child: Icon(
                        locked ? Icons.lock : widget.themeIcon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Texto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cat.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (locked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Em breve',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          if (!locked) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _chip(modulesAsync.isLoading ? '...' : '$moduleCount módulos', displayColor),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Seta (só quando desbloqueado)
                    if (!locked)
                      Icon(
                        Icons.chevron_right,
                        color: displayColor.withValues(alpha: 0.6),
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
