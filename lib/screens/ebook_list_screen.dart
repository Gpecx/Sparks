import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_skeleton.dart';
import 'package:spark_app/models/spark_admin_models.dart';
import 'package:spark_app/models/ebook_model.dart';
import 'package:spark_app/providers/content_providers.dart';
import 'package:spark_app/providers/ebook_providers.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/screens/ebook_reader_screen.dart';

class EbookListScreen extends ConsumerWidget {
  final SPARKCategory category;
  final Color themeColor;
  final IconData themeIcon;

  const EbookListScreen({
    super.key,
    required this.category,
    this.themeColor = AppColors.primary,
    this.themeIcon = Icons.menu_book,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(modulesStreamProvider(category.id));
    final progressList = ref.watch(ebookProgressStreamProvider).asData?.value ?? [];

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(category: category, themeColor: themeColor),
                const SizedBox(height: 16),
                Expanded(
                  child: modulesAsync.when(
                    data: (modules) {
                      if (modules.isEmpty) {
                        return const Center(
                          child: Text('Nenhum módulo disponível.',
                              style: TextStyle(color: Colors.white54)),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: modules.length,
                        itemBuilder: (context, i) {
                          final mod = modules[i];
                          return _ModuleSection(
                            category: category,
                            module: mod,
                            themeColor: themeColor,
                            progressList: progressList,
                          );
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 5,
                      itemBuilder: (context, i) => const SparkSkeleton(
                        width: double.infinity,
                        height: 120,
                        margin: EdgeInsets.only(bottom: 16),
                      ),
                    ),
                    error: (e, _) => Center(
                        child: Text('Erro: $e',
                            style: const TextStyle(color: AppColors.error))),
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

// ── Cabeçalho ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final SPARKCategory category;
  final Color themeColor;

  const _Header({required this.category, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: themeColor.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.menu_book_outlined, color: themeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'E-books por módulo',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seção de módulo com seus e-books ─────────────────────────────
class _ModuleSection extends ConsumerWidget {
  final SPARKCategory category;
  final SPARKModule module;
  final Color themeColor;
  final List<EbookProgressModel> progressList;

  const _ModuleSection({
    required this.category,
    required this.module,
    required this.themeColor,
    required this.progressList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ebooksAsync = ref.watch(ebooksStreamProvider(
        (categoryId: category.id, moduleId: module.id)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              module.title.toUpperCase(),
              style: TextStyle(
                color: themeColor.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          ebooksAsync.when(
            data: (ebooks) {
              if (ebooks.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.cardBorder.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_empty,
                          color: AppColors.textMuted, size: 18),
                      const SizedBox(width: 10),
                      const Text('E-book em elaboração',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                );
              }
              return Column(
                children: ebooks
                    .map((eb) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _EbookCard(
                            ebook: eb,
                            themeColor: themeColor,
                            progress: progressList
                                .where((p) => p.ebookId == eb.id)
                                .firstOrNull,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EbookReaderScreen(
                                    ebook: eb,
                                    themeColor: themeColor,
                                  ),
                                ),
                              );
                            },
                          ),
                        ))
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            ),
            error: (e, _) => Text('Erro: $e',
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Card de e-book ────────────────────────────────────────────────
class _EbookCard extends StatelessWidget {
  final EbookModel ebook;
  final Color themeColor;
  final EbookProgressModel? progress;
  final VoidCallback onTap;

  const _EbookCard({
    required this.ebook,
    required this.themeColor,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = progress?.completed ?? false;

    return Semantics(
      button: true,
      label: '${ebook.title}. ${ebook.estimatedMinutes} minutos.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: done
                    ? themeColor.withValues(alpha: 0.45)
                    : AppColors.cardBorder.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: done
                          ? themeColor.withValues(alpha: 0.2)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: done
                            ? themeColor.withValues(alpha: 0.5)
                            : AppColors.cardBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      done ? Icons.check_circle : Icons.menu_book_outlined,
                      color: done ? themeColor : AppColors.textMuted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ebook.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ebook.subtitle,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _tag(Icons.timer_outlined,
                                '${ebook.estimatedMinutes} min'),
                            const SizedBox(width: 8),
                            _tag(Icons.collections_bookmark_outlined,
                                '${ebook.chapterCount} capítulos'),
                            if (done) ...[
                              const SizedBox(width: 8),
                              _tag(Icons.check, 'Concluído',
                                  color: themeColor),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: themeColor.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: c, size: 12),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: c, fontSize: 11)),
      ],
    );
  }
}
