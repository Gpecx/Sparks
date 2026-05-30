import 'package:flutter/material.dart';
import 'package:spark_app/utils/equipment_current.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class EquipmentCurrentScreen extends StatefulWidget {
  const EquipmentCurrentScreen({super.key});

  @override
  State<EquipmentCurrentScreen> createState() => _EquipmentCurrentScreenState();
}

class _EquipmentCurrentScreenState extends State<EquipmentCurrentScreen> {
  int _mode = 0; // 0 = transformador, 1 = motor

  // Transformador
  final _power = TextEditingController(text: '1000');
  final _vPrim = TextEditingController(text: '13.8');
  final _vSec = TextEditingController(text: '0.38');
  final _inrush = TextEditingController(text: '10');

  // Motor
  final _mPower = TextEditingController(text: '75');
  final _mVolt = TextEditingController(text: '380');
  final _mPf = TextEditingController(text: '0.85');
  final _mEff = TextEditingController(text: '0.93');
  final _startFactor = TextEditingController(text: '6');

  List<ToolResult>? _results;
  String? _warning;

  @override
  void dispose() {
    for (final c in [
      _power, _vPrim, _vSec, _inrush,
      _mPower, _mVolt, _mPf, _mEff, _startFactor,
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
      final s = _p(_power);
      final vp = _p(_vPrim);
      if (s == null || vp == null || s <= 0 || vp <= 0) {
        setState(() {
          _warning = 'Informe potência (kVA) e tensão primária (kV) > 0.';
          _results = null;
        });
        return;
      }
      final inPrim = transformerRatedCurrent(powerKva: s, voltageKv: vp);
      final results = <ToolResult>[
        ToolResult('In primário', '${fmtNumber(inPrim, decimals: 2)} A'),
      ];
      final vs = _p(_vSec);
      if (vs != null && vs > 0) {
        final inSec = transformerRatedCurrent(powerKva: s, voltageKv: vs);
        results.add(ToolResult('In secundário', '${fmtNumber(inSec, decimals: 2)} A'));
      }
      final k = _p(_inrush);
      if (k != null && k > 0) {
        results.add(ToolResult(
            'Inrush estimado (${fmtNumber(k, decimals: 0)}×)',
            '${fmtNumber(inPrim * k, decimals: 1)} A'));
      }
      setState(() {
        _warning = null;
        _results = results;
      });
    } else {
      final p = _p(_mPower);
      final v = _p(_mVolt);
      final pf = _p(_mPf);
      final eff = _p(_mEff);
      if (p == null || v == null || pf == null || eff == null ||
          p <= 0 || v <= 0 || pf <= 0 || eff <= 0) {
        setState(() {
          _warning = 'Preencha potência, tensão, FP e rendimento (> 0).';
          _results = null;
        });
        return;
      }
      final inMotor = motorRatedCurrent(
          powerKw: p, voltageV: v, powerFactor: pf, efficiency: eff);
      final results = <ToolResult>[
        ToolResult('Corrente nominal', '${fmtNumber(inMotor, decimals: 2)} A'),
      ];
      final k = _p(_startFactor);
      if (k != null && k > 0) {
        results.add(ToolResult(
            'Corrente de partida (${fmtNumber(k, decimals: 0)}×)',
            '${fmtNumber(inMotor * k, decimals: 1)} A'));
      }
      setState(() {
        _warning = null;
        _results = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Corrente Nominal',
      children: [
        ToolSegmented(
          labels: const ['Transformador', 'Motor'],
          selected: _mode,
          onSelect: (i) => setState(() {
            _mode = i;
            _results = null;
            _warning = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_mode == 0)
          ToolCard(
            title: 'Transformador',
            subtitle: 'In = S / (√3 · V)',
            children: [
              ToolField(controller: _power, label: 'Potência S (kVA)'),
              const SizedBox(height: 12),
              ToolFieldRow(children: [
                ToolField(controller: _vPrim, label: 'V primário (kV)'),
                ToolField(controller: _vSec, label: 'V secundário (kV)'),
              ]),
              const SizedBox(height: 12),
              ToolField(controller: _inrush, label: 'Fator de inrush (×)'),
            ],
          )
        else
          ToolCard(
            title: 'Motor',
            subtitle: 'In = P / (√3 · V · FP · η)  ·  use kW (1 CV ≈ 0,7355 kW)',
            children: [
              ToolFieldRow(children: [
                ToolField(controller: _mPower, label: 'Potência (kW)'),
                ToolField(controller: _mVolt, label: 'Tensão (V)'),
              ]),
              const SizedBox(height: 12),
              ToolFieldRow(children: [
                ToolField(controller: _mPf, label: 'FP (cosφ)'),
                ToolField(controller: _mEff, label: 'Rendimento η'),
              ]),
              const SizedBox(height: 12),
              ToolField(controller: _startFactor, label: 'Fator de partida (×)'),
            ],
          ),
        const SizedBox(height: 20),
        ToolButton(label: 'CALCULAR', onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(results: _results ?? const [], warning: _warning),
        ],
      ],
    );
  }
}
