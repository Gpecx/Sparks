import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/utils/short_circuit.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class ShortCircuitScreen extends StatefulWidget {
  const ShortCircuitScreen({super.key});

  @override
  State<ShortCircuitScreen> createState() => _ShortCircuitScreenState();
}

class _ShortCircuitScreenState extends State<ShortCircuitScreen> {
  final _vLL = TextEditingController(text: '138');
  final _z1 = TextEditingController(text: '10');
  final _z2 = TextEditingController(text: '10');
  final _z0 = TextEditingController(text: '15');
  final _zf = TextEditingController(text: '0');

  List<ToolResult>? _results;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_vLL, _z1, _z2, _z0, _zf]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  String _amps(double a) {
    if (a.isNaN) return '—';
    final ka = a / 1000.0;
    return '${fmtNumber(a, decimals: 0)} A  (${fmtNumber(ka, decimals: 3)} kA)';
  }

  void _calculate() {
    final v = _p(_vLL);
    final z1 = _p(_z1);
    final z0 = _p(_z0);
    final zf = _p(_zf) ?? 0;
    if (v == null || z1 == null || z0 == null || v <= 0 || z1 <= 0) {
      setState(() {
        _warning = 'Informe a tensão de linha e ao menos Z1 e Z0 (valores > 0).';
        _results = null;
      });
      return;
    }
    final z2 = _p(_z2) ?? z1;

    final r = shortCircuitCurrents(
      vLLkv: v,
      z1: z1,
      z2: z2,
      z0: z0,
      zf: zf,
    );

    setState(() {
      _warning = null;
      _results = [
        ToolResult(AppLocalizations.of(context)!.shortCircuit3P, _amps(r.threePhase)),
        ToolResult(AppLocalizations.of(context)!.shortCircuitLL, _amps(r.lineToLine)),
        ToolResult(AppLocalizations.of(context)!.shortCircuitLG, _amps(r.lineToGround)),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: AppLocalizations.of(context)!.tlShortCircuit,
      children: [
        ToolCard(
          title: AppLocalizations.of(context)!.shortCircuitData,
          subtitle:
              AppLocalizations.of(context)!.shortCircuitDesc,
          children: [
            ToolField(
              controller: _vLL,
              label: AppLocalizations.of(context)!.shortCircuitVLL,
              semantic: 'Tensão de linha em kV',
            ),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(
                  controller: _z1,
                  label: AppLocalizations.of(context)!.shortCircuitZ1,
                  semantic: 'Impedância de sequência positiva'),
              ToolField(
                  controller: _z2,
                  label: AppLocalizations.of(context)!.shortCircuitZ2,
                  semantic: 'Impedância de sequência negativa'),
            ]),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(
                  controller: _z0,
                  label: AppLocalizations.of(context)!.shortCircuitZ0,
                  semantic: 'Impedância de sequência zero'),
              ToolField(
                  controller: _zf,
                  label: AppLocalizations.of(context)!.shortCircuitZf,
                  semantic: 'Impedância de falta'),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        ToolButton(label: AppLocalizations.of(context)!.tlBtnCalculate, onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
            title: AppLocalizations.of(context)!.shortCircuitCurrents,
            note:
                'Aproximação por módulos de impedância (escalar). Para precisão de fase, '
                'use cálculo fasorial completo.',
          ),
        ],
      ],
    );
  }
}
