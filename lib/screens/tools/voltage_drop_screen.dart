import 'package:flutter/material.dart';
import 'package:spark_app/utils/voltage_drop.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class VoltageDropScreen extends StatefulWidget {
  const VoltageDropScreen({super.key});

  @override
  State<VoltageDropScreen> createState() => _VoltageDropScreenState();
}

class _VoltageDropScreenState extends State<VoltageDropScreen> {
  final _current = TextEditingController(text: '100');
  final _length = TextEditingController(text: '10');
  final _r = TextEditingController(text: '0.1');
  final _x = TextEditingController(text: '0.1');
  final _pf = TextEditingController(text: '0.8');
  final _vLL = TextEditingController(text: '13.8');

  List<ToolResult>? _results;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_current, _length, _r, _x, _pf, _vLL]) {
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
    final i = _p(_current);
    final l = _p(_length);
    final r = _p(_r);
    final x = _p(_x);
    final pf = _p(_pf);
    final v = _p(_vLL);
    if (i == null || l == null || r == null || x == null || pf == null ||
        v == null) {
      setState(() {
        _warning = 'Preencha todos os campos.';
        _results = null;
      });
      return;
    }
    if (pf < 0 || pf > 1) {
      setState(() {
        _warning = 'O fator de potência deve estar entre 0 e 1.';
        _results = null;
      });
      return;
    }

    final res = voltageDrop(
      currentA: i,
      lengthKm: l,
      rPerKm: r,
      xPerKm: x,
      powerFactor: pf,
      vLLkv: v,
    );

    setState(() {
      _warning = null;
      _results = [
        ToolResult('Queda de tensão ΔV', '${fmtNumber(res.dropVolts, decimals: 1)} V'),
        ToolResult('Queda percentual', '${fmtNumber(res.dropPercent, decimals: 2)} %'),
        ToolResult('Tensão na carga', '${fmtNumber(v * 1000 - res.dropVolts, decimals: 1)} V'),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Queda de Tensão',
      children: [
        ToolCard(
          title: 'Alimentador trifásico',
          subtitle: 'ΔV = √3 · I · L · (R·cosφ + X·senφ)',
          children: [
            ToolFieldRow(children: [
              ToolField(
                  controller: _current,
                  label: 'Corrente I (A)',
                  semantic: 'Corrente em ampères'),
              ToolField(
                  controller: _length,
                  label: 'Comprimento L (km)',
                  semantic: 'Comprimento em km'),
            ]),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(
                  controller: _r,
                  label: 'R (Ω/km)',
                  semantic: 'Resistência por km'),
              ToolField(
                  controller: _x,
                  label: 'X (Ω/km)',
                  semantic: 'Reatância por km'),
            ]),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(
                  controller: _pf,
                  label: 'FP (cosφ)',
                  semantic: 'Fator de potência'),
              ToolField(
                  controller: _vLL,
                  label: 'Tensão V_LL (kV)',
                  semantic: 'Tensão de linha em kV'),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
          ),
        ],
      ],
    );
  }
}
