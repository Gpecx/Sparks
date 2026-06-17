import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/utils/differential_balance.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class _WindingFields {
  final String name;
  final TextEditingController power;
  final TextEditingController voltage;
  final TextEditingController ctPrimary;
  final TextEditingController ctSecondary;

  _WindingFields({
    required this.name,
    required String power,
    required String voltage,
    required String ctPrimary,
    required String ctSecondary,
  })  : power = TextEditingController(text: power),
        voltage = TextEditingController(text: voltage),
        ctPrimary = TextEditingController(text: ctPrimary),
        ctSecondary = TextEditingController(text: ctSecondary);

  void dispose() {
    power.dispose();
    voltage.dispose();
    ctPrimary.dispose();
    ctSecondary.dispose();
  }
}

class DifferentialBalanceScreen extends StatefulWidget {
  const DifferentialBalanceScreen({super.key});

  @override
  State<DifferentialBalanceScreen> createState() =>
      _DifferentialBalanceScreenState();
}

class _DifferentialBalanceScreenState extends State<DifferentialBalanceScreen> {
  late final List<_WindingFields> _windings = [
    _WindingFields(
        name: 'Primário',
        power: '40',
        voltage: '115.5',
        ctPrimary: '200',
        ctSecondary: '1'),
    _WindingFields(
        name: 'Secundário',
        power: '40',
        voltage: '30',
        ctPrimary: '800',
        ctSecondary: '1'),
  ];

  List<ToolResult>? _results;
  String? _warning;

  @override
  void dispose() {
    for (final w in _windings) {
      w.dispose();
    }
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _calculate() {
    final inputs = <WindingInput>[];
    for (final w in _windings) {
      final s = _p(w.power);
      final v = _p(w.voltage);
      final cp = _p(w.ctPrimary);
      final cs = _p(w.ctSecondary);
      if (s == null || v == null || cp == null || cs == null ||
          s <= 0 || v <= 0 || cp <= 0 || cs <= 0) {
        setState(() {
          _warning =
              'Preencha potência, tensão e relação de TC de todos os enrolamentos (valores > 0).';
          _results = null;
        });
        return;
      }
      inputs.add(WindingInput(
          powerMva: s, voltageKv: v, ctPrimary: cp, ctSecondary: cs));
    }

    final res = computeDifferentialBalance(inputs, 0);
    final results = <ToolResult>[];
    for (var i = 0; i < res.length; i++) {
      final name = _windings[i].name;
      results.add(ToolResult(
          '$name — I nominal', '${fmtNumber(res[i].nominalCurrent, decimals: 1)} A'));
      results.add(ToolResult(
          '$name — I secundário TC', '${fmtNumber(res[i].secondaryCurrent, decimals: 4)} A'));
      results.add(ToolResult(
          '$name — Balanço', fmtNumber(res[i].balance, decimals: 3)));
    }

    setState(() {
      _warning = null;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: AppLocalizations.of(context)!.tlDiffBalance,
      children: [
        ToolCard(
          subtitle:
              AppLocalizations.of(context)!.diffBalDesc,
          children: const [],
        ),
        const SizedBox(height: 12),
        for (final w in _windings) ...[
          ToolCard(
            title: w.name,
            children: [
              ToolFieldRow(children: [
                ToolField(
                    controller: w.power,
                    label: AppLocalizations.of(context)!.diffBalPower,
                    semantic: 'Potência do enrolamento ${w.name}'),
                ToolField(
                    controller: w.voltage,
                    label: AppLocalizations.of(context)!.diffBalVolt,
                    semantic: 'Tensão do enrolamento ${w.name}'),
              ]),
              const SizedBox(height: 12),
              ToolFieldRow(children: [
                ToolField(
                    controller: w.ctPrimary,
                    label: AppLocalizations.of(context)!.diffBalPri,
                    semantic: 'TC primário ${w.name}'),
                ToolField(
                    controller: w.ctSecondary,
                    label: AppLocalizations.of(context)!.diffBalSec,
                    semantic: 'TC secundário ${w.name}'),
              ]),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        ToolButton(label: AppLocalizations.of(context)!.tlBtnCalculate, onPressed: _calculate),
        if (_warning != null || _results != null) ...[
          const SizedBox(height: 24),
          ToolResultsPanel(
            results: _results ?? const [],
            warning: _warning,
            title: AppLocalizations.of(context)!.diffBalCoeffs,
          ),
        ],
      ],
    );
  }
}
