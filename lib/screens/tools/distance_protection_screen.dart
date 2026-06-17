import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/distance_protection.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class DistanceProtectionScreen extends StatefulWidget {
  const DistanceProtectionScreen({super.key});

  @override
  State<DistanceProtectionScreen> createState() =>
      _DistanceProtectionScreenState();
}

class _DistanceProtectionScreenState extends State<DistanceProtectionScreen> {
  int _mode = 0; // 0 = ajuste de zonas, 1 = característica R-X

  final _zLine = TextEditingController(text: '10');
  final _zAdjacent = TextEditingController(text: '8');
  final _z1Pct = TextEditingController(text: '85');
  final _z2Factor = TextEditingController(text: '0.5');
  final _z3Factor = TextEditingController(text: '1.0');
  final _rtc = TextEditingController(text: '');
  final _rtp = TextEditingController(text: '');

  final _lineAngle = TextEditingController(text: '75');
  final _faultMag = TextEditingController(text: '6');
  final _faultAng = TextEditingController(text: '75');

  List<ToolResult>? _results;
  String? _warning;

  DistanceZones? _zones;
  ImpedanceVector? _fault;
  int? _zoneSeeing;

  @override
  void dispose() {
    for (final c in [
      _zLine, _zAdjacent, _z1Pct, _z2Factor, _z3Factor, _rtc, _rtp,
      _lineAngle, _faultMag, _faultAng,
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

  DistanceZones? _computeZones() {
    final zl = _p(_zLine);
    if (zl == null || zl <= 0) return null;
    return distanceZones(
      lineImpedance: zl,
      adjacentImpedance: _p(_zAdjacent) ?? 0,
      zone1Percent: _p(_z1Pct) ?? 85,
      zone2AdjacentFactor: _p(_z2Factor) ?? 0.5,
      zone3AdjacentFactor: _p(_z3Factor) ?? 1.0,
      rtc: _p(_rtc),
      rtp: _p(_rtp),
    );
  }

  void _calculate() {
    final r = _computeZones();
    if (r == null) {
      setState(() {
        _warning = 'Informe a impedância da linha (Ω) maior que zero.';
        _results = null;
        _zones = null;
      });
      return;
    }

    if (_mode == 0) {
      final results = <ToolResult>[
        ToolResult(AppLocalizations.of(context)!.distProtZ1T, '${fmtNumber(r.z1, decimals: 3)} Ω prim'),
        ToolResult(AppLocalizations.of(context)!.distProtZ2T, '${fmtNumber(r.z2, decimals: 3)} Ω prim'),
        ToolResult(AppLocalizations.of(context)!.distProtZ3T, '${fmtNumber(r.z3, decimals: 3)} Ω prim'),
      ];
      if (r.z1Secondary != null) {
        results.addAll([
          ToolResult(AppLocalizations.of(context)!.distProtZ1Sec, '${fmtNumber(r.z1Secondary!, decimals: 3)} Ω sec'),
          ToolResult(AppLocalizations.of(context)!.distProtZ2Sec, '${fmtNumber(r.z2Secondary!, decimals: 3)} Ω sec'),
          ToolResult(AppLocalizations.of(context)!.distProtZ3Sec, '${fmtNumber(r.z3Secondary!, decimals: 3)} Ω sec'),
        ]);
      }
      setState(() {
        _warning = null;
        _results = results;
        _zones = null;
      });
    } else {
      final la = _p(_lineAngle);
      final fm = _p(_faultMag);
      final fa = _p(_faultAng);
      if (la == null || fm == null || fa == null || fm < 0) {
        setState(() {
          _warning =
              'Preencha ângulo da linha e a impedância de falta (módulo ≥ 0, ângulo).';
          _results = null;
          _zones = null;
        });
        return;
      }
      final fault = faultImpedance(magnitude: fm, angleDeg: fa);
      final zone = fastestZoneSeeing(
        fault: fault, z1: r.z1, z2: r.z2, z3: r.z3, lineAngleDeg: la,
      );
      setState(() {
        _warning = null;
        _results = null;
        _zones = r;
        _fault = fault;
        _zoneSeeing = zone;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: AppLocalizations.of(context)!.tlDistanceProtection,
      children: [
        ToolSegmented(
          labels: const ['Ajuste de zonas', 'Característica R-X'],
          selected: _mode,
          onSelect: (i) => setState(() {
            _mode = i;
            _results = null;
            _zones = null;
            _warning = null;
          }),
        ),
        const SizedBox(height: 16),
        ToolCard(
          title: AppLocalizations.of(context)!.tlImpedances,
          subtitle:
              AppLocalizations.of(context)!.distProtDesc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _zLine, label: AppLocalizations.of(context)!.distProtZLine),
              ToolField(controller: _zAdjacent, label: AppLocalizations.of(context)!.distProtZAdj),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.distProtAdjust,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _z1Pct, label: AppLocalizations.of(context)!.distProtZ1),
              ToolField(controller: _z2Factor, label: AppLocalizations.of(context)!.distProtF2),
              ToolField(controller: _z3Factor, label: AppLocalizations.of(context)!.distProtF3),
            ]),
          ],
        ),
        if (_mode == 0) ...[
          const SizedBox(height: 12),
          ToolCard(
            title: AppLocalizations.of(context)!.distProtConv,
            subtitle: AppLocalizations.of(context)!.distProtZsec,
            children: [
              ToolFieldRow(children: [
                ToolField(controller: _rtc, label: AppLocalizations.of(context)!.distProtRtc),
                ToolField(controller: _rtp, label: AppLocalizations.of(context)!.distProtRtp),
              ]),
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          ToolCard(
            title: AppLocalizations.of(context)!.distProtLineFault,
            subtitle:
                AppLocalizations.of(context)!.distProtRxDesc,
            children: [
              ToolField(controller: _lineAngle, label: AppLocalizations.of(context)!.distProtAngLine),
              const SizedBox(height: 12),
              ToolFieldRow(children: [
                ToolField(controller: _faultMag, label: AppLocalizations.of(context)!.distProtZFault),
                ToolField(
                    controller: _faultAng, label: AppLocalizations.of(context)!.distProtAngFault, signed: true),
              ]),
            ],
          ),
        ],
        const SizedBox(height: 20),
        ToolButton(label: AppLocalizations.of(context)!.tlBtnCalculate, onPressed: _calculate),
        if (_warning != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: const [], warning: _warning),
        ],
        if (_results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(
            results: _results!,
            title: AppLocalizations.of(context)!.distProtReach,
            note:
                'Tempos típicos de referência. Ajuste Z1 a 80–85% e garanta Z2 ≥ 120% da linha.',
          ),
        ],
        if (_zones != null && _fault != null) ...[
          const SizedBox(height: 24),
          _rxVerdict(),
          const SizedBox(height: 12),
          _rxChart(),
        ],
      ],
    );
  }

  Widget _rxVerdict() {
    final z = _zoneSeeing ?? 0;
    final color = z == 1
        ? AppColors.warning
        : z == 0
            ? AppColors.primary
            : AppColors.gold;
    final text = z == 0
        ? 'Falta FORA de todas as zonas (Z1/Z2/Z3 não enxergam)'
        : 'Falta enxergada pela ZONA $z (a mais rápida que pega o ponto)';
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
          Icon(z == 0 ? Icons.gps_off : Icons.gps_fixed, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rxChart() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              AppLocalizations.of(context)!.distProtRx,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _RxPainter(
                z1: _zones!.z1,
                z2: _zones!.z2,
                z3: _zones!.z3,
                lineAngle: _p(_lineAngle) ?? 75,
                fault: _fault!,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legend(AppColors.primary, 'Zona 1'),
              _legend(AppColors.gold, 'Zona 2'),
              _legend(AppColors.warning, 'Zona 3'),
              _legend(AppColors.textPrimary, 'Falta'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

class _RxPainter extends CustomPainter {
  final double z1, z2, z3, lineAngle;
  final ImpedanceVector fault;

  _RxPainter({
    required this.z1,
    required this.z2,
    required this.z3,
    required this.lineAngle,
    required this.fault,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 26.0;
    final plot = Rect.fromLTRB(pad, 10, size.width - 10, size.height - pad);

    final maxR = math.max(z3, fault.magnitude) * 1.15;
    final scale = math.min(plot.width / maxR, plot.height / maxR);
    final origin = Offset(plot.left, plot.bottom);

    Offset toPx(double r, double x) =>
        Offset(origin.dx + r * scale, origin.dy - x * scale);

    final axis = Paint()
      ..color = AppColors.cardBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(origin, Offset(plot.right, origin.dy), axis);
    canvas.drawLine(origin, Offset(origin.dx, plot.top), axis);
    _label(canvas, 'R', Offset(plot.right - 10, origin.dy + 4),
        const TextStyle(color: AppColors.textMuted, fontSize: 10));
    _label(canvas, 'X', Offset(origin.dx + 4, plot.top),
        const TextStyle(color: AppColors.textMuted, fontSize: 10));

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    void drawMho(double reach, Color color) {
      final rad = lineAngle * math.pi / 180.0;
      final cx = reach / 2 * math.cos(rad);
      final cy = reach / 2 * math.sin(rad);
      final center = toPx(cx, cy);
      final radiusPx = reach / 2 * scale;
      canvas.drawCircle(center, radiusPx,
          Paint()..color = color.withValues(alpha: 0.12));
      canvas.drawCircle(
          center,
          radiusPx,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    drawMho(z3, AppColors.warning);
    drawMho(z2, AppColors.gold);
    drawMho(z1, AppColors.primary);

    final rad = lineAngle * math.pi / 180.0;
    canvas.drawLine(
        origin,
        toPx(z3 * math.cos(rad), z3 * math.sin(rad)),
        Paint()
          ..color = AppColors.textMuted.withValues(alpha: 0.5)
          ..strokeWidth = 1);

    final fpt = toPx(fault.r, fault.x);
    canvas.drawCircle(fpt, 6, Paint()..color = AppColors.textPrimary);
    canvas.drawCircle(
        fpt,
        6,
        Paint()
          ..color = AppColors.background
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_RxPainter old) => true;
}
