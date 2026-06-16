import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/restricted_differential.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class RestrictedDifferentialScreen extends StatefulWidget {
  const RestrictedDifferentialScreen({super.key});

  @override
  State<RestrictedDifferentialScreen> createState() =>
      _RestrictedDifferentialScreenState();
}

class _RestrictedDifferentialScreenState
    extends State<RestrictedDifferentialScreen> {
  RestraintConvention _conv = RestraintConvention.average;

  // Característica (ajustes do relé)
  final _pickup = TextEditingController(text: '0.3');
  final _slope1 = TextEditingController(text: '0.25');
  final _slope2 = TextEditingController(text: '0.6');
  final _knee1 = TextEditingController(text: '2');
  final _knee2 = TextEditingController(text: '6');

  // Ponto de operação (correntes dos enrolamentos, em pu de I_nom)
  final _i1 = TextEditingController(text: '5');
  final _ang1 = TextEditingController(text: '0');
  final _i2 = TextEditingController(text: '5');
  final _ang2 = TextEditingController(text: '180');

  DifferentialOperatingPoint? _point;
  String? _warning;

  @override
  void dispose() {
    for (final c in [
      _pickup, _slope1, _slope2, _knee1, _knee2,
      _i1, _ang1, _i2, _ang2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _calculate() {
    final pk = _p(_pickup);
    final s1 = _p(_slope1);
    final s2 = _p(_slope2);
    final k1 = _p(_knee1);
    final k2 = _p(_knee2);
    final i1 = _p(_i1);
    final a1 = _p(_ang1);
    final i2 = _p(_i2);
    final a2 = _p(_ang2);

    if (pk == null ||
        s1 == null ||
        s2 == null ||
        k1 == null ||
        k2 == null ||
        i1 == null ||
        a1 == null ||
        i2 == null ||
        a2 == null) {
      setState(() {
        _warning = 'Preencha todos os ajustes e as correntes dos enrolamentos.';
        _point = null;
      });
      return;
    }
    if (pk < 0 || s1 < 0 || s2 < 0 || k1 < 0 || k2 < 0) {
      setState(() {
        _warning = 'Ajustes da característica não podem ser negativos.';
        _point = null;
      });
      return;
    }
    if (k2 < k1) {
      setState(() {
        _warning = 'O joelho 2 deve ser ≥ joelho 1.';
        _point = null;
      });
      return;
    }

    final p = evaluateDifferential(
      i1: i1, ang1: a1, i2: i2, ang2: a2,
      convention: _conv,
      pickup: pk, slope1: s1, slope2: s2, knee1: k1, knee2: k2,
    );
    setState(() {
      _warning = null;
      _point = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: '87 — Diferencial c/ Restrição',
      children: [
        _infoBox(),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.restDiffCharDesc,
          subtitle: AppLocalizations.of(context)!.restDiffLimDesc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _pickup, label: AppLocalizations.of(context)!.restDiffPickup),
              ToolField(controller: _slope1, label: AppLocalizations.of(context)!.restDiffSlope1),
              ToolField(controller: _slope2, label: AppLocalizations.of(context)!.restDiffSlope2),
            ]),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(controller: _knee1, label: AppLocalizations.of(context)!.restDiffKnee1),
              ToolField(controller: _knee2, label: AppLocalizations.of(context)!.restDiffKnee2),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.restDiffConv,
          children: [
            ToolSegmented(
              labels: const ['Média', 'Máximo', 'Soma'],
              selected: _conv.index,
              onSelect: (i) => setState(() {
                _conv = RestraintConvention.values[i];
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.restDiffCur,
          subtitle:
              AppLocalizations.of(context)!.restDiffModAng,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _i1, label: AppLocalizations.of(context)!.restDiffI1),
              ToolField(controller: _ang1, label: AppLocalizations.of(context)!.restDiffI1Ang, signed: true),
            ]),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(controller: _i2, label: AppLocalizations.of(context)!.restDiffI2),
              ToolField(controller: _ang2, label: AppLocalizations.of(context)!.restDiffI2Ang, signed: true),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'AVALIAR', onPressed: _calculate),
        if (_warning != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: const [], warning: _warning),
        ],
        if (_point != null) ...[
          const SizedBox(height: 24),
          _verdictBox(_point!),
          const SizedBox(height: 12),
          _resultsPanel(_point!),
          const SizedBox(height: 16),
          _chartCard(_point!),
        ],
      ],
    );
  }

  Widget _verdictBox(DifferentialOperatingPoint p) {
    final color = p.operates ? AppColors.warning : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(p.operates ? Icons.bolt : Icons.shield_outlined,
              color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.operates
                  ? 'OPERA — ponto acima da característica (trip)'
                  : 'RESTRINGE — ponto abaixo da característica (sem trip)',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsPanel(DifferentialOperatingPoint p) {
    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.restDiffIdiff, fmtNumber(p.idiff, decimals: 3)),
      ToolResult(AppLocalizations.of(context)!.restDiffIrest, fmtNumber(p.irest, decimals: 3)),
      ToolResult(AppLocalizations.of(context)!.restDiffLimIrest, fmtNumber(p.threshold, decimals: 3)),
      ToolResult(AppLocalizations.of(context)!.restDiffMargin, fmtNumber(p.margin, decimals: 3)),
    ];
    return ToolResultsPanel(
      results: results,
      title: AppLocalizations.of(context)!.restDiffOp,
      note: 'Idiff = |I1 + I2| (soma fasorial). Em falta passante ideal, '
          'Idiff ≈ 0 mesmo com Irest alta — por isso o relé restringe.',
    );
  }

  Widget _chartCard(DifferentialOperatingPoint p) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              AppLocalizations.of(context)!.restDiffChar,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 1.2,
            child: CustomPaint(
              painter: _CharacteristicPainter(
                pickup: _p(_pickup) ?? 0.3,
                slope1: _p(_slope1) ?? 0.25,
                slope2: _p(_slope2) ?? 0.6,
                knee1: _p(_knee1) ?? 2,
                knee2: _p(_knee2) ?? 6,
                point: p,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.restDiffDesc,
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacteristicPainter extends CustomPainter {
  final double pickup, slope1, slope2, knee1, knee2;
  final DifferentialOperatingPoint point;

  _CharacteristicPainter({
    required this.pickup,
    required this.slope1,
    required this.slope2,
    required this.knee1,
    required this.knee2,
    required this.point,
  });

  static const double _padLeft = 40;
  static const double _padBottom = 26;
  static const double _padTop = 10;
  static const double _padRight = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
        _padLeft, _padTop, size.width - _padRight, size.height - _padBottom);

    // Escala dinâmica: cobre o ponto e a característica com folga.
    final xMax = math.max(knee2 * 1.6, math.max(point.irest * 1.2, 8.0));
    final thAtMax = dualSlopeThreshold(
        irest: xMax,
        pickup: pickup,
        slope1: slope1,
        slope2: slope2,
        knee1: knee1,
        knee2: knee2);
    final yMax = math.max(thAtMax * 1.2, math.max(point.idiff * 1.2, 1.0));

    double sx(double x) => plot.left + (x / xMax).clamp(0.0, 1.0) * plot.width;
    double sy(double y) =>
        plot.bottom - (y / yMax).clamp(0.0, 1.0) * plot.height;

    // Fundo + moldura
    canvas.drawRect(
        plot, Paint()..color = AppColors.background.withValues(alpha: 0.4));
    final grid = Paint()
      ..color = AppColors.cardBorder.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    final textStyle = TextStyle(
        color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 9);

    for (int i = 0; i <= 4; i++) {
      final fx = i / 4;
      final x = plot.left + fx * plot.width;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      _label(canvas, (xMax * fx).toStringAsFixed(1),
          Offset(x, plot.bottom + 4), textStyle, alignCenter: true);
      final y = plot.bottom - fx * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(canvas, (yMax * fx).toStringAsFixed(1),
          Offset(plot.left - 4, y), textStyle, alignRight: true, alignMiddle: true);
    }
    canvas.drawRect(
        plot,
        Paint()
          ..color = AppColors.cardBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    canvas.save();
    canvas.clipRect(plot);

    // Região de operação (acima da curva) levemente sombreada
    final charPath = Path()..moveTo(sx(0), sy(pickup));
    const samples = 120;
    for (int i = 0; i <= samples; i++) {
      final x = xMax * i / samples;
      final th = dualSlopeThreshold(
          irest: x,
          pickup: pickup,
          slope1: slope1,
          slope2: slope2,
          knee1: knee1,
          knee2: knee2);
      charPath.lineTo(sx(x), sy(th));
    }
    // Linha da característica
    canvas.drawPath(
        charPath,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Marcadores dos joelhos
    for (final k in [knee1, knee2]) {
      final th = dualSlopeThreshold(
          irest: k,
          pickup: pickup,
          slope1: slope1,
          slope2: slope2,
          knee1: knee1,
          knee2: knee2);
      canvas.drawCircle(Offset(sx(k), sy(th)), 3,
          Paint()..color = AppColors.primary.withValues(alpha: 0.6));
    }

    // Ponto de operação
    final ptColor = point.operates ? AppColors.warning : AppColors.gold;
    final pt = Offset(sx(point.irest), sy(point.idiff));
    canvas.drawCircle(pt, 6, Paint()..color = ptColor);
    canvas.drawCircle(
        pt,
        6,
        Paint()
          ..color = AppColors.background
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    canvas.restore();

    // Rótulos dos eixos
    _label(canvas, 'Irest', Offset(plot.right - 24, plot.bottom + 12),
        textStyle.copyWith(fontWeight: FontWeight.w700));
    _label(canvas, 'Idiff', Offset(plot.left + 2, plot.top - 2),
        textStyle.copyWith(fontWeight: FontWeight.w700));
  }

  void _label(Canvas canvas, String text, Offset at, TextStyle style,
      {bool alignRight = false,
      bool alignCenter = false,
      bool alignMiddle = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = at.dx;
    double dy = at.dy;
    if (alignRight) dx -= tp.width;
    if (alignCenter) dx -= tp.width / 2;
    if (alignMiddle) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_CharacteristicPainter old) => true;
}
