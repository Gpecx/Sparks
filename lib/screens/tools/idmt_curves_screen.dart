import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/idmt_curves.dart';
import 'package:spark_app/screens/tools/widgets/idmt_curve_picker.dart';
import 'package:spark_app/widgets/sparks_background.dart';
import 'package:spark_app/widgets/pcb_background.dart';

class IdmtCurvesScreen extends StatefulWidget {
  const IdmtCurvesScreen({super.key});

  @override
  State<IdmtCurvesScreen> createState() => _IdmtCurvesScreenState();
}

class _IdmtCurvesScreenState extends State<IdmtCurvesScreen> {
  IdmtCurve _curve = idmtCurves.first;

  final _iPickup = TextEditingController(text: '1');
  final _dial = TextEditingController(text: '1');
  final _iTest = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    for (final c in [_iPickup, _dial, _iTest]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_iPickup, _dial, _iTest]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.'));

  double get _td => _parse(_dial) ?? 0;

  String? get _validationError {
    final ip = _parse(_iPickup);
    final it = _parse(_iTest);
    final td = _parse(_dial);
    if (ip == null || it == null || td == null) {
      return 'Preencha pickup, dial e corrente de teste.';
    }
    if (ip <= 0) return 'I pick-up deve ser maior que zero.';
    if (td <= 0) return 'Dial de tempo deve ser maior que zero.';
    if (it <= ip) return 'I teste deve ser maior que o I pick-up.';
    return null;
  }

  double? get _multiple {
    final ip = _parse(_iPickup);
    final it = _parse(_iTest);
    if (ip == null || it == null || ip <= 0) return null;
    return it / ip;
  }

  double? get _tripTime {
    if (_validationError != null) return null;
    final t = _curve.timeForMultiple(_multiple!, _td);
    if (t.isNaN || t.isInfinite || t < 0) return null;
    return t;
  }

