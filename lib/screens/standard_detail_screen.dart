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
        _error = 'Erro ao carregar norma';
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, color: AppColors.primary, size: 14),
                        SizedBox(width: 4),
                        Text('POWERPLAY', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
              Text(_error ?? 'Erro desconhecido', style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _loadStandard();
                },
                child: const Text('Tentar novamente'),
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
              style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ),

        const SizedBox(height: 24),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // ── Título ────────────────────────────────────────────────────────
        Text(
          s.code,
          style: TextStyle(color: accent, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2),
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
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 24),

        // ── Feature chips ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _featureChip(Icons.security, 'Segurança'),
              const SizedBox(width: 10),
              _featureChip(Icons.assignment_outlined, 'Norma Técnica'),
              const SizedBox(width: 10),
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
                child: const Text('POWERPLAY', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(width: 10),
              Text('Vídeos sobre ${s.code}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
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
        const Text('POWERPLAY', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 3)),
        const SizedBox(height: 6),
        const Text('O Netflix da Engenharia Elétrica', style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Acesse centenas de aulas, estudos de caso e conteúdos exclusivos sobre normas técnicas e engenharia — tudo num só lugar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _featureChip(Icons.videocam_outlined, 'Vídeo Aulas'),
              const SizedBox(width: 10),
              _featureChip(Icons.cases_outlined, 'Casos Reais'),
              const SizedBox(width: 10),
              _featureChip(Icons.offline_bolt_outlined, 'Offline'),
            ],
          ),
        ),
        const SizedBox(height: 28),
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
                child: const Text('EM ALTA', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(width: 10),
              const Text('Recomendados para você', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildVideoList(null),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {},
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('ACESSAR POWERPLAY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2)),
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
          child: const Text('Talvez mais tarde', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
        separatorBuilder: (_, __) => const SizedBox(width: 12),
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
        {'title': 'NR-10: Painéis Elétricos Industriais Avançados', 'duration': '12:45'},
        {'title': 'Estudo de Caso: Inspeção em Alta Tensão', 'duration': '8:30'},
        {'title': 'NR-35: Equipamentos de Proteção Individual', 'duration': '15:20'},
      ];
    }
    // Mapeamento básico de vídeos por norma
    final Map<String, List<Map<String, String>>> catalog = {
      'NR-10': [
        {'title': 'NR-10: Fundamentos de Segurança Elétrica', 'duration': '18:20'},
        {'title': 'NR-10: Painéis Elétricos Industriais Avançados', 'duration': '12:45'},
        {'title': 'Estudo de Caso: LOTO em Subestações', 'duration': '9:10'},
      ],
      'NR-35': [
        {'title': 'NR-35: Trabalho em Altura — Fundamentos', 'duration': '14:00'},
        {'title': 'NR-35: EPIs e Ancoragem Correta', 'duration': '15:20'},
        {'title': 'Estudo de Caso: Queda em Estrutura Metálica', 'duration': '11:05'},
      ],
      'NR-12': [
        {'title': 'NR-12: Segurança em Máquinas Industriais', 'duration': '16:30'},
        {'title': 'NR-12: Zonas de Risco e Proteções', 'duration': '10:15'},
        {'title': 'Estudo de Caso: Acidente em Prensa Hidráulica', 'duration': '8:50'},
      ],
      'NR-33': [
        {'title': 'NR-33: Espaço Confinado — Conceitos', 'duration': '13:00'},
        {'title': 'NR-33: Procedimentos de Entrada Segura', 'duration': '17:40'},
        {'title': 'Simulação: Resgate em Ambiente Confinado', 'duration': '9:30'},
      ],
    };

    return catalog[code] ??
        [
          {'title': '$code: Introdução à Norma', 'duration': '10:00'},
          {'title': '$code: Aplicações Práticas', 'duration': '12:00'},
          {'title': 'Estudo de Caso com $code', 'duration': '8:00'},
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
                    child: const Text('NOVO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
