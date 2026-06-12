import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/widgets/spark_snack.dart';
import 'package:spark_app/models/ebook_model.dart';
import 'package:spark_app/providers/ebook_providers.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';
import 'package:spark_app/services/access_control_service.dart';
import 'package:spark_app/services/analytics_service.dart';
import 'package:spark_app/widgets/plan_widgets.dart';

// ─────────────────────────────────────────────────────────────────
//  TELA 1 — ÍNDICE DO E-BOOK (lista de capítulos)
// ─────────────────────────────────────────────────────────────────
class EbookReaderScreen extends ConsumerWidget {
  final EbookModel ebook;
  final Color themeColor;

  const EbookReaderScreen({
    super.key,
    required this.ebook,
    this.themeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(ebookProgressProvider(ebook.id));
    final completedChapters = progress?.completedChapters ?? const [];
    final chapters = [...ebook.chapterIndex]..sort((a, b) => a.order.compareTo(b.order));
    final access = ref.watch(accessControlProvider);

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Sumário'),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Capa
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            themeColor.withValues(alpha: 0.18),
                            themeColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border:
                            Border.all(color: themeColor.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.menu_book, color: themeColor, size: 32),
                          const SizedBox(height: 12),
                          Text(
                            ebook.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ebook.subtitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _tag(Icons.collections_bookmark_outlined,
                                  '${ebook.chapterCount} capítulos', themeColor),
                              const SizedBox(width: 10),
                              _tag(Icons.timer_outlined,
                                  '${ebook.estimatedMinutes} min', themeColor),
                            ],
                          ),
                          if (chapters.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _ProgressBar(
                              value: completedChapters.length / chapters.length,
                              color: themeColor,
                              label:
                                  '${completedChapters.length} de ${chapters.length} capítulos lidos',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'CAPÍTULOS',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (chapters.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.cardBorder.withValues(alpha: 0.3)),
                        ),
                        child: const Text('Capítulos em elaboração.',
                            style: TextStyle(color: AppColors.textMuted)),
                      )
                    else
                      ...chapters.asMap().entries.map((e) {
                        final i = e.key;
                        final ch = e.value;
                        final done = completedChapters.contains(ch.id);
                        final locked = !access.canAccessEbookChapter(i);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ChapterTile(
                            number: i + 1,
                            chapterRef: ch,
                            done: done,
                            color: themeColor,
                            locked: locked,
                            onTap: () {
                              if (locked) {
                                AnalyticsService().logLockedFeatureAccessed(
                                    feature: 'ebook', itemId: ebook.id);
                                UpgradePromptBottomSheet.show(context,
                                    feature: 'ebook', trigger: 'ebook_locked');
                                return;
                              }
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChapterReaderScreen(
                                    ebook: ebook,
                                    chapterId: ch.id,
                                    chapterTitle: ch.title,
                                    chapterNumber: i + 1,
                                    totalChapters: chapters.length,
                                    themeColor: themeColor,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final int number;
  final EbookChapterRef chapterRef;
  final bool done;
  final Color color;
  final VoidCallback onTap;
  final bool locked;

  const _ChapterTile({
    required this.number,
    required this.chapterRef,
    required this.done,
    required this.color,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Capítulo $number: ${chapterRef.title}',
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
                    ? color.withValues(alpha: 0.45)
                    : AppColors.cardBorder.withValues(alpha: 0.4),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done
                        ? color.withValues(alpha: 0.2)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: done
                          ? color.withValues(alpha: 0.5)
                          : AppColors.cardBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: done
                      ? Icon(Icons.check, color: color, size: 20)
                      : Text('$number',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapterRef.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${chapterRef.sectionCount} seções'
                        '${chapterRef.estimatedMinutes > 0 ? ' · ${chapterRef.estimatedMinutes} min' : ''}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(locked ? Icons.lock_rounded : Icons.chevron_right,
                    color: locked
                        ? AppColors.primary
                        : color.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final String label;

  const _ProgressBar(
      {required this.value, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: AppColors.cardBorder.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  TELA 2 — LEITURA DE UM CAPÍTULO (lazy load das seções)
// ─────────────────────────────────────────────────────────────────
class ChapterReaderScreen extends ConsumerStatefulWidget {
  final EbookModel ebook;
  final String chapterId;
  final String chapterTitle;
  final int chapterNumber;
  final int totalChapters;
  final Color themeColor;

  const ChapterReaderScreen({
    super.key,
    required this.ebook,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.totalChapters,
    this.themeColor = AppColors.primary,
  });

  @override
  ConsumerState<ChapterReaderScreen> createState() =>
      _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends ConsumerState<ChapterReaderScreen> {
  Future<void> _markChapterComplete() async {
    HapticFeedback.mediumImpact();
    final prev = ref.read(ebookProgressProvider(widget.ebook.id));
    final done = <String>{
      ...(prev?.completedChapters ?? const <String>[]),
      widget.chapterId,
    }.toList();
    final allDone = done.length >= widget.totalChapters;
    await saveEbookProgress(
      ebookId: widget.ebook.id,
      lastChapterId: widget.chapterId,
      lastSectionId: '',
      completedChapters: done,
      completed: allDone,
    );
    if (mounted) {
      SparkSnack.success(
        context,
        allDone
            ? 'E-book concluído! 🎉'
            : 'Capítulo ${widget.chapterNumber} concluído',
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(ebookChapterProvider((
      categoryId: widget.ebook.categoryId,
      moduleId: widget.ebook.moduleId,
      ebookId: widget.ebook.id,
      chapterId: widget.chapterId,
    )));
    final color = widget.themeColor;

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text('Cap. ${widget.chapterNumber}/${widget.totalChapters}'),
          ),
          body: SafeArea(
            top: false,
            child: chapterAsync.when(
              data: (chapter) {
                if (chapter == null) {
                  return const Center(
                    child: Text('Capítulo não encontrado.',
                        style: TextStyle(color: Colors.white54)),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding:
                                const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              Text(
                                chapter.title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (chapter.subtitle != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  chapter.subtitle!,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Divider(
                                  color: color.withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              ...chapter.sections.asMap().entries.map((e) =>
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 28),
                                    child: _SectionWidget(
                                      section: e.value,
                                      themeColor: color,
                                      index: e.key,
                                    ),
                                  )),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _markChapterComplete,
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(
                                widget.chapterNumber < widget.totalChapters
                                    ? 'CONCLUIR CAPÍTULO'
                                    : 'CONCLUIR E-BOOK',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                  child: Text('Erro ao carregar capítulo: $e',
                      style: const TextStyle(color: AppColors.error))),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  RENDERER DE SEÇÃO (compartilhado)
// ─────────────────────────────────────────────────────────────────
class _SectionWidget extends StatelessWidget {
  final EbookSection section;
  final Color themeColor;
  final int index;

  const _SectionWidget({
    required this.section,
    required this.themeColor,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                section.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildBody(),
      ],
    );
  }

  Widget _buildBody() {
    switch (section.type) {
      case 'text':
        return _textBlock(section.body ?? '');
      case 'list':
        return _listBlock(section.items ?? []);
      case 'note':
        return _noteBlock(section.body ?? '');
      case 'formula':
        return _formulaBlock(section.formula ?? '', section.explanation ?? '');
      case 'summary':
        return _summaryBlock(section.body ?? '');
      default:
        return _textBlock(section.body ?? '');
    }
  }

  Widget _textBlock(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 15,
        height: 1.6,
      ),
    );
  }

  Widget _listBlock(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7, right: 10),
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _noteBlock(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: themeColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: themeColor.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulaBlock(String formula, String explanation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
          ),
          child: Text(
            formula,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: themeColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
        if (explanation.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            explanation,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryBlock(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeColor.withValues(alpha: 0.15),
            themeColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_outlined, color: themeColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Resumo',
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
