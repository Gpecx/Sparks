import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/models/spark_admin_models.dart';
import 'package:spark_app/providers/content_providers.dart';
import 'package:spark_app/providers/ebook_providers.dart';
import 'package:spark_app/widgets/spark_skeleton.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/ebook_list_screen.dart';

const List<Map<String, dynamic>> _categoryThemes = [
  {'color': AppColors.primary, 'gradientEnd': Color(0xFF007A01), 'icon': Icons.bolt},
  {'color': Color(0xFF22C55E), 'gradientEnd': Color(0xFF15803D), 'icon': Icons.memory},
  {'color': Color(0xFF2DD4BF), 'gradientEnd': Color(0xFF0F766E), 'icon': Icons.gavel},
  {'color': Color(0xFF84CC16), 'gradientEnd': Color(0xFF3F6212), 'icon': Icons.lightbulb},
  {'color': Color(0xFF4ADE80), 'gradientEnd': Color(0xFF166534), 'icon': Icons.layers},
  {'color': Color(0xFF34D399), 'gradientEnd': Color(0xFF065F46), 'icon': Icons.science},
];

class EstudosScreen extends ConsumerWidget {
  const EstudosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final progressList = ref.watch(ebookProgressStreamProvider).asData?.value ?? [];

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ESTUDOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Leia os e-books antes de praticar nas trilhas',
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                          final theme = _categoryThemes[index % _categoryThemes.length];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _CategoryCard(
                              category: cat,
                              color: theme['color'] as Color,
                              gradientEnd: theme['gradientEnd'] as Color,
                              icon: theme['icon'] as IconData,
                              ebooksDone: progressList
                                  .where((p) => p.completed && p.ebookId.startsWith(cat.id))
                                  .length,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EbookListScreen(
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
                    loading: () => ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 6,
                      itemBuilder: (context, index) => const SparkSkeleton(
                        width: double.infinity,
                        height: 92,
                        margin: EdgeInsets.only(bottom: 14),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text('Erro: $e',
                          style: const TextStyle(color: AppColors.error)),
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

class _CategoryCard extends StatelessWidget {
  final SPARKCategory category;
  final Color color;
  final Color gradientEnd;
  final IconData icon;
  final int ebooksDone;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.color,
    required this.gradientEnd,
    required this.icon,
    required this.ebooksDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${category.title}. Categoria de estudos.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  gradientEnd.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.menu_book_outlined, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.subtitle,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ebooksDone > 0) ...[
                          const SizedBox(height: 8),
                          _chip('$ebooksDone lido${ebooksDone > 1 ? 's' : ''}', color),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      );
}