  void _pickCurve() async {
    final selected = await showIdmtCurvePicker(context, selectedId: _curve.id);
    if (selected != null) {
      setState(() => _curve = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _validationError;
    final time = _tripTime;

    return SparksBackground(
      child: PcbBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Curvas de Sobrecorrente (51)'),
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
                    _buildCurveSelector(),
                    const SizedBox(height: 16),
                    _buildCoefficients(),
                    const SizedBox(height: 16),
                    _buildInputs(),
                    const SizedBox(height: 20),
                    _buildResult(error, time),
                    const SizedBox(height: 20),
                    _buildChartCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurveSelector() {
    return Semantics(
      button: true,
      label: 'Curva selecionada: ${_curve.name}. Toque para trocar.',
      child: GestureDetector(
        onTap: _pickCurve,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.show_chart, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Curva selecionada',
                      style: TextStyle(
                        color: AppColors.textMuted.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _curve.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _curve.family,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.unfold_more, color: AppColors.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoefficients() {
    final items = <MapEntry<String, double>>[
      MapEntry('A', _curve.a),
      MapEntry('P', _curve.p),
      MapEntry('Q', _curve.q),
      MapEntry('B', _curve.b),
      MapEntry('K1', _curve.k1),
      MapEntry('K2', _curve.k2),
    ];
    String fmt(double v) {
      final s = v.toStringAsFixed(4);
      return s.replaceFirst(RegExp(r'\.?0+$'), '');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coeficientes  ·  t = (A·Td + K1)/(M^P − Q) + B·Td + K2',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((e) => _coefChip(e.key, fmt(e.value)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _coefChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label = ',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: _iPickup,
                  label: 'I pick-up (A)',
                  semantic: 'Corrente de pick-up em ampères',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberField(
                  controller: _dial,
                  label: 'Dial de tempo (Td)',
                  semantic: 'Dial de tempo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NumberField(
            controller: _iTest,
            label: 'I teste (A)',
            semantic: 'Corrente de teste em ampères',
          ),
        ],
      ),
    );
  }

  Widget _buildResult(String? error, double? time) {
    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final m = _multiple!;
    final secondsText = '${time!.toStringAsFixed(time < 1 ? 4 : 3)} s';
    final formatted = formatTripTime(time);
    final clip = '${_curve.name}\n'
        'M = ${m.toStringAsFixed(3)} · Td = ${_td.toStringAsFixed(3)}\n'
        'Tempo de atuação: $secondsText ($formatted)';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tempo de atuação',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Copiar resultado',
                child: IconButton(
                  icon: const Icon(Icons.copy_outlined,
                      color: AppColors.primary, size: 20),
                  tooltip: 'Copiar',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: clip));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Resultado copiado')),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Tempo de atuação $secondsText, equivalente a $formatted',
            child: Text(
              secondsText,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
          ),
          Text(
            '$formatted  (hh:mm:ss.cc)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'M = I_teste / I_pickup = ${m.toStringAsFixed(3)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
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
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Curva tempo × múltiplo (log-log)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 1.25,
            child: Semantics(
              label: 'Gráfico log-log da curva ${_curve.name}',
              child: CustomPaint(
                painter: _TccPainter(
                  curve: _curve,
                  td: _td > 0 ? _td : 1,
                  testMultiple: _validationError == null ? _multiple : null,
                  testTime: _tripTime,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String semantic;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.semantic,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semantic,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

// ── Pintor do gráfico log-log tempo × múltiplo ──────────────────
class _TccPainter extends CustomPainter {
  final IdmtCurve curve;
  final double td;
  final double? testMultiple;
  final double? testTime;

  static const double xMin = 1;
  static const double xMax = 20;
  static const double yMin = 0.01;
  static const double yMax = 1000;

  _TccPainter({
    required this.curve,
    required this.td,
    this.testMultiple,
    this.testTime,
  });

  static const double _padLeft = 44;
  static const double _padBottom = 24;
  static const double _padTop = 8;
  static const double _padRight = 10;

  double _lx(double m) =>
      (math.log(m) - math.log(xMin)) / (math.log(xMax) - math.log(xMin));
  double _ly(double t) =>
      (math.log(t) - math.log(yMin)) / (math.log(yMax) - math.log(yMin));

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _padLeft,
      _padTop,
      size.width - _padRight,
      size.height - _padBottom,
    );

    Offset toPx(double m, double t) {
      final fx = _lx(m).clamp(0.0, 1.0);
      final fy = _ly(t).clamp(0.0, 1.0);
      return Offset(
        plot.left + fx * plot.width,
        plot.bottom - fy * plot.height,
      );
    }

    final bg = Paint()..color = AppColors.background.withValues(alpha: 0.4);
    canvas.drawRect(plot, bg);

    final grid = Paint()
      ..color = AppColors.cardBorder.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final textStyle = TextStyle(
      color: AppColors.textMuted.withValues(alpha: 0.9),
      fontSize: 9,
    );

    // Linhas horizontais (décadas de tempo)
    for (final decade in [0.01, 0.1, 1.0, 10.0, 100.0, 1000.0]) {
      final y = plot.bottom - _ly(decade).clamp(0.0, 1.0) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(canvas, _fmtAxis(decade), Offset(plot.left - 4, y),
          textStyle, alignRight: true, alignMiddle: true);
    }

    // Linhas verticais (múltiplos)
    for (final mult in [1.0, 2.0, 3.0, 5.0, 10.0, 20.0]) {
      final x = plot.left + _lx(mult).clamp(0.0, 1.0) * plot.width;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      _label(canvas, _fmtAxis(mult), Offset(x, plot.bottom + 4), textStyle,
          alignCenter: true);
    }

    // Moldura
    final border = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(plot, border);

    // Curva
    final curvePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool started = false;
    const samples = 240;
    for (int i = 0; i <= samples; i++) {
      final f = i / samples;
      final m = math.exp(
          math.log(xMin) + f * (math.log(xMax) - math.log(xMin)));
      if (m <= 1.0001) continue;
      final t = curve.timeForMultiple(m, td);
      if (t.isNaN || t.isInfinite || t <= 0) {
        started = false;
        continue;
      }
      final fy = _ly(t);
      if (fy < 0 || fy > 1) {
        started = false;
        continue;
      }
      final pt = toPx(m, t);
      if (!started) {
        path.moveTo(pt.dx, pt.dy);
        started = true;
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.save();
    canvas.clipRect(plot);
    canvas.drawPath(path, curvePaint);

    // Ponto de teste
    if (testMultiple != null &&
        testTime != null &&
        testTime! > 0 &&
        _ly(testTime!) >= 0 &&
        _ly(testTime!) <= 1 &&
        _lx(testMultiple!) >= 0 &&
        _lx(testMultiple!) <= 1) {
      final pt = toPx(testMultiple!, testTime!);
      final cross = Paint()
        ..color = AppColors.gold
        ..strokeWidth = 1;
      canvas.drawLine(Offset(plot.left, pt.dy), Offset(plot.right, pt.dy),
          cross..color = AppColors.gold.withValues(alpha: 0.4));
      canvas.drawLine(Offset(pt.dx, plot.top), Offset(pt.dx, plot.bottom),
          cross..color = AppColors.gold.withValues(alpha: 0.4));
      canvas.drawCircle(pt, 5, Paint()..color = AppColors.gold);
      canvas.drawCircle(
          pt, 5, Paint()
            ..color = AppColors.background
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    canvas.restore();
  }

  String _fmtAxis(double v) {
    if (v >= 1) return v.toStringAsFixed(0);
    if (v == 0.1) return '0,1';
    if (v == 0.01) return '0,01';
    return v.toString();
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
  bool shouldRepaint(_TccPainter old) =>
      old.curve.id != curve.id ||
      old.td != td ||
      old.testMultiple != testMultiple ||
      old.testTime != testTime;
}
