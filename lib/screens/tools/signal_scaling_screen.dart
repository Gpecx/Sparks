import 'package:flutter/material.dart';
import 'package:spark_app/l10n/app_localizations.dart';
import 'package:spark_app/utils/signal_scaling.dart';
import 'package:spark_app/screens/tools/widgets/tool_kit.dart';

class SignalScalingScreen extends StatefulWidget {
  const SignalScalingScreen({super.key});

  @override
  State<SignalScalingScreen> createState() => _SignalScalingScreenState();
}

class _SignalScalingScreenState extends State<SignalScalingScreen> {
  int _preset = 0; // 0 = 4-20 mA, 1 = 0-20 mA, 2 = 0-10 V, 3 = personalizado

  final _sigMin = TextEditingController(text: '4');
  final _sigMax = TextEditingController(text: '20');
  final _engMin = TextEditingController(text: '0');
  final _engMax = TextEditingController(text: '100');
  final _sigVal = TextEditingController(text: '12');
  final _engVal = TextEditingController(text: '50');

  List<ToolResult>? _results;
  String? _warning;

  @override
  void dispose() {
    for (final c in [_sigMin, _sigMax, _engMin, _engMax, _sigVal, _engVal]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _p(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _applyPreset(int i) {
    setState(() {
      _preset = i;
      _results = null;
      _warning = null;
      switch (i) {
        case 0:
          _sigMin.text = '4';
          _sigMax.text = '20';
          break;
        case 1:
          _sigMin.text = '0';
          _sigMax.text = '20';
          break;
        case 2:
          _sigMin.text = '0';
          _sigMax.text = '10';
          break;
      }
    });
  }

  void _calculate() {
    final sMin = _p(_sigMin);
    final sMax = _p(_sigMax);
    final eMin = _p(_engMin);
    final eMax = _p(_engMax);
    if (sMin == null || sMax == null || eMin == null || eMax == null) {
      setState(() {
        _warning = 'Preencha as faixas de sinal e de engenharia.';
        _results = null;
      });
      return;
    }
    if (sMin == sMax || eMin == eMax) {
      setState(() {
        _warning = 'As faixas não podem ter início igual ao fim.';
        _results = null;
      });
      return;
    }

    final results = <ToolResult>[];
    final sv = _p(_sigVal);
    if (sv != null) {
      final eng = signalToEng(
          signal: sv, sigMin: sMin, sigMax: sMax, engMin: eMin, engMax: eMax);
      results.add(ToolResult('Sinal $sv → engenharia', fmtNumber(eng, decimals: 3)));
    }
    final ev = _p(_engVal);
    if (ev != null) {
      final sig = engToSignal(
          eng: ev, sigMin: sMin, sigMax: sMax, engMin: eMin, engMax: eMax);
      results.add(ToolResult('Engenharia $ev → sinal', fmtNumber(sig, decimals: 4)));
    }
    if (results.isEmpty) {
      setState(() {
        _warning = 'Informe um valor de sinal ou de engenharia para converter.';
        _results = null;
      });
      return;
    }

    setState(() {
      _warning = null;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Escalonamento 4–20 mA',
      children: [
        ToolSegmented(
          labels: const ['4–20 mA', '0–20 mA', '0–10 V', 'Custom'],
          selected: _preset,
          onSelect: _applyPreset,
        ),
        const SizedBox(height: 16),
        ToolCard(
          title: AppLocalizations.of(context)!.signalScalingRanges,
          subtitle: AppLocalizations.of(context)!.signalScalingDesc,
          children: [
            ToolFieldRow(children: [
              ToolField(controller: _sigMin, label: AppLocalizations.of(context)!.signalScalingSigMin, signed: true),
              ToolField(controller: _sigMax, label: AppLocalizations.of(context)!.signalScalingSigMax, signed: true),
            ]),
            const SizedBox(height: 12),
            ToolFieldRow(children: [
              ToolField(controller: _engMin, label: AppLocalizations.of(context)!.signalScalingEngMin, signed: true),
              ToolField(controller: _engMax, label: AppLocalizations.of(context)!.signalScalingEngMax, signed: true),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ToolCard(
          title: AppLocalizations.of(context)!.signalScalingConv,
          children: [
            ToolField(
                controller: _sigVal,
                label: AppLocalizations.of(context)!.signalScalingSigVal,
                signed: true),
            const SizedBox(height: 12),
            ToolField(
                controller: _engVal,
                label: AppLocalizations.of(context)!.signalScalingEngVal,
                signed: true),
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
