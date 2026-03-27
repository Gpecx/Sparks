import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  MODELOS
// ─────────────────────────────────────────────────────────────────

/// Uma zona clicável dentro da cena desenhada.
class HitZone {
  final Rect rect;          // posição/tamanho em coordenadas do CustomPainter
  final String id;          // identificador único dentro do nível
  final String errorMessage;

  const HitZone({
    required this.rect,
    required this.id,
    required this.errorMessage,
  });
}

/// Um nível completo do laboratório.
class InspectionLevel {
  final String title;
  final String instruction;
  final String completionMessage;
  final Widget Function(Set<String> foundIds) sceneBuilder;
  final List<HitZone> hitZones;
  final double originalWidth;
  final double originalHeight;

  const InspectionLevel({
    required this.title,
    required this.instruction,
    required this.completionMessage,
    required this.sceneBuilder,
    required this.hitZones,
    required this.originalWidth,
    required this.originalHeight,
  });
}

// ─────────────────────────────────────────────────────────────────
//  TELA PRINCIPAL
// ─────────────────────────────────────────────────────────────────

class ErrorSimulationScreen extends StatefulWidget {
  const ErrorSimulationScreen({super.key});

  @override
  State<ErrorSimulationScreen> createState() =>
      _ErrorSimulationScreenState();
}

