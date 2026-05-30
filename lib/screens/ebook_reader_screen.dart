import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/models/ebook_model.dart';
import 'package:spark_app/providers/ebook_providers.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

class EbookReaderScreen extends ConsumerStatefulWidget {
  final EbookModel ebook;
  final Color themeColor;

  const EbookReaderScreen({
    super.key,
    required this.ebook,
    this.themeColor = AppColors.primary,
  });

  @override
  ConsumerState<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends ConsumerState<EbookReaderScreen> {
  late final ScrollController _scroll;
  int _currentSectionIndex = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _scroll.addListener(_onScroll);
    final saved = ref
        .read(ebookProgressProvider(widget.ebook.id));
    if (saved != null) {
      _completed = saved.completed;
      final idx = widget.ebook.sections
          .indexWhere((s) => s.id == saved.lastSectionId);
      if (idx >= 0) _currentSectionIndex = idx;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final maxScroll = _scroll.position.maxScrollExtent;
    if (maxScroll <= 0) return;
    final fraction = _scroll.offset / maxScroll;
    final idx = (fraction * (widget.ebook.sections.length - 1)).round()
        .clamp(0, widget.ebook.sections.length - 1);
    if (idx != _currentSectionIndex) {
      setState(() => _currentSectionIndex = idx);
      _saveProgress(completed: false);
    }
  }

  Future<void> _saveProgress({required bool completed}) async {
    if (widget.ebook.sections.isEmpty) return;
    final sectionId = widget.ebook.sections[_currentSectionIndex].id;
    await saveEbookProgress(
      ebookId: widget.ebook.id,
      lastSectionId: sectionId,
      completed: completed,
    );
    if (completed) setState(() => _completed = true);
  }

  void _markComplete() {
    HapticFeedback.mediumImpact();
    _saveProgress(completed: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: widget.themeColor, size: 18),
            const SizedBox(width: 8),
            const Text('E-book concluído!'),
          ],
        ),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double get _readProgress {
    if (widget.ebook.sections.isEmpty) return 0;
    return (_currentSectionIndex + 1) / widget.ebook.sections.length;
  }

  @override
  Widget build(BuildContext context) {
    final ebook = widget.ebook;
    final color = widget.themeColor;

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(ebook, color),
                _buildProgressBar(color),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 800;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildToc(ebook, color),
                            const VerticalDivider(
                                width: 1,
                                color: AppColors.cardBorder),
                            Expanded(child: _buildContent(ebook, color)),
                          ],
                        );
                      }
                      return _buildContent(ebook, color);
                    },
                  ),
                ),
                _buildFooter(color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(EbookModel ebook, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ebook.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${ebook.estimatedMinutes} min · ${ebook.sectionCount} seções',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_completed)
            Icon(Icons.check_circle, color: color, size: 22)
          else
            TextButton(
              onPressed: _markComplete,
              child: Text('Concluir',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _readProgress,
              backgroundColor: AppColors.cardBorder.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Seção ${_currentSectionIndex + 1} de ${widget.ebook.sectionCount}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Sumário lateral (apenas em telas largas ≥ 800 px)
  Widget _buildToc(EbookModel ebook, Color color) {
    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SUMÁRIO',
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: ebook.sections.length,
                itemBuilder: (context, i) {
                  final s = ebook.sections[i];
                  final active = i == _currentSectionIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentSectionIndex = i);
                      _scroll.animateTo(
                        _offsetForSection(i),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        s.title,
                        style: TextStyle(
                          color: active ? color : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _offsetForSection(int index) {
    const estimatedSectionHeight = 220.0;
    return (index * estimatedSectionHeight)
        .clamp(0.0, _scroll.position.maxScrollExtent);
  }

  Widget _buildContent(EbookModel ebook, Color color) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: ebook.sections.length,
      itemBuilder: (context, i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: _SectionWidget(
            section: ebook.sections[i],
            themeColor: color,
            index: i,
          ),
        );
      },
    );
  }

  Widget _buildFooter(Color color) {
    if (_completed) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'E-book concluído! Agora pratique nas trilhas.',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: Semantics(
          button: true,
          label: 'Marcar e-book como concluído',
          child: ElevatedButton.icon(
            onPressed: _markComplete,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('MARCAR COMO CONCLUÍDO'),
          ),
        ),
      ),
    );
  }
}

// ── Renderer de seção ────────────────────────────────────────────
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
        // Título da seção
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
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
        return _formulaBlock(
            section.formula ?? '', section.explanation ?? '');
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
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
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
