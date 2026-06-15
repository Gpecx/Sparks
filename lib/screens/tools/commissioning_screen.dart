import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/commissioning.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class CommissioningScreen extends StatefulWidget {
  const CommissioningScreen({super.key});

  @override
  State<CommissioningScreen> createState() => _CommissioningScreenState();
}

class _CommissioningScreenState extends State<CommissioningScreen> {
  int _mode = 0; // 0 = tolerância, 1 = injeção secundária

  // Tolerância
  final _measured = TextEditingController(text: '0.512');
  final _expected = TextEditingController(text: '0.500');
  final _tolerance = TextEditingController(text: '5');

  // Injeção secundária
  final _faultPrim = TextEditingController(text: '6000');
  final _rtc = TextEditingController(text: '120');
  final _vPrim = TextEditingController(text: '13800');
  final _rtp = TextEditingController(text: '120');

  List<ToolResult>? _results;
  String? _warning;
  bool? _pass;

  @override
  void dispose() {
    for (final c in [
      _measured, _expected, _tolerance,
      _faultPrim, _rtc, _vPrim, _rtp,
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
    if (_mode == 0) {
      final m = _p(_measured);
      final e = _p(_expected);
      final tol = _p(_tolerance);
      if (m == null || e == null || tol == null || e == 0) {
        setState(() {
          _warning = 'Preencha medido, esperado (≠ 0) e tolerância.';
          _results = null;
          _pass = null;
        });
        return;
      }
      final r = toleranceCheck(measured: m, expected: e, tolerancePercent: tol);
      setState(() {
        _warning = null;
        _pass = r.pass;
        _results = [
          ToolResult('Erro', '${fmtNumber(r.errorPercent, decimals: 3)} %'),
          ToolResult('Tolerância', '± ${fmtNumber(tol, decimals: 2)} %'),
          ToolResult('Veredito', r.pass ? 'APROVADO' : 'REPROVADO'),
        ];
      });
    } else {
      final ifault = _p(_faultPrim);
      final rtc = _p(_rtc);
      if (ifault == null || rtc == null || rtc <= 0) {
        setState(() {
          _warning = 'Informe a corrente de falta primária e a RTC (> 0).';
          _results = null;
          _pass = null;
        });
        return;
      }
      final results = <ToolResult>[
        ToolResult('I de injeção (secundário)',
            '${fmtNumber(secondaryInjectionCurrent(faultPrimary: ifault, rtc: rtc), decimals: 3)} A'),
      ];
      final vp = _p(_vPrim);
      final rtp = _p(_rtp);
      if (vp != null && rtp != null && rtp > 0) {
        results.add(ToolResult('V de injeção (secundário)',
            '${fmtNumber(secondaryInjectionVoltage(primaryVoltage: vp, rtp: rtp), decimals: 2)} V'));
      }
      setState(() {
        _warning = null;
        _pass = null;
        _results = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Comissionamento / Ensaios',
      children: [
        ToolSegmented(
          labels: const ['Tolerância', 'Injeção secundária'],
          selected: _mode,
          onSelect: (i) => setState(() {
            _mode = i;
            _results = null;
            _warning = null;
            _pass = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_mode == 0)
          ToolCard(
            title: 'Tolerância de ensaio',
            subtitle: 'erro% = (medido − esperado) / esperado · 100',
            children: [
              ToolFieldRow(children: [
                ToolField(controller: _measured, label: 'Medido'),
                ToolField(controller: _expected, label: 'Esperado'),
              ]),
              const SizedBox(height: 12),
              ToolField(controller: _tolerance, label: 'Tolerância (± %)'),
            ],
          )
        else
          ToolCard(
            title: 'Injeção secundária',
            subtitle: 'I_sec = I_falta / RTC   ·   V_sec = V_primária / RTP',
            children: [
              ToolFieldRow(children: [
                ToolField(controller: _faultPrim, label: 'I falta primária (A)'),
                ToolField(controller: _rtc, label: 'RTC'),
              ]),
              const SizedBox(height: 12),
              ToolFieldRow(children: [
                ToolField(controller: _vPrim, label: 'V primária (V)'),
                ToolField(controller: _rtp, label: 'RTP'),
              ]),
            ],
          ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          if (_pass != null) _verdictBox(_pass!),
          if (_pass != null) const SizedBox(height: 12),
          ToolResultsPanel(results: _results ?? const [], warning: _warning),
        ],
      ],
    );
  }

  Widget _verdictBox(bool pass) {
    final color = pass ? AppColors.primary : AppColors.error;
    final icon = pass ? Icons.check_circle : Icons.cancel_outlined;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pass ? 'APROVADO (dentro da tolerância)' : 'REPROVADO (fora da tolerância)',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