// SECRETO DE SÊNIOR: Mudamos de SingleTickerProviderStateMixin para TickerProviderStateMixin 
// porque agora temos 2 animações (Pulso e Tremida)!
class _ErrorSimulationScreenState extends State<ErrorSimulationScreen>
    with TickerProviderStateMixin {
  int _currentLevelIndex = 0;
  final Set<String> _foundIds = {};
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  // Controlador do Pulso (Glow vermelho nas falhas)
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Novo controlador para o efeito de "Tremida" (Shake ao errar o clique)
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // ── Lista de Níveis ─────────────────────────────────────────────
  late final List<InspectionLevel> _levels = [
    // LAB-01 · Caixa de Tomada Residencial
    InspectionLevel(
      title: 'LAB-01',
      instruction: 'Inspecione a caixa de tomada.\nEncontre os 2 riscos ocultos.',
      completionMessage: '✓ Inspeção concluída! +50 XP',
      hitZones: const [
        HitZone(
          id: 'fio',
          rect: Rect.fromLTWH(200, 140, 85, 55),
          errorMessage:
              '⚡ RISCO · Fio terra desencapado — cobre exposto sem isolamento verde/amarelo.',
        ),
        HitZone(
          id: 'prot',
          rect: Rect.fromLTWH(270, 68, 85, 65),
          errorMessage:
              '⚠ NORMA · Tomada sem proteção infantil (NBR 14136). Abertura exposta.',
        ),
      ],
      sceneBuilder: (foundIds) => _TomadaScene(foundIds: foundIds),
      originalWidth: 560,
      originalHeight: 260,
    ),

    // LAB-02 · Quadro de Distribuição
    InspectionLevel(
      title: 'LAB-02',
      instruction: 'Inspecione o Quadro QD-01.\nAtenção às cores dos condutores.',
      completionMessage: '✓ Inspeção concluída! +50 XP',
      hitZones: const [
        HitZone(
          id: 'trip',
          rect: Rect.fromLTWH(55, 132, 230, 42),
          errorMessage:
              '⚡ CRÍTICO · Disjuntor C3 em TRIP. Causa raiz não investigada — reconexão proibida.',
        ),
        HitZone(
          id: 'inv',
          rect: Rect.fromLTWH(130, 195, 50, 50),
          errorMessage:
              '⚡ PERIGO · Fio FASE ligado na barra NEUTRO. Inversão de polaridade — risco de choque com disjuntor desligado.',
        ),
      ],
      sceneBuilder: (foundIds) => _QuadroScene(foundIds: foundIds),
      originalWidth: 560,
      originalHeight: 320,
    ),

    // LAB-03 · Painel Industrial
    InspectionLevel(
      title: 'LAB-03',
      instruction: 'Inspecione o painel industrial.\n3 não-conformidades presentes.',
      completionMessage: '✓ Inspeção concluída! +50 XP',
      hitZones: const [
        HitZone(
          id: 'rele',
          rect: Rect.fromLTWH(268, 35, 90, 68),
          errorMessage:
              '⚡ CRÍTICO · Relé térmico em TRIP sem reset autorizado. Motor com histórico de sobrecarga.',
        ),
        HitZone(
          id: 'borda',
          rect: Rect.fromLTWH(145, 238, 65, 35),
          errorMessage:
              '⚠ RISCO · Cabo elétrico sobre borda metálica sem passa-fio. Isolamento sofrerá corte progressivo.',
        ),
        HitZone(
          id: 'paraf',
          rect: Rect.fromLTWH(405, 260, 40, 35),
          errorMessage:
              '⚠ NORMA · Parafuso ausente no gabinete. Grau de proteção IP comprometido.',
        ),
      ],
      sceneBuilder: (foundIds) => _PainelIndustrialScene(foundIds: foundIds),
      originalWidth: 560,
      originalHeight: 310,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Inicializando o controlador da tremida (rápido, dura só 400ms)
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shakeCtrl.dispose(); // Limpando a memória do novo controlador!
    super.dispose();
  }

  bool _isHintActive = false;

  InspectionLevel get _level => _levels[_currentLevelIndex];
  int get _totalErrors => _level.hitZones.length;
  bool get _levelComplete => _foundIds.length >= _totalErrors;

  void _onTapScene(Offset localPosition, Size renderedSize) {
    if (_levelComplete) return;

    final double scaleX = renderedSize.width / _level.originalWidth;
    final double scaleY = renderedSize.height / _level.originalHeight;

    // Checa se bateu em alguma hitzone
    for (final zone in _level.hitZones) {
      if (_foundIds.contains(zone.id)) continue;
      
      final scaledRect = Rect.fromLTWH(
        zone.rect.left * scaleX,
        zone.rect.top * scaleY,
        zone.rect.width * scaleX,
        zone.rect.height * scaleY,
      );

      if (scaledRect.contains(localPosition)) {
        setState(() {
          _foundIds.add(zone.id);
          _feedbackMessage = zone.errorMessage;
          _feedbackIsError = true;
          if (_levelComplete) {
            _feedbackMessage = _level.completionMessage;
            _feedbackIsError = false;
            _nextLevel();
          }
        });
        return;
      }
    }

    // Toque em área sem erro: Vibra, treme a tela e dá feedback negativo
    HapticFeedback.vibrate(); 
    _shakeCtrl.forward(from: 0.0); 

    setState(() {
      _feedbackMessage = '// Tudo certo por aqui. Continue procurando...';
      _feedbackIsError = false;
    });
  }

  void _activateHint() {
    if (_levelComplete || _isHintActive) return;
    HapticFeedback.lightImpact();
    setState(() => _isHintActive = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isHintActive = false);
    });
  }

  void _nextLevel() {
    if (_currentLevelIndex < _levels.length - 1) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _currentLevelIndex++;
          _foundIds.clear();
          _feedbackMessage = null;
          _feedbackIsError = false;
        });
      });
    } else {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Laboratório Concluído! +150 XP'),
            backgroundColor: AppColors.gold,
          ),
        );
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
            _buildHeader(),
            _buildProgressDots(),
            Expanded(child: _buildScene()),
            _buildFeedbackBar(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4), width: 1),
            ),
            child: Text(
              _level.title,
              style: const TextStyle(
                color: AppColors.primary,
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _level.instruction.split('\n').first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Botão Dica
          if (!_levelComplete)
            GestureDetector(
              onTap: _activateHint,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _isHintActive ? AppColors.gold : const Color(0xFF1a1a0f),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isHintActive ? AppColors.gold : AppColors.gold.withValues(alpha: 0.3),
                  ),
                  boxShadow: _isHintActive ? [
                    BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)
                  ] : [],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 14, color: _isHintActive ? Colors.black : AppColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      'DICA',
                      style: TextStyle(
                        color: _isHintActive ? Colors.black : AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Contador de erros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${_foundIds.length}/$_totalErrors',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dots de progresso ─────────────────────────────────────────
  Widget _buildProgressDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_levels.length, (i) {
          final bool isActive = i == _currentLevelIndex;
          final bool isDone = i < _currentLevelIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.primary
                  : isActive
                      ? AppColors.primary
                      : AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // ── Cena clicável (Com Tremida e Proporção Corrigida) ─────────
  Widget _buildScene() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (context, child) {
          // A mágica acontece aqui: usamos seno para criar a oscilação da tremida
          final dx = math.sin(_shakeAnim.value * math.pi * 6) * 8.0;
          final amplitude = 1.0 - _shakeAnim.value; // Vai perdendo força
          
          return Transform.translate(
            offset: Offset(dx * amplitude, 0.0), // Move no eixo X
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF111811),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Center(
              // AspectRatio mantém as hitboxes perfeitamente alinhadas com o desenho
              child: AspectRatio(
                aspectRatio: _level.originalWidth / _level.originalHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final Size renderSize = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onTapDown: (details) => _onTapScene(details.localPosition, renderSize),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _level.sceneBuilder(_foundIds),
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => CustomPaint(
                              painter: _HitZoneOverlayPainter(
                                hitZones: _level.hitZones,
                                foundIds: _foundIds,
                                pulseValue: _pulseAnim.value,
                                isHintActive: _isHintActive,
                                renderedSize: renderSize,
                                originalSize: Size(_level.originalWidth, _level.originalHeight),
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Barra de feedback ─────────────────────────────────────────
  Widget _buildFeedbackBar() {
    final msg =
        _feedbackMessage ?? '// ${_level.instruction.split('\n').last}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0e0a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _feedbackIsError
              ? AppColors.error.withValues(alpha: 0.6)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _levelComplete
                ? Icons.check_circle_outline
                : _feedbackIsError
                    ? Icons.warning_amber_rounded
                    : Icons.terminal,
            color: _levelComplete
                ? AppColors.primary
                : _feedbackIsError
                    ? AppColors.error
                    : AppColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: _levelComplete
                    ? AppColors.primary
                    : _feedbackIsError
                        ? AppColors.error
                        : AppColors.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  OVERLAY DE HITBOXES (Corrigido para ocultar respostas erradas)
// ─────────────────────────────────────────────────────────────────

class _HitZoneOverlayPainter extends CustomPainter {
  final List<HitZone> hitZones;
  final Set<String> foundIds;
  final double pulseValue;
  final bool isHintActive;
  final Size renderedSize;
  final Size originalSize;

  const _HitZoneOverlayPainter({
    required this.hitZones,
    required this.foundIds,
    required this.pulseValue,
    required this.isHintActive,
    required this.renderedSize,
    required this.originalSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / originalSize.width;
    final double sy = size.height / originalSize.height;

    for (int i = 0; i < hitZones.length; i++) {
      final zone = hitZones[i];
      final bool found = foundIds.contains(zone.id);

      final scaledRect = Rect.fromLTWH(
        zone.rect.left * sx,
        zone.rect.top * sy,
        zone.rect.width * sx,
        zone.rect.height * sy,
      );

      if (found) {
        // Zona encontrada: borda vermelha sólida + fill suave
        final fillPaint = Paint()
          ..color = AppColors.error.withValues(alpha: 0.15 + (pulseValue * 0.1))
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = AppColors.error
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final rRect = RRect.fromRectAndRadius(scaledRect, const Radius.circular(5));
        canvas.drawRRect(rRect, fillPaint);
        canvas.drawRRect(rRect, borderPaint);

        // Ícone "!"
        final tp = TextPainter(
          text: const TextSpan(
            text: '!',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            scaledRect.center.dx - tp.width / 2,
            scaledRect.center.dy - tp.height / 2,
          ),
        );
      } else {
        // Zona não encontrada: Só destacamos se a dica foi ativada!
        final bool isFirstMissing = (!found && hitZones.firstWhere((z) => !foundIds.contains(z.id)).id == zone.id);

        if (isHintActive && isFirstMissing) {
           final highlightPaint = Paint()
            ..color = AppColors.gold.withValues(alpha: 0.5 + (pulseValue * 0.4))
            ..style = PaintingStyle.fill;
          final borderH = Paint()
            ..color = AppColors.gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0;

          final rRect = RRect.fromRectAndRadius(scaledRect, const Radius.circular(5));
          canvas.drawRRect(rRect, highlightPaint);
          canvas.drawRRect(rRect, borderH);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HitZoneOverlayPainter old) =>
      old.pulseValue != pulseValue || old.foundIds != foundIds || old.isHintActive != isHintActive || old.renderedSize != renderedSize;
}

// ─────────────────────────────────────────────────────────────────
//  CENA 1 — CAIXA DE TOMADA RESIDENCIAL
// ─────────────────────────────────────────────────────────────────

class _TomadaScene extends StatelessWidget {
  final Set<String> foundIds;
  const _TomadaScene({required this.foundIds});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 560 / 260,
      child: CustomPaint(painter: _TomadaPainter(foundIds: foundIds)),
    );
  }
}

class _TomadaPainter extends CustomPainter {
  final Set<String> foundIds;
  const _TomadaPainter({required this.foundIds});

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 560;
    final double sy = size.height / 260;

    void rect(Rect r, Color fill,
        {Color? stroke, double sw = 1, double rx = 0}) {
      final scaled = Rect.fromLTWH(
          r.left * sx, r.top * sy, r.width * sx, r.height * sy);
      final rr = RRect.fromRectAndRadius(scaled, Radius.circular(rx * sx));
      canvas.drawRRect(rr, Paint()..color = fill);
      if (stroke != null) {
        canvas.drawRRect(
            rr,
            Paint()
              ..color = stroke
              ..style = PaintingStyle.stroke
              ..strokeWidth = sw);
      }
    }

    void line(Offset a, Offset b, Color color,
        {double sw = 2, bool dashed = false}) {
      final pa = Offset(a.dx * sx, a.dy * sy);
      final pb = Offset(b.dx * sx, b.dy * sy);
      final paint = Paint()
        ..color = color
        ..strokeWidth = sw * sx
        ..strokeCap = StrokeCap.round;
      if (dashed) {
        const dash = 5.0;
        const gap = 3.0;
        final total = (pb - pa).distance;
        final dir = (pb - pa) / total;
        double d = 0;
        while (d < total) {
          canvas.drawLine(pa + dir * d, pa + dir * (d + dash).clamp(0, total), paint);
          d += dash + gap;
        }
      } else {
        canvas.drawLine(pa, pb, paint);
      }
    }

    void circle(Offset center, double r, Color fill,
        {Color? stroke, double sw = 1}) {
      final c = Offset(center.dx * sx, center.dy * sy);
      canvas.drawCircle(c, r * sx, Paint()..color = fill);
      if (stroke != null) {
        canvas.drawCircle(
            c,
            r * sx,
            Paint()
              ..color = stroke
              ..style = PaintingStyle.stroke
              ..strokeWidth = sw);
      }
    }

    void text(String t, Offset pos, Color color,
        {double fs = 8, bool mono = true, TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            color: color,
            fontSize: fs * sx,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout();
      final dx = align == TextAlign.center ? pos.dx * sx - tp.width / 2 : pos.dx * sx;
      tp.paint(canvas, Offset(dx, pos.dy * sy));
    }

    // ── Fundo ──────────────────────────────────────────
    rect(Rect.fromLTWH(0, 0, 560, 260), const Color(0xFF111811));

    // Grid de fundo
    final gridPaint = Paint()
      ..color = const Color(0xFF141e14)
      ..strokeWidth = 0.5;
    for (double x = 0; x < 560; x += 20) {
      canvas.drawLine(Offset(x * sx, 0), Offset(x * sx, size.height), gridPaint);
    }
    for (double y = 0; y < 260; y += 20) {
      canvas.drawLine(Offset(0, y * sy), Offset(size.width, y * sy), gridPaint);
    }

    // ── Caixa embutida ─────────────────────────────────
    rect(Rect.fromLTWH(130, 30, 300, 185), const Color(0xFF0d150d),
        stroke: const Color(0xFF1a2e1a), sw: 1.5, rx: 6);
    rect(Rect.fromLTWH(140, 40, 280, 165), const Color(0xFF0f1a0f),
        stroke: const Color(0xFF1f341f), rx: 4);

    // Frame da placa
    rect(Rect.fromLTWH(158, 55, 244, 120), const Color(0xFF1a2a1a),
        stroke: const Color(0xFF2a3e2a), sw: 1.5, rx: 5);
    rect(Rect.fromLTWH(166, 63, 228, 104), const Color(0xFF151f15),
        stroke: const Color(0xFF253525), rx: 3);

    // Tomada ESQUERDA
    rect(Rect.fromLTWH(178, 76, 76, 78), const Color(0xFF0d170d),
        stroke: const Color(0xFF1a2e1a), rx: 4);
    rect(Rect.fromLTWH(188, 92, 14, 16), const Color(0xFF0a0a0a),
        stroke: const Color(0xFF222222), rx: 2);
    rect(Rect.fromLTWH(208, 92, 14, 16), const Color(0xFF0a0a0a),
        stroke: const Color(0xFF222222), rx: 2);
    rect(Rect.fromLTWH(188, 122, 14, 16), const Color(0xFF0a0a0a),
        stroke: const Color(0xFF222222), rx: 2);
    rect(Rect.fromLTWH(208, 122, 14, 16), const Color(0xFF0a0a0a),
        stroke: const Color(0xFF222222), rx: 2);
    circle(const Offset(215, 115), 4, const Color(0xFF1a2a1a),
        stroke: const Color(0xFF2a3a2a));

    // Tomada DIREITA (com fissura = erro 2)
    rect(Rect.fromLTWH(270, 76, 76, 78), const Color(0xFF0d170d),
        stroke: const Color(0xFF1a2e1a), rx: 4);
    rect(Rect.fromLTWH(280, 92, 14, 16), const Color(0xFF0a0a0a),
        stroke: const Color(0xFF222222), rx: 2);
    rect(Rect.fromLTWH(300, 92, 14, 16), const Color(0xFF0a0a0a),
        stroke: const Color(0xFF222222), rx: 2);
    rect(Rect.fromLTWH(280, 122, 14, 16), const Color(0xFF0a0a0a),
        stroke: const Color(0xFF222222), rx: 2);
    rect(Rect.fromLTWH(300, 122, 14, 16), const Color(0xFF0a0a0a),
        stroke: const Color(0xFF222222), rx: 2);
    circle(const Offset(297, 115), 4, const Color(0xFF1a2a1a),
        stroke: const Color(0xFF2a3a2a));

    // Fissura na tomada direita (erro visual)
    final fissuraPaint = Paint()
      ..color = AppColors.error.withValues(alpha: 0.6)
      ..strokeWidth = 1 * sx
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(286 * sx, 78 * sy), Offset(298 * sx, 93 * sy), fissuraPaint);
    canvas.drawLine(Offset(292 * sx, 78 * sy), Offset(304 * sx, 91 * sy), fissuraPaint);

    // Parafusos da placa
    for (final pos in [
      const Offset(170, 68),
      const Offset(390, 68),
      const Offset(170, 152),
      const Offset(390, 152),
    ]) {
      circle(pos, 3, const Color(0xFF1a2a1a), stroke: const Color(0xFF2a3a2a));
    }

    // ── Conduíte ───────────────────────────────────────
    rect(Rect.fromLTWH(266, 175, 28, 80), const Color(0xFF141e14),
        stroke: const Color(0xFF1a2e1a), rx: 3);

    // Fio fase (vermelho) — correto
    line(const Offset(272, 175), const Offset(272, 165), const Color(0xFFC62828), sw: 3);
    line(const Offset(272, 165), const Offset(258, 165), const Color(0xFFC62828), sw: 3);
    line(const Offset(258, 165), const Offset(258, 148), const Color(0xFFC62828), sw: 3);

    // Fio neutro (azul) — correto
    line(const Offset(284, 175), const Offset(284, 165), const Color(0xFF1565C0), sw: 3);
    line(const Offset(284, 165), const Offset(296, 165), const Color(0xFF1565C0), sw: 3);
    line(const Offset(296, 165), const Offset(296, 148), const Color(0xFF1565C0), sw: 3);

    // ERRO: fio terra desencapado (cobre exposto, cor âmbar/laranja)
    line(const Offset(280, 175), const Offset(280, 162), const Color(0xFF1D9E75),
        sw: 2.5);
    line(const Offset(280, 162), const Offset(232, 162), const Color(0xFF1D9E75),
        sw: 2.5);
    // trecho exposto sem isolamento
    line(const Offset(238, 162), const Offset(232, 162), const Color(0xFFF5A623),
        sw: 3.5);
    line(const Offset(232, 162), const Offset(232, 145), const Color(0xFFF5A623),
        sw: 3.5);
    circle(const Offset(235, 162), 3, AppColors.error.withValues(alpha: 0.8));
    circle(const Offset(231, 158), 2, const Color(0xFFF5A623).withValues(alpha: 0.6));

    // ── Legenda lateral ────────────────────────────────
    rect(Rect.fromLTWH(430, 40, 115, 80), const Color(0xFF0a0e0a),
        stroke: const Color(0xFF1a2a1a), rx: 4);
    text('NBR 5410', const Offset(438, 52), const Color(0xFF2a4a3a));
    line(const Offset(438, 63), const Offset(460, 63), const Color(0xFF8BC34A), sw: 3);
    text('Terra PE', const Offset(464, 60), const Color(0xFF4a6a5a));
    line(const Offset(438, 77), const Offset(460, 77), const Color(0xFF42A5F5), sw: 3);
    text('Neutro N', const Offset(464, 74), const Color(0xFF4a6a5a));
    line(const Offset(438, 91), const Offset(460, 91), const Color(0xFFC62828), sw: 3);
    text('Fase', const Offset(464, 88), const Color(0xFF4a6a5a));
    text('ERRO: terra', const Offset(438, 108), AppColors.error, fs: 7);
    text('exposto', const Offset(438, 116), AppColors.error.withValues(alpha: 0.7), fs: 7);
  }

  @override
  bool shouldRepaint(_TomadaPainter old) => old.foundIds != foundIds;
}

// ─────────────────────────────────────────────────────────────────
//  CENA 2 — QUADRO DE DISTRIBUIÇÃO
// ─────────────────────────────────────────────────────────────────

class _QuadroScene extends StatelessWidget {
  final Set<String> foundIds;
  const _QuadroScene({required this.foundIds});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 560 / 320,
      child: CustomPaint(painter: _QuadroPainter(foundIds: foundIds)),
    );
  }
}

class _QuadroPainter extends CustomPainter {
  final Set<String> foundIds;
  const _QuadroPainter({required this.foundIds});

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 560;
    final double sy = size.height / 320;

    void rect(Rect r, Color fill,
        {Color? stroke, double sw = 1, double rx = 0}) {
      final s = Rect.fromLTWH(r.left*sx, r.top*sy, r.width*sx, r.height*sy);
      final rr = RRect.fromRectAndRadius(s, Radius.circular(rx * sx));
      canvas.drawRRect(rr, Paint()..color = fill);
      if (stroke != null) {
        canvas.drawRRect(rr, Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = sw);
      }
    }

    void line(Offset a, Offset b, Color c, {double sw = 2}) {
      canvas.drawLine(Offset(a.dx*sx, a.dy*sy), Offset(b.dx*sx, b.dy*sy),
        Paint()..color=c..strokeWidth=sw*sx..strokeCap=StrokeCap.round);
    }

    void circle(Offset center, double r, Color fill, {Color? stroke, double sw=1}) {
      canvas.drawCircle(Offset(center.dx*sx, center.dy*sy), r*sx, Paint()..color=fill);
      if (stroke != null) {
        canvas.drawCircle(Offset(center.dx*sx, center.dy*sy), r*sx,
          Paint()..color=stroke..style=PaintingStyle.stroke..strokeWidth=sw);
      }
    }

    void text(String t, Offset pos, Color color, {double fs=8, TextAlign align=TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text:t, style: TextStyle(color:color, fontSize:fs*sx, fontFamily:'monospace')),
        textDirection: TextDirection.ltr, textAlign: align,
      )..layout();
      final dx = align == TextAlign.center ? pos.dx*sx - tp.width/2 : pos.dx*sx;
      tp.paint(canvas, Offset(dx, pos.dy*sy));
    }

    // Fundo
    rect(Rect.fromLTWH(0,0,560,320), const Color(0xFF111811));
    final gp = Paint()..color=const Color(0xFF141e14)..strokeWidth=0.5;
    for (double x=0; x<560; x+=20) canvas.drawLine(Offset(x*sx,0), Offset(x*sx,size.height), gp);
    for (double y=0; y<320; y+=20) canvas.drawLine(Offset(0,y*sy), Offset(size.width,y*sy), gp);

    // Gabinete
    rect(Rect.fromLTWH(50,12,370,285), const Color(0xFF0a1a12),
        stroke: AppColors.primary.withValues(alpha: 0.7), sw: 1.2, rx: 6);
    rect(Rect.fromLTWH(55,17,360,275), const Color(0xFF0d1a0d),
        stroke: const Color(0xFF1a2e1a), rx: 4);
    // Header
    rect(Rect.fromLTWH(55,17,360,22), const Color(0xFF081008), rx: 4);
    text('QD-01 · QUADRO DE DISTRIBUIÇÃO', const Offset(235,29), AppColors.primary,
        fs: 8, align: TextAlign.center);

    // Disjuntor Geral
    rect(Rect.fromLTWH(75,48,155,26), const Color(0xFF0f1f0f),
        stroke: const Color(0xFF1a3a1a), rx: 3);
    text('GERAL · 63A', const Offset(120,63), const Color(0xFF4a6a5a));
    rect(Rect.fromLTWH(218,51,12,18), const Color(0xFF1a2a1a),
        stroke: AppColors.primary, rx: 2);
    rect(Rect.fromLTWH(220,52,8,9), AppColors.primary.withValues(alpha: 0.8), rx: 1);

    line(const Offset(65,86), const Offset(410,86), const Color(0xFF1a2e1a));

    // Linhas C1–C4
    final circuits = [
      ('C1 · ILUMINAÇÃO · 10A', 92, false),
      ('C2 · TOMADAS · 20A', 118, false),
      ('C3 · CHUVEIRO · 40A', 144, true), // TRIP
      ('C4 · AR-COND. · 20A', 170, false),
    ];

    for (final (label, y, isTrip) in circuits) {
      final bgColor = isTrip ? const Color(0xFF1a0808) : const Color(0xFF0a140a);
      final borderColor = isTrip ? const Color(0xFF3a1010) : const Color(0xFF1a2a1a);
      rect(Rect.fromLTWH(65, y.toDouble(), 165, 20), bgColor,
          stroke: borderColor, sw: isTrip ? 1 : 0.5, rx: 2);
      text(label, Offset(73, y + 13.0), isTrip ? const Color(0xFF993C1D) : const Color(0xFF4a6a5a));
      rect(Rect.fromLTWH(237, y + 2.0, 12, 16), isTrip ? const Color(0xFF2a0808) : const Color(0xFF1a2a1a),
          stroke: isTrip ? const Color(0xFF993C1D) : const Color(0xFF1a3a1a), rx: 2);
      rect(Rect.fromLTWH(239, y + 3.0, 8, 8),
          isTrip ? AppColors.error.withValues(alpha: 0.9) : AppColors.primary.withValues(alpha: 0.7),
          rx: 1);
      if (isTrip) {
        text('TRIP', Offset(256, y + 11.0), AppColors.error, fs: 6);
      }
    }

    // Barra Neutro
    rect(Rect.fromLTWH(65,202,330,14), const Color(0xFF0d1a0d),
        stroke: const Color(0xFF1a2e1a), rx: 2);
    text('BARRA NEUTRO (N)', const Offset(230, 212), const Color(0xFF2a4a3a),
        fs: 7, align: TextAlign.center);

    // Parafusos na barra neutro
    for (final cx in [85.0, 108.0, 131.0]) {
      circle(Offset(cx, 209), 4, const Color(0xFF1a2a1a),
          stroke: const Color(0xFF2255aa), sw: 1);
    }
    // ERRO: parafuso com fio fase no neutro
    circle(const Offset(154, 209), 4, const Color(0xFF1a0808),
        stroke: AppColors.error, sw: 1.2);
    line(const Offset(154,213), const Offset(154,226), const Color(0xFFC62828), sw:2);
    circle(const Offset(150,232), 2.5, AppColors.error.withValues(alpha: 0.8));
    // X de inversão
    final xPaint = Paint()..color=AppColors.error..strokeWidth=1.5*sx..strokeCap=StrokeCap.round;
    canvas.drawLine(Offset(158*sx,218*sy), Offset(165*sx,224*sy), xPaint);
    canvas.drawLine(Offset(165*sx,218*sy), Offset(158*sx,224*sy), xPaint);

    // Barra Terra
    rect(Rect.fromLTWH(65,226,220,14), const Color(0xFF0a140a),
        stroke: const Color(0xFF1a3a1a), rx: 2);
    text('BARRA TERRA (PE)', const Offset(175, 236), const Color(0xFF2a4a3a),
        fs: 7, align: TextAlign.center);

    // Fios descendo — NBR 5410 corretos
    // Terra (verde + amarelo)
    line(const Offset(90,240), const Offset(90,285), const Color(0xFF8BC34A), sw:3);
    line(const Offset(90,248), const Offset(90,255), const Color(0xFFFFD600), sw:3);
    line(const Offset(90,263), const Offset(90,270), const Color(0xFFFFD600), sw:3);
    // Neutro (azul)
    line(const Offset(113,216), const Offset(113,285), const Color(0xFF42A5F5), sw:3);
    // Fase preto
    line(const Offset(136,216), const Offset(136,285), const Color(0xFF444444), sw:3);
    line(const Offset(136,216), const Offset(136,285), const Color(0xFF666666), sw:1.5);
    // ERRO: fio vermelho (fase) no neutro
    line(const Offset(154,216), const Offset(154,285), const Color(0xFFC62828), sw:3);

    // Terminal
    rect(Rect.fromLTWH(70,285,120,10), const Color(0xFF0a140a),
        stroke: const Color(0xFF1a2a1a), rx: 2);
    text('TERMINAL SAÍDA', const Offset(130,292), const Color(0xFF2a4a3a),
        fs: 6, align: TextAlign.center);

    // Legenda
    rect(Rect.fromLTWH(430,38,115,100), const Color(0xFF0a0e0a),
        stroke: const Color(0xFF1a2a1a), rx: 4);
    text('NBR 5410', const Offset(438,54), const Color(0xFF2a4a3a));
    line(const Offset(438,65), const Offset(458,65), const Color(0xFF8BC34A), sw:3);
    line(const Offset(448,65), const Offset(450,65), const Color(0xFFFFD600), sw:3);
    text('Terra PE', const Offset(462,62), const Color(0xFF4a6a5a));
    line(const Offset(438,79), const Offset(458,79), const Color(0xFF42A5F5), sw:3);
    text('Neutro N', const Offset(462,76), const Color(0xFF4a6a5a));
    line(const Offset(438,93), const Offset(458,93), const Color(0xFF555555), sw:3);
    text('Fase (preto)', const Offset(462,90), const Color(0xFF4a6a5a));
    line(const Offset(438,107), const Offset(458,107), const Color(0xFFC62828), sw:3);
    text('ERRO: fase/N', const Offset(462,104), AppColors.error, fs:7);
    rect(Rect.fromLTWH(438,116,96,10), const Color(0xFF1a0808),
        stroke: const Color(0xFF993C1D), rx: 2);
    text('invertidos!', const Offset(486,122), const Color(0xFF993C1D),
        fs: 6, align: TextAlign.center);
  }

  @override
  bool shouldRepaint(_QuadroPainter old) => old.foundIds != foundIds;
}

// ─────────────────────────────────────────────────────────────────
//  CENA 3 — PAINEL INDUSTRIAL
// ─────────────────────────────────────────────────────────────────

class _PainelIndustrialScene extends StatelessWidget {
  final Set<String> foundIds;
  const _PainelIndustrialScene({required this.foundIds});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 560 / 310,
      child: CustomPaint(painter: _PainelIndustrialPainter(foundIds: foundIds)),
    );
  }
}

class _PainelIndustrialPainter extends CustomPainter {
  final Set<String> foundIds;
  const _PainelIndustrialPainter({required this.foundIds});

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 560;
    final double sy = size.height / 310;

    void rect(Rect r, Color fill, {Color? stroke, double sw=1, double rx=0}) {
      final s = Rect.fromLTWH(r.left*sx, r.top*sy, r.width*sx, r.height*sy);
      final rr = RRect.fromRectAndRadius(s, Radius.circular(rx*sx));
      canvas.drawRRect(rr, Paint()..color=fill);
      if (stroke != null) canvas.drawRRect(rr, Paint()..color=stroke..style=PaintingStyle.stroke..strokeWidth=sw);
    }

    void line(Offset a, Offset b, Color c, {double sw=2}) {
      canvas.drawLine(Offset(a.dx*sx, a.dy*sy), Offset(b.dx*sx, b.dy*sy),
        Paint()..color=c..strokeWidth=sw*sx..strokeCap=StrokeCap.round);
    }

    void circle(Offset center, double r, Color fill, {Color? stroke, double sw=1}) {
      canvas.drawCircle(Offset(center.dx*sx, center.dy*sy), r*sx, Paint()..color=fill);
      if (stroke != null) canvas.drawCircle(Offset(center.dx*sx, center.dy*sy), r*sx,
        Paint()..color=stroke..style=PaintingStyle.stroke..strokeWidth=sw);
    }

    void text(String t, Offset pos, Color color, {double fs=8, TextAlign align=TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text:t, style: TextStyle(color:color, fontSize:fs*sx, fontFamily:'monospace')),
        textDirection: TextDirection.ltr, textAlign: align,
      )..layout();
      final dx = align==TextAlign.center ? pos.dx*sx-tp.width/2 : pos.dx*sx;
      tp.paint(canvas, Offset(dx, pos.dy*sy));
    }

    // Fundo + grid
    rect(Rect.fromLTWH(0,0,560,310), const Color(0xFF111811));
    final gp = Paint()..color=const Color(0xFF141e14)..strokeWidth=0.5;
    for (double x=0; x<560; x+=20) canvas.drawLine(Offset(x*sx,0), Offset(x*sx,size.height), gp);
    for (double y=0; y<310; y+=20) canvas.drawLine(Offset(0,y*sy), Offset(size.width,y*sy), gp);

    // Gabinete
    rect(Rect.fromLTWH(40,10,390,280), const Color(0xFF0c1c0c),
        stroke: AppColors.primary.withValues(alpha: 0.6), sw: 1.5, rx: 5);
    rect(Rect.fromLTWH(45,15,380,270), const Color(0xFF0a140a),
        stroke: const Color(0xFF1a2a1a), rx: 4);
    // Header
    rect(Rect.fromLTWH(45,15,380,20), const Color(0xFF081008), rx: 4);
    text('PAINEL INDUSTRIAL · CMD-CLP-01', const Offset(235,27),
        AppColors.primary, fs: 8, align: TextAlign.center);

    // Parafusos
    for (final pos in [const Offset(52,23), const Offset(419,23), const Offset(52,278)]) {
      circle(pos, 3, const Color(0xFF1a2a1a), stroke: const Color(0xFF2a3a2a), sw: 0.5);
    }
    // ERRO: parafuso faltando (buraco vazio)
    circle(const Offset(419,278), 3, const Color(0xFF1a0808), stroke: AppColors.error, sw: 1);
    text('?', const Offset(425,275), AppColors.error, fs: 7);

    // ── PLC ──────────────────────────────────────────────
    rect(Rect.fromLTWH(58,42,88,110), const Color(0xFF0a1a2a),
        stroke: const Color(0xFF185FA5), sw: 1.2, rx: 3);
    text('PLC · S7', const Offset(102,57), const Color(0xFF378ADD),
        fs: 9, align: TextAlign.center);
    for (int i = 0; i < 4; i++) {
      rect(Rect.fromLTWH(63, 62 + i*14.0, 78, 10), const Color(0xFF060e18),
          stroke: const Color(0xFF0C447C), sw: 0.5, rx: 1);
    }
    final ledColors = [const Color(0xFF00C853), const Color(0xFF00C853),
                       AppColors.error, const Color(0xFF4a6a5a)];
    for (int i = 0; i < 4; i++) {
      circle(Offset(70, 67 + i * 14.0), 3, ledColors[i]);
    }
    text('RUN · OK', const Offset(102, 130), const Color(0xFF378ADD),
        fs: 6, align: TextAlign.center);

    // ── INVERSOR ─────────────────────────────────────────
    rect(Rect.fromLTWH(160,42,100,110), const Color(0xFF0a0a1e),
        stroke: const Color(0xFF534AB7), sw: 1.2, rx: 3);
    text('INVERSOR', const Offset(210,57), const Color(0xFF7F77DD),
        fs: 9, align: TextAlign.center);
    text('VFD · 380V', const Offset(210,68), const Color(0xFF534AB7),
        fs: 7, align: TextAlign.center);
    rect(Rect.fromLTWH(168,74,84,32), const Color(0xFF060614), rx: 2);
    text('60.0Hz', const Offset(210,87), const Color(0xFFAFA9EC),
        fs: 10, align: TextAlign.center);
    text('380V · 12.4A', const Offset(210,100), const Color(0xFF534AB7),
        fs: 7, align: TextAlign.center);
    for (final x in [170.0, 199.0, 228.0]) {
      rect(Rect.fromLTWH(x,114,22,18), const Color(0xFF1a1a2a),
          stroke: const Color(0xFF2a2a4a), rx: 2);
    }

    // ── RELÉ TÉRMICO (TRIP) ───────────────────────────────
    rect(Rect.fromLTWH(275,42,72,56), const Color(0xFF1e0808),
        stroke: const Color(0xFF993C1D), sw: 1.2, rx: 3);
    text('RELÉ', const Offset(311,57), const Color(0xFFD85A30),
        fs: 8, align: TextAlign.center);
    text('TÉRMICO', const Offset(311,68), const Color(0xFF993C1D),
        fs: 7, align: TextAlign.center);
    rect(Rect.fromLTWH(283,74,56,16), const Color(0xFF0e0202), rx: 2);
    text('TRIP!', const Offset(311,86), AppColors.error,
        fs: 9, align: TextAlign.center);

    // ── BOTOEIRA ──────────────────────────────────────────
    rect(Rect.fromLTWH(275,108,72,44), const Color(0xFF0a140a),
        stroke: const Color(0xFF1a2a1a), rx: 3);
    circle(const Offset(296,130), 12, const Color(0xFF0a2a0a),
        stroke: AppColors.primary, sw: 1.5);
    text('ON', const Offset(296,133), AppColors.primary,
        fs: 6, align: TextAlign.center);
    circle(const Offset(330,130), 12, const Color(0xFF2a0808),
        stroke: const Color(0xFF993C1D), sw: 1.5);
    text('OFF', const Offset(330,133), AppColors.error,
        fs: 6, align: TextAlign.center);

    // ── CALHA DE CABOS ────────────────────────────────────
    rect(Rect.fromLTWH(58,165,300,16), const Color(0xFF0d1a0d),
        stroke: const Color(0xFF1a2a1a), rx: 2);
    text('CALHA DE CABOS', const Offset(208,176), const Color(0xFF1a3a1a),
        fs: 7, align: TextAlign.center);

    // Fios saindo da calha — NBR 5410 corretos
    line(const Offset(90,181), const Offset(90,260), const Color(0xFFC62828), sw: 2.5);
    line(const Offset(108,181), const Offset(108,260), const Color(0xFF42A5F5), sw: 2.5);
    line(const Offset(126,181), const Offset(126,260), const Color(0xFFF9A825), sw: 2.5);
    line(const Offset(150,181), const Offset(150,260), const Color(0xFF8BC34A), sw: 2.5);
    line(const Offset(150,228), const Offset(150,235), const Color(0xFFFFD600), sw: 2.5);
    line(const Offset(150,245), const Offset(150,252), const Color(0xFFFFD600), sw: 2.5);

    // ERRO: cabo cinza sem identificação sobre borda
    line(const Offset(190,181), const Offset(190,210), const Color(0xFF888888), sw: 3);
    line(const Offset(190,210), const Offset(220,210), const Color(0xFF888888), sw: 3);
    line(const Offset(220,210), const Offset(220,260), const Color(0xFF888888), sw: 3);
    // Borda metálica sem passa-fio (tracejado vermelho)
    final bordaDashPaint = Paint()
      ..color = AppColors.error
      ..strokeWidth = 1 * sx
      ..style = PaintingStyle.stroke;
    final bordaRect = Rect.fromLTWH(210*sx, 255*sy, 20*sx, 6*sy);
    final bd = [bordaRect.topLeft, bordaRect.topRight, bordaRect.bottomRight, bordaRect.bottomLeft, bordaRect.topLeft];
    for (int i=0; i<4; i++) {
      final a=bd[i]; final b=bd[i+1];
      final total=(b-a).distance;
      final dir=(b-a)/total;
      double d=0;
      while(d<total){
        canvas.drawLine(a+dir*d, a+dir*(d+3).clamp(0,total), bordaDashPaint);
        d+=5;
      }
    }
    // Dano no cabo
    canvas.drawOval(
      Rect.fromCenter(center: Offset(220*sx, 255*sy), width: 8*sx, height: 5*sy),
      Paint()..color=AppColors.error.withValues(alpha: 0.6),
    );

    // Aterramento
    rect(Rect.fromLTWH(58,260,170,12), const Color(0xFF0a140a),
        stroke: const Color(0xFF1a3a1a), rx: 2);
    text('BARRA PE · ATERRAMENTO', const Offset(143,268), const Color(0xFF2a4a3a),
        fs: 6, align: TextAlign.center);

    // Legenda
    rect(Rect.fromLTWH(452,38,96,100), const Color(0xFF0a0e0a),
        stroke: const Color(0xFF1a2a1a), rx: 4);
    text('NBR 5410', const Offset(458,54), const Color(0xFF2a4a3a));
    line(const Offset(458,65), const Offset(478,65), const Color(0xFF8BC34A), sw:2.5);
    line(const Offset(468,65), const Offset(470,65), const Color(0xFFFFD600), sw:2.5);
    text('Terra PE', const Offset(482,62), const Color(0xFF4a6a5a));
    line(const Offset(458,77), const Offset(478,77), const Color(0xFF42A5F5), sw:2.5);
    text('Neutro', const Offset(482,74), const Color(0xFF4a6a5a));
    line(const Offset(458,89), const Offset(478,89), const Color(0xFFC62828), sw:2.5);
    text('Fase', const Offset(482,86), const Color(0xFF4a6a5a));
    line(const Offset(458,101), const Offset(478,101), const Color(0xFFF9A825), sw:2.5);
    text('Proteção', const Offset(482,98), const Color(0xFF4a6a5a));
    line(const Offset(458,113), const Offset(478,113), const Color(0xFF888888), sw:2.5);
    text('ERRO: s/id', const Offset(482,110), AppColors.error, fs:7);
    text('3 riscos', const Offset(475,128), const Color(0xFF993C1D),
        fs: 7, align: TextAlign.center);
  }

  @override
  bool shouldRepaint(_PainelIndustrialPainter old) => old.foundIds != foundIds;
}