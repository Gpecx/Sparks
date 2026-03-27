import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/models/curriculum_models.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/learning_path_screen.dart';

class ModulesScreen extends StatelessWidget {
  final LearningCategory? category;

  const ModulesScreen({super.key, this.category});

  @override
  Widget build(BuildContext context) {
    // Fallback: se nenhuma categoria for passada, usa a primeira
    final cat = category ?? mockCategories.first;

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
                            colors: [cat.color, cat.gradientEnd],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cat.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.title.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cat.modules.length} módulos disponíveis',
                              style: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
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
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: cat.modules.length,
                    itemBuilder: (context, index) {
                      final module = cat.modules[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ModuleCard(
                          module: module,
                          categoryColor: cat.color,
                          onTap: () {
                            if (module.isLocked) {
                              HapticFeedback.heavyImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Conclua os módulos anteriores para desbloquear!'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LearningPathScreen(
                                  moduleTitle: module.title,
                                  lessons: module.lessons,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
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
  final LearningModule module;
  final Color categoryColor;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.module,
    required this.categoryColor,
    required this.onTap,
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
    final color = mod.isLocked ? AppColors.textMuted : mod.color;

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
              color: mod.isLocked
                  ? AppColors.cardBorder.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: mod.isLocked
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
                        color: mod.isLocked
                            ? AppColors.inputBackground
                            : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        mod.isLocked ? Icons.lock : mod.icon,
                        color: mod.isLocked ? AppColors.textMuted : color,
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
                              color: mod.isLocked ? AppColors.textMuted : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mod.subtitle,
                            style: TextStyle(
                              color: AppColors.textMuted.withValues(alpha: mod.isLocked ? 0.5 : 1.0),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!mod.isLocked)
                      Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 14),
                  ],
                ),
                if (!mod.isLocked) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '${(mod.progress * 100).toInt()}% Concluído',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${mod.lessons.length} lições',
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: mod.progress,
                      backgroundColor: AppColors.inputBackground,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
                if (mod.isLocked) ...[
                  const SizedBox(height: 12),
                  Text(
                    '🔒 Bloqueado · ${mod.lessons.length} lições',
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
        child: Icon(widget.icon, color: Colors.white, size: widget.size),
      ),
    );
  }
}