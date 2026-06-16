import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/utils/power_factor.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class PowerFactorScreen extends StatefulWidget {
  const PowerFactorScreen({super.key});

  @override
  State<PowerFactorScreen> createState() => _PowerFactorScreenState();
}

class _PowerFactorScreenState extends State<PowerFactorScreen> {
  final _power = TextEditingController(text: '100');
  final _pfNow = TextEditingController(text: '0.8');
  final _pfTarget = TextEditingController(text: '0.95');

  List<ToolResult>? _results;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_power, _pfNow, _pfTarget]) {
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
    final p = _p(_power);
    final pf1 = _p(_pfNow);
    final pf2 = _p(_pfTarget);
    if (p == null || pf1 == null || pf2 == null || p <= 0) {
      setState(() {
        _warning = 'Preencha potência ativa e os fatores de potência.';
        _results = null;
      });
      return;
    }
    if (pf1 <= 0 || pf1 > 1 || pf2 <= 0 || pf2 > 1) {
      setState(() {
        _warning = 'Os fatores de potência devem estar entre 0 e 1.';
        _results = null;
      });
      return;
    }
    if (pf2 <= pf1) {
      setState(() {
        _warning = 'O FP desejado deve ser maior que o FP atual.';
        _results = null;
      });
      return;
    }

    final res = powerFactorCorrection(
      activePowerKw: p,
      pfCurrent: pf1,
      pfTarget: pf2,
    );

    setState(() {
      _warning = null;
      _results = [
        ToolResult(AppLocalizations.of(context)!.powerFactorReqBank, '${fmtNumber(res.capacitorKvar, decimals: 2)} kvar'),
        ToolResult(AppLocalizations.of(context)!.powerFactorReactBefore, '${fmtNumber(res.reactiveBefore, decimals: 2)} kvar'),
        ToolResult(AppLocalizations.of(context)!.powerFactorReactAfter, '${fmtNumber(res.reactiveAfter, decimals: 2)} kvar'),
        ToolResult(AppLocalizations.of(context)!.powerFactorAppBefore, '${fmtNumber(res.apparentBefore, decimals: 2)} kVA'),
        ToolResult(AppLocalizations.of(context)!.powerFactorAppAfter, '${fmtNumber(res.apparentAfter, decimals: 2)} kVA'),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Correção de Fator de Potência',
      children: [
        ToolCard(
          title: AppLocalizations.of(context)!.powerFactorData,
          subtitle: AppLocalizations.of(context)!.powerFactorDesc,
          children: [
            ToolField(
              controller: _power,
              label: AppLocalizations.of(context)!.powerFactorActP,
              semantic: 'Potência ativa em kW',
            ),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(
                  controller: _pfNow,
                  label: AppLocalizations.of(context)!.powerFactorCurPF,
                  semantic: 'Fator de potência atual'),
              ToolField(
                  controller: _pfTarget,
                  label: AppLocalizations.of(context)!.powerFactorDesPF,
                  semantic: 'Fator de potência desejado'),
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
            title: AppLocalizations.of(context)!.powerFactorBank,
          ),
        ],
      ],
    );
  }
}
