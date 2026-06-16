import 'package:flutter/material.dart';
import 'package:spark_app/theme/app_theme.dart';
import 'package:spark_app/utils/ct_saturation.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class CtSaturationScreen extends StatefulWidget {
  const CtSaturationScreen({super.key});

  @override
  State<CtSaturationScreen> createState() => _CtSaturationScreenState();
}

class _CtSaturationScreenState extends State<CtSaturationScreen> {
  final _ctPrimary = TextEditingController(text: '600');
  final _ctSecondary = TextEditingController(text: '5');
  final _rct = TextEditingController(text: '0.5');
  final _ratedBurden = TextEditingController(text: '15');
  final _alf = TextEditingController(text: '20');
  final _connectedBurden = TextEditingController(text: '2');
  final _faultCurrent = TextEditingController(text: '6000');

  List<ToolResult>? _results;
  String? _warning;
  bool _saturates = false;

  @override
  void dispose() {
    for (final c in [
      _ctPrimary, _ctSecondary, _rct, _ratedBurden, _alf, _connectedBurden,
      _faultCurrent,
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
    final cp = _p(_ctPrimary);
    final cs = _p(_ctSecondary);
    final rct = _p(_rct);
    final sn = _p(_ratedBurden);
    final alf = _p(_alf);
    final zb = _p(_connectedBurden);
    final ifault = _p(_faultCurrent);
    if ([cp, cs, rct, sn, alf, zb, ifault].any((e) => e == null) ||
        cp! <= 0 || cs! <= 0 || alf! <= 0) {
      setState(() {
        _warning = 'Preencha todos os campos (TC, Rct, carga, ALF e corrente de falta).';
        _results = null;
      });
      return;
    }

    final r = ctSaturation(
      ctPrimary: cp,
      ctSecondary: cs,
      rctOhm: rct!,
      ratedBurdenVa: sn!,
      alf: alf,
      connectedBurdenOhm: zb!,
      faultPrimaryCurrent: ifault!,
    );

    setState(() {
      _warning = null;
      _saturates = r.saturates;
      _results = [
        ToolResult('RTC', fmtNumber(r.rtc, decimals: 1)),
        ToolResult('Carga nominal Zn', '${fmtNumber(r.ratedBurdenOhm, decimals: 3)} Ω'),
        ToolResult('Tensão de joelho Vk', '${fmtNumber(r.kneeVoltage, decimals: 1)} V'),
        ToolResult('I secundária de falta', '${fmtNumber(r.secondaryFaultCurrent, decimals: 2)} A'),
        ToolResult('Tensão exigida V_req', '${fmtNumber(r.requiredVoltage, decimals: 1)} V'),
        ToolResult('Múltiplo de falta', '${fmtNumber(r.faultMultiple, decimals: 2)} ×'),
        ToolResult('ALF efetivo', fmtNumber(r.effectiveAlf, decimals: 2)),
        ToolResult('Margem (Vk/V_req)', fmtNumber(r.margin, decimals: 3)),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Saturação de TC',
      children: [
        ToolCard(
          title: 'Transformador de corrente (classe P)',
          subtitle:
              'Zn = Sn/In² · Vk ≈ ALF·In·(Rct+Zn) · V_req = I_sec_falta·(Rct+Zb). Satura se V_req > Vk.',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _ctPrimary, label: 'TC primário (A)'),
              ToolField(controller: _ctSecondary, label: 'TC secundário In (A)'),
            ]),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(controller: _rct, label: 'Rct interna (Ω)'),
              ToolField(controller: _alf, label: 'ALF (ex.: 20)'),
            ]),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(controller: _ratedBurden, label: 'Carga nominal Sn (VA)'),
              ToolField(controller: _connectedBurden, label: 'Carga conectada Zb (Ω)'),
            ]),
            const SizedBox(height: 12),
            ToolField(
              controller: _faultCurrent,
              label: 'Corrente de falta no primário (A)',
            ),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          if (_results != null) _verdict(),
          if (_results != null) const SizedBox(height: 12),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
            title: 'Verificação de saturação',
          ),
        ],
      ],
    );
  }

  Widget _verdict() {
    final color = _saturates ? AppColors.error : AppColors.primary;
    final icon = _saturates ? Icons.warning_amber_rounded : Icons.check_circle;
    final text = _saturates
        ? 'O TC SATURA nesta condição (V_req > Vk).'
        : 'O TC NÃO satura nesta condição (V_req ≤ Vk).';
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
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
