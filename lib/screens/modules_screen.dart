import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_skeleton.dart';
import 'package:spark_app/models/spark_admin_models.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/learning_path_screen.dart';
import 'package:spark_app/providers/dev_mode_provider.dart';
import 'package:spark_app/providers/progress_provider.dart';
import 'package:spark_app/providers/content_providers.dart';
import 'package:spark_app/core/utils/theme_utils.dart';

class ModulesScreen extends ConsumerWidget {
  final SPARKCategory? category;
  // Cor enviada pela tela de Categorias (já que o SPARKCategory não armazena cor diretamente)
  final Color themeColor;
  final IconData themeIcon;

  const ModulesScreen({
    super.key, 
    this.category, 
    this.themeColor = AppColors.primary,
    this.themeIcon = Icons.school,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTestMode = kDebugMode && ref.watch(devModeProvider);
    
    // Fallback: se for nulo, apenas volta
    if (category == null) {
      return const Scaffold(body: Center(child: Text('Categoria não encontrada')));
    }
    final cat = category!;

    final userProgressAsync = ref.watch(userProgressProvider);
    final userProgress = userProgressAsync.value ?? [];

    final modulesAsync = ref.watch(modulesStreamProvider(cat.id));

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
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      _ResponsiveIconButton(
                        icon: Icons.arrow_back_ios_new,
                        size: 20,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [themeColor, themeColor.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.category, color: AppColors.textPrimary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.title.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            modulesAsync.when(
                              data: (modules) => Text(
                                '${modules.length} módulos disponíveis',
                                style: TextStyle(
                                  color: AppColors.textMuted.withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Lista de Módulos ────────────────────────────
                Expanded(
                  child: modulesAsync.when(
                    data: (modules) {
                      if (modules.isEmpty) {
                        return const Center(
                          child: Text(
                            'Nenhum módulo encontrado nesta categoria.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }

                      // Ícone ÚNICO por módulo: derivado do conteúdo, sem
                      // repetição na lista e sempre diferente do ícone da
                      // categoria. Calculado de uma vez sobre a lista inteira.
                      final moduleIcons = ThemeUtils.assignUniqueIcons(
                        modules.map((m) => '${m.title} ${m.subtitle}').toList(),
                        categoryIcon: themeIcon,
                        seed: cat.id,
                      );

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: modules.length,
                        itemBuilder: (context, index) {
                          final module = modules[index];
                          final moduleIcon = moduleIcons[index];

                          // Calcular progresso (módulos sem bloqueio sequencial)
                          final progIndex = userProgress.indexWhere((p) => p.moduleId == module.id);
                          final prog = progIndex >= 0 ? userProgress[progIndex] : null;
                          final actualProgress = prog?.progressPercent ?? 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _ModuleCard(
                              module: module,
                              progress: actualProgress,
                              isLocked: false, // Navegação livre — sem prerequisito sequencial
                              themeColor: themeColor,
                              themeIcon: moduleIcon,
                              isTestMode: isTestMode,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LearningPathScreen(
                                      category: cat,
                                      module: module,
                                      themeColor: themeColor,
                                      themeIcon: moduleIcon,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 6,
                      itemBuilder: (context, index) => const SparkSkeleton(
                        width: double.infinity,
                        height: 104,
                        margin: EdgeInsets.only(bottom: 14),
                      ),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Erro ao carregar módulos',
                        style: TextStyle(color: AppColors.error),
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
//  CARD DE MÓDULO (com animação de escala ao toque)
// ─────────────────────────────────────────────────────────────────

class _ModuleCard extends StatefulWidget {
  final SPARKModule module;
  final double progress;
  final bool isLocked;
  final Color themeColor;
  final IconData themeIcon;
  final VoidCallback onTap;
  final bool isTestMode;

  const _ModuleCard({
    required this.module,
    required this.progress,
    required this.isLocked,
    required this.themeColor,
    this.themeIcon = Icons.school,
    required this.onTap,
    this.isTestMode = false,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard>
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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
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
    final mod = widget.module;
    final locked = !widget.isTestMode && widget.isLocked;
    final color = locked ? AppColors.textMuted : widget.themeColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: locked
                  ? AppColors.cardBorder.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: locked
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: locked
                            ? AppColors.inputBackground
                            : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.themeIcon,
                        color: locked ? AppColors.textMuted.withValues(alpha: 0.4) : color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mod.title,
                            style: TextStyle(
                              color: locked ? AppColors.textMuted : AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mod.subtitle,
                            style: TextStyle(
                              color: AppColors.textMuted.withValues(alpha: locked ? 0.5 : 1.0),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!locked)
                      Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 14),
                  ],
                ),
                if (!locked) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '${(widget.progress * 100).toInt()}% Concluído',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      backgroundColor: AppColors.inputBackground,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
                if (locked) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Bloqueado',
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  BOTÃO ÍCONE RESPONSIVO (reusável)
// ─────────────────────────────────────────────────────────────────

class _ResponsiveIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ResponsiveIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  State<_ResponsiveIconButton> createState() => _ResponsiveIconButtonState();
}

class _ResponsiveIconButtonState extends State<_ResponsiveIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _pressed ? 0.5 : 1.0,
        child: Icon(widget.icon, color: AppColors.textPrimary, size: widget.size),
      ),
    );
  }
}