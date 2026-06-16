import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/utils/ground_grid.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class GroundGridScreen extends StatefulWidget {
  const GroundGridScreen({super.key});

  @override
  State<GroundGridScreen> createState() => _GroundGridScreenState();
}

class _GroundGridScreenState extends State<GroundGridScreen> {
  int _body = 0; // 0 = 50 kg, 1 = 70 kg

  final _rho = TextEditingController(text: '2500');
  final _ts = TextEditingController(text: '0.5');
  final _cs = TextEditingController(text: '1');
  final _ig = TextEditingController(text: '5000');
  final _rg = TextEditingController(text: '1');

  List<ToolResult>? _results;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_rho, _ts, _cs, _ig, _rg]) {
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
    final rho = _p(_rho);
    final ts = _p(_ts);
    final cs = _p(_cs) ?? 1;
    final ig = _p(_ig) ?? 0;
    final rg = _p(_rg) ?? 0;
    if (rho == null || ts == null || ts <= 0) {
      setState(() {
        _warning = 'Informe a resistividade superficial e o tempo de falta (> 0).';
        _results = null;
      });
      return;
    }

    final r = groundGridTolerable(
      surfaceResistivity: rho,
      faultDuration: ts,
      cs: cs,
      body70kg: _body == 1,
      gridCurrent: ig,
      gridResistance: rg,
    );

    final results = <ToolResult>[
      ToolResult(AppLocalizations.of(context)!.groundGridTouchTol, '${fmtNumber(r.touchVoltage, decimals: 1)} V'),
      ToolResult(AppLocalizations.of(context)!.groundGridStepTol, '${fmtNumber(r.stepVoltage, decimals: 1)} V'),
    ];
    if (ig > 0 && rg > 0) {
      results.add(ToolResult(AppLocalizations.of(context)!.groundGridGpr, '${fmtNumber(r.gpr, decimals: 1)} V'));
    }

    setState(() {
      _warning = null;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Malha de Aterramento (IEEE 80)',
      children: [
        ToolSegmented(
          labels: const ['Corpo 50 kg', 'Corpo 70 kg'],
          selected: _body,
          onSelect: (i) => setState(() {
            _body = i;
            _results = null;
            _warning = null;
          }),
        ),
        const SizedBox(height: 16),
        ToolCard(
          title: AppLocalizations.of(context)!.groundGridParams,
          subtitle:
              'E_toque = (1000 + 1,5·Cs·ρs)·k · E_passo = (1000 + 6·Cs·ρs)·k · k = ${_body == 1 ? '0,157' : '0,116'}/√ts',
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _rho, label: AppLocalizations.of(context)!.groundGridRes),
              ToolField(controller: _ts, label: AppLocalizations.of(context)!.groundGridTime),
            ]),
            const SizedBox(height: 12),
            ToolField(controller: _cs, label: AppLocalizations.of(context)!.groundGridCs),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.groundGridGprCalc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _ig, label: AppLocalizations.of(context)!.groundGridIg),
              ToolField(controller: _rg, label: AppLocalizations.of(context)!.groundGridRg),
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
            title: AppLocalizations.of(context)!.groundGridTol,
            note:
                'Limites toleráveis pelo corpo humano (IEEE 80). A verificação completa exige '
                'as tensões de malha (Em) e de passo (Es) reais, que dependem da geometria.',
          ),
        ],
      ],
    );
  }
}
