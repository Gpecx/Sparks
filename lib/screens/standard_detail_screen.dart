import 'package:spark_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/screens/video_preview_screen.dart';
import 'package:spark_app/services/standards_service.dart';
import 'package:spark_app/models/standard_metadata.dart';

/// Tela híbrida: exibe detalhes técnicos da norma + seção PowerPlay de vídeos.
/// Aceita [standardId] como parâmetro de rota (ex: 'nr-10').
/// Se nulo, exibe a tela genérica de PowerPlay para retrocompatibilidade.
class StandardDetailScreen extends StatefulWidget {
  final String? standardId;
  const StandardDetailScreen({super.key, this.standardId});

  @override
  State<StandardDetailScreen> createState() => _StandardDetailScreenState();
}

class _StandardDetailScreenState extends State<StandardDetailScreen> {
  StandardMetadata? _standard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStandard();
  }

  Future<void> _loadStandard() async {
    final id = widget.standardId;
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final s = await StandardsService().getStandard(id);
      if (!mounted) return;
      setState(() {
        _standard = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.stdErrorLoading;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  // PowerPlay badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, color: AppColors.primary, size: 14),
                        SizedBox(width: 4),
                        Text(AppLocalizations.of(context)!.powerplayTitle, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _error != null
                      ? _buildError()
                      : SingleChildScrollView(
                          child: widget.standardId != null && _standard != null
                              ? _buildDetailedView()
                              : _buildGenericPowerPlay(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(_error ?? AppLocalizations.of(context)!.stdUnknownError, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _loadStandard();
                },
                child: Text(AppLocalizations.of(context)!.tryAgain),
              ),
            ],
          ),
        ),
      );

  // ── Vista detalhada (norma específica + PowerPlay) ──────────────────────────
  Widget _buildDetailedView() {
    final s = _standard!;
    Color accent;
    try {
      final hex = s.colorHex.replaceAll('#', '');
      accent = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      accent = AppColors.primary;
    }

    return Column(
      children: [
        const SizedBox(height: 16),

        // ── Hero da Norma ──────────────────────────────────────────────────
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.card,
            border: Border.all(color: accent, width: 2.5),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 6),
            ],
          ),
          child: Center(
            child: Text(
              s.code,
              textAlign: TextAlign.center,
              style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),

        const SizedBox(height: 24),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // ── Título ────────────────────────────────────────────────────────
        Text(
          s.code,
          style: TextStyle(color: accent, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        const SizedBox(height: 6),
        Text(
          s.title,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),

        // ── Descrição ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            s.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 24),

        // ── Feature chips ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _featureChip(Icons.security, AppLocalizations.of(context)!.stdSafety),
              _featureChip(Icons.assignment_outlined, AppLocalizations.of(context)!.stdTechnicalStandard),
              _featureChip(Icons.verified_outlined, 'MTE'),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Divisor PowerPlay ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(AppLocalizations.of(context)!.powerplayTitle, style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(AppLocalizations.of(context)!.stdVideosAbout(s.code), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Lista de vídeos ────────────────────────────────────────────────
        _buildVideoList(s.code),

        const SizedBox(height: 32),
      ],
    );
  }

  // ── Vista genérica PowerPlay (sem ID específico) ────────────────────────────
  Widget _buildGenericPowerPlay() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.card,
            border: Border.all(color: AppColors.primary, width: 2.5),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 6)],
          ),
          child: const Icon(Icons.play_arrow, color: AppColors.primary, size: 46),
        ),
        const SizedBox(height: 24),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text(AppLocalizations.of(context)!.powerplayTitle, style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, letterSpacing: 3)),
        const SizedBox(height: 6),
        Text(AppLocalizations.of(context)!.stdNetflixTagline, style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            AppLocalizations.of(context)!.stdPowerplayDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _featureChip(Icons.videocam_outlined, AppLocalizations.of(context)!.stdFeatVideoClasses),
              _featureChip(Icons.cases_outlined, AppLocalizations.of(context)!.stdFeatRealCases),
              _featureChip(Icons.offline_bolt_outlined, AppLocalizations.of(context)!.stdFeatOffline),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {},
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppLocalizations.of(context)!.stdAccessPowerplay, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  SizedBox(width: 10),
                  Icon(Icons.open_in_new, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.stdMaybeLater, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildVideoList(String? normCode) {
    final videos = _videosFor(normCode);
    return SizedBox(
      height: 195,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: videos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final v = videos[i];
          return GestureDetector(
            onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => VideoPreviewScreen(title: v['title']!))),
            child: _videoCard(v['title']!, v['duration']!, i == 0),
          );
        },
      ),
    );
  }

  List<Map<String, String>> _videosFor(String? normCode) {
    final code = normCode?.toUpperCase();
    if (code == null) {
      return [
        {'title': AppLocalizations.of(context)!.stdVidPanelsAdv, 'duration': '12:45'},
        {'title': AppLocalizations.of(context)!.stdVidHvInspection, 'duration': '8:30'},
        {'title': AppLocalizations.of(context)!.stdVidNr35Epi, 'duration': '15:20'},
      ];
    }
    // Mapeamento básico de vídeos por norma
    final Map<String, List<Map<String, String>>> catalog = {
      'NR-10': [
        {'title': AppLocalizations.of(context)!.stdVidNr10Fundamentals, 'duration': '18:20'},
        {'title': AppLocalizations.of(context)!.stdVidPanelsAdv, 'duration': '12:45'},
        {'title': AppLocalizations.of(context)!.stdVidLoto, 'duration': '9:10'},
      ],
      'NR-35': [
        {'title': AppLocalizations.of(context)!.stdVidNr35Heights, 'duration': '14:00'},
        {'title': AppLocalizations.of(context)!.stdVidNr35Anchorage, 'duration': '15:20'},
        {'title': AppLocalizations.of(context)!.stdVidFallStructure, 'duration': '11:05'},
      ],
      'NR-12': [
        {'title': AppLocalizations.of(context)!.stdVidNr12Machines, 'duration': '16:30'},
        {'title': AppLocalizations.of(context)!.stdVidNr12Risk, 'duration': '10:15'},
        {'title': AppLocalizations.of(context)!.stdVidPress, 'duration': '8:50'},
      ],
      'NR-33': [
        {'title': AppLocalizations.of(context)!.stdVidNr33Concepts, 'duration': '13:00'},
        {'title': AppLocalizations.of(context)!.stdVidNr33Entry, 'duration': '17:40'},
        {'title': AppLocalizations.of(context)!.stdVidConfinedRescue, 'duration': '9:30'},
      ],
    };

    return catalog[code] ??
        [
          {'title': AppLocalizations.of(context)!.stdVidIntro(code), 'duration': '10:00'},
          {'title': AppLocalizations.of(context)!.stdVidPractical(code), 'duration': '12:00'},
          {'title': AppLocalizations.of(context)!.stdVidCaseWith(code), 'duration': '8:00'},
        ];
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _videoCard(String title, String duration, bool isNew) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Stack(
            children: [
              Container(
                height: 130,
                width: 240,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                  gradient: LinearGradient(
                    colors: [AppColors.greenDark.withValues(alpha: 0.6), AppColors.background],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Icon(Icons.play_arrow, color: AppColors.primary, size: 26),
                  ),
                ),
              ),
              if (isNew)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(5)),
                    child: Text(AppLocalizations.of(context)!.stdNew, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: Text(duration, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
