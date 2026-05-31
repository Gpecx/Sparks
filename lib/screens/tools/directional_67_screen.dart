import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/directional_67.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class Directional67Screen extends StatefulWidget {
  const Directional67Screen({super.key});

  @override
  State<Directional67Screen> createState() => _Directional67ScreenState();
}

class _Directional67ScreenState extends State<Directional67Screen> {
  int _mode = 0; // 0 = 67 (fase), 1 = 67N (neutro)
  int _polKind = 0; // 67N: 0 = 3V0 (tensão), 1 = 3I0 (corrente)

  final _iOpMag = TextEditingController(text: '5');
  final _iOpAng = TextEditingController(text: '45');
  final _polMag = TextEditingController(text: '100');
  final _polAng = TextEditingController(text: '0');
  final _mta = TextEditingController(text: '45');
  final _pickup = TextEditingController(text: '1');

  DirectionalResult? _result;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_iOpMag, _iOpAng, _polMag, _polAng, _mta, _pickup]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _onMode(int i) {
    setState(() {
      _mode = i;
      _result = null;
      _warning = null;
      if (i == 1) {
        _mta.text = '-45';
        _iOpAng.text = '135';
        _polAng.text = '180';
        _pickup.text = '0.5';
      } else {
        _mta.text = '45';
        _iOpAng.text = '45';
        _polAng.text = '0';
        _pickup.text = '1';
      }
    });
  }

  void _calculate() {
    final iom = _p(_iOpMag);
    final ioa = _p(_iOpAng);
    final pm = _p(_polMag);
    final pa = _p(_polAng);
    final mta = _p(_mta);
    final pk = _p(_pickup);
    if (iom == null ||
        ioa == null ||
        pm == null ||
        pa == null ||
        mta == null ||
        pk == null) {
      setState(() {
        _warning = 'Preencha operação, polarização, MTA e pickup.';
        _result = null;
      });
      return;
    }
    if (iom < 0 || pm <= 0 || pk < 0) {
      setState(() {
        _warning =
            'Módulos não podem ser negativos e a polarização deve ser > 0.';
        _result = null;
      });
      return;
    }
    final r = evaluateDirectional(
      iOpMag: iom, iOpAng: ioa, polMag: pm, polAng: pa, mta: mta, pickup: pk,
    );
    setState(() {
      _warning = null;
      _result = r;
    });
  }

  String get _opLabel => _mode == 0 ? 'I fase' : '3I0';
  String get _polLabel {
    if (_mode == 0) return 'V polarização (quadratura)';
    return _polKind == 0 ? '3V0 (tensão residual)' : '3I0 polarização (corrente)';
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Direcional 67 / 67N',
      children: [
        _infoBox(),
        const SizedBox(height: 12),
        ToolSegmented(
          labels: const ['67 (fase)', '67N (neutro)'],
          selected: _mode,
          onSelect: _onMode,
        ),
        if (_mode == 1) ...[
          const SizedBox(height: 12),
          ToolCard(
            title: 'Polarização do 67N',
            children: [
              ToolSegmented(
                labels: const ['Por 3V0 (tensão)', 'Por 3I0 (corrente)'],
                selected: _polKind,
                onSelect: (i) => setState(() => _polKind = i),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        ToolCard(
          title: 'Grandeza de operação',
          subtitle: 'Módulo e ângulo de $_opLabel.',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _iOpMag, label: '$_opLabel (A)'),
              ToolField(controller: _iOpAng, label: 'Âng. (°)', signed: true),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Grandeza de polarização',
          subtitle: _polLabel,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _polMag, label: 'Módulo'),
              ToolField(controller: _polAng, label: 'Âng. (°)', signed: true),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: 'Ajustes do elemento',
          subtitle: 'MTA (ângulo de máximo torque) relativo à polarização.',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _mta, label: 'MTA / RCA (°)', signed: true),
              ToolField(controller: _pickup, label: 'Pickup (A)'),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'AVALIAR', onPressed: _calculate),
        if (_warning != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: const [], warning: _warning),
        ],
        if (_result != null) ...[
          const SizedBox(height: 24),
          _verdictBox(_result!),
          const SizedBox(height: 12),
          _resultsPanel(_result!),
          const SizedBox(height: 16),
          _phasorCard(_result!),
        ],
      ],
    );
  }

  Widget _verdictBox(DirectionalResult r) {
    final color = r.operates
        ? AppColors.primary
        : (r.forward ? AppColors.gold : AppColors.warning);
    final text = r.operates
        ? 'OPERA — falta DIRETA acima do pickup (trip)'
        : r.forward
            ? 'Falta DIRETA, mas abaixo do pickup (sem trip)'
            : 'BLOQUEIA — falta REVERSA (conjugado negativo)';
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
          Icon(
            r.operates
                ? Icons.bolt
                : (r.forward ? Icons.warning_amber : Icons.block),
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsPanel(DirectionalResult r) {
    final results = <ToolResult>[
      ToolResult('Ângulo relativo θ (Iop − pol)',
          '${fmtNumber(r.relativeAngle, decimals: 1)}°'),
      ToolResult('θ − MTA', '${fmtNumber(r.torqueAngle, decimals: 1)}°'),
      ToolResult('Margem angular ao limite',
          '${fmtNumber(r.angularMargin, decimals: 1)}°'),
      ToolResult('Sentido', r.forward ? 'Direta (forward)' : 'Reversa'),
      ToolResult('Acima do pickup', r.abovePickup ? 'Sim' : 'Não'),
    ];
    return ToolResultsPanel(
      results: results,
      title: 'Avaliação direcional',
      note: 'Opera quando a corrente cai em ±90° do MTA (cos(θ−MTA) > 0) e '
          'acima do pickup. Convenções de sinal/ângulo variam por fabricante — '
          'confira no manual do relé.',
    );
  }

  Widget _phasorCard(DirectionalResult r) {
    final mta = _p(_mta) ?? 0;
    final iOpAng = _p(_iOpAng) ?? 0;
    final polAng = _p(_polAng) ?? 0;
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
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Diagrama fasorial e setor de operação',
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
              painter: _PhasorPainter(
                polAngle: polAng,
                opAngle: iOpAng,
                mta: mta,
                operates: r.operates,
                forward: r.forward,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legend(AppColors.primary, 'Polarização'),
              _legend(AppColors.gold, _opLabel),
              _legend(AppColors.textMuted, 'Linha MTA'),
              _legend(
                  AppColors.primary.withValues(alpha: 0.25), 'Zona de operação'),
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
          const Icon(Icons.explore_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Elemento direcional 67 (fase) e 67N (neutro). Verifica se a falta é '
              'direta (opera) ou reversa (bloqueia) e a margem angular. Triagem — '
              'as convenções de polarização e sinal variam por fabricante.',
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

class _PhasorPainter extends CustomPainter {
  final double polAngle;
  final double opAngle;
  final double mta;
  final bool operates;
  final bool forward;

  _PhasorPainter({
    required this.polAngle,
    required this.opAngle,
    required this.mta,
    required this.operates,
    required this.forward,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;

    Offset dir(double deg) {
      final rad = deg * math.pi / 180.0;
      return Offset(math.cos(rad), -math.sin(rad));
    }

    canvas.drawCircle(
        c, radius, Paint()..color = AppColors.background.withValues(alpha: 0.4));

    final mtaAbs = polAngle + mta;
    final sweepStart = mtaAbs - 90;
    final path = Path()..moveTo(c.dx, c.dy);
    const steps = 60;
    for (int i = 0; i <= steps; i++) {
      final a = sweepStart + 180.0 * i / steps;
      final p = c + dir(a) * radius;
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
        path, Paint()..color = AppColors.primary.withValues(alpha: 0.18));

    final axis = Paint()
      ..color = AppColors.cardBorder.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(c.dx - radius, c.dy), Offset(c.dx + radius, c.dy), axis);
    canvas.drawLine(
        Offset(c.dx, c.dy - radius), Offset(c.dx, c.dy + radius), axis);
    canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = AppColors.cardBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    _dashedLine(canvas, c, c + dir(mtaAbs) * radius,
        AppColors.textMuted.withValues(alpha: 0.8));
    _dashedLine(canvas, c, c + dir(mtaAbs + 180) * radius,
        AppColors.textMuted.withValues(alpha: 0.35));

    _arrow(canvas, c, c + dir(polAngle) * radius * 0.92, AppColors.primary, 2.5);
    final opColor = operates
        ? AppColors.gold
        : (forward ? AppColors.gold.withValues(alpha: 0.7) : AppColors.warning);
    _arrow(canvas, c, c + dir(opAngle) * radius * 0.8, opColor, 2.5);
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color, double w) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final d = to - from;
    final len = d.distance;
    if (len < 1) return;
    final ux = d.dx / len, uy = d.dy / len;
    const head = 9.0;
    final left = Offset(
        to.dx - head * (ux * math.cos(0.5) - uy * math.sin(0.5)),
        to.dy - head * (uy * math.cos(0.5) + ux * math.sin(0.5)));
    final right = Offset(
        to.dx - head * (ux * math.cos(-0.5) - uy * math.sin(-0.5)),
        to.dy - head * (uy * math.cos(-0.5) + ux * math.sin(-0.5)));
    canvas.drawLine(to, left, paint);
    canvas.drawLine(to, right, paint);
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    const dash = 6.0, gap = 4.0;
    final total = (to - from).distance;
    if (total == 0) return;
    final ux = (to.dx - from.dx) / total, uy = (to.dy - from.dy) / total;
    double d = 0;
    while (d < total) {
      final s = from + Offset(ux * d, uy * d);
      final e = from +
          Offset(ux * math.min(d + dash, total), uy * math.min(d + dash, total));
      canvas.drawLine(s, e, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_PhasorPainter old) => true;
}
